import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// The background check must never open a dialog: Pi's extension selectors
// don't queue, so an unsolicited prompt can strand an active permission gate.
// An explicit slash command is the user's consent to update packages.
export default function (pi: ExtensionAPI) {
	let controller: AbortController | undefined;
	let updateController: AbortController | undefined;

	pi.registerCommand("update-pi-packages", {
		description: "Update user-installed Pi packages (restart Pi afterward)",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") return;
			if (updateController) {
				ctx.ui.notify("Pi package update already in progress.", "info");
				return;
			}
			controller?.abort(); // Don't report stale check results after an update.
			controller = undefined;
			const current = new AbortController();
			updateController = current;
			ctx.ui.notify("Updating Pi packages…", "info");
			try {
				// Never touch the Homebrew-owned Pi binary or trusted project packages.
				const result = await pi.exec("pi", ["update", "--extensions", "--no-approve"], {
					cwd: homedir(), signal: current.signal,
				});
				if (current.signal.aborted) return;
				if (result.code !== 0) {
					ctx.ui.notify(`Package update failed: ${result.stderr.trim() || result.stdout.trim() || `exit ${result.code}`}`, "error");
				} else {
					ctx.ui.notify("Pi packages updated. Restart Pi to load the new versions.", "info");
				}
			} catch (error) {
				if (!current.signal.aborted) ctx.ui.notify(`Package update failed: ${String(error)}`, "error");
			} finally {
				if (updateController === current) updateController = undefined;
			}
		},
	});

	pi.on("session_start", (event, ctx) => {
		if (event.reason !== "startup") {
			controller?.abort();
			controller = undefined;
			updateController?.abort();
			updateController = undefined;
			return;
		}
		if (ctx.mode !== "tui") return;
		if (process.env.PI_OFFLINE) {
			ctx.ui.notify("Pi package update check skipped (offline).", "info");
			return;
		}
		const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
		const npmDir = join(agentDir, "npm");
		if (!existsSync(join(npmDir, "package.json"))) {
			ctx.ui.notify("No installed npm Pi packages to check.", "info");
			return;
		}

		controller = new AbortController();
		const signal = controller.signal;
		// Don't hold up the UI while npm checks the registry; results are
		// notifications only, even if an agent permission dialog is active.
		void (async () => {
			const result = await pi.exec("npm", ["outdated", "--json", "--depth=0"], {
				cwd: npmDir,
				signal,
				timeout: 5000,
			});
			if (signal.aborted) return;
			if (result.killed || (result.code !== 0 && result.code !== 1) || !result.stdout.trim()) {
				ctx.ui.notify("Could not check Pi package updates; starting normally.", "warning");
				return;
			}
			const outdated: unknown = JSON.parse(result.stdout);
			if (!outdated || typeof outdated !== "object" || Array.isArray(outdated) || "error" in outdated) {
				throw new Error("Invalid npm outdated response");
			}
			const entries = Object.entries(outdated);
			if (entries.some(([, info]) => !info || typeof info !== "object"
				|| typeof info.current !== "string" || typeof info.latest !== "string")) {
				throw new Error("Invalid npm outdated package entry");
			}
			const updates = entries
				.filter(([, info]) => info.current !== info.latest)
				.map(([name, info]) => `${name}: ${info.current} → ${info.latest}`);
			if (signal.aborted) return;
			if (!updates.length) {
				if (result.code === 1) {
					ctx.ui.notify("Could not check Pi package updates; starting normally.", "warning");
				} else {
					ctx.ui.notify("Installed npm Pi packages are up to date.", "info");
				}
				return;
			}
			ctx.ui.notify(`Pi package updates available: ${updates.join(", ")}. Run /update-pi-packages to install.`, "info");
		})().catch(() => {
			if (!signal.aborted) ctx.ui.notify("Could not check Pi package updates; starting normally.", "warning");
		});
	});

	pi.on("session_shutdown", () => {
		controller?.abort();
		controller = undefined;
		updateController?.abort();
		updateController = undefined;
	});
}
