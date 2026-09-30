import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Pi's own startup check notifies about package updates but does not offer
// confirmation. Check the installed npm packages here, then let pi's package
// manager perform the update (not npm directly, and never `pi update` bare).
export default function (pi: ExtensionAPI) {
	let controller: AbortController | undefined;

	pi.on("session_start", (event, ctx) => {
		if (event.reason !== "startup") {
			controller?.abort(); // Don't prompt for a session that was just replaced.
			controller = undefined;
			return;
		}
		if (ctx.mode !== "tui" || process.env.PI_OFFLINE) return;
		const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
		const npmDir = join(agentDir, "npm");
		if (!existsSync(join(npmDir, "package.json"))) return;

		controller = new AbortController();
		const signal = controller.signal;
		// Don't hold up the UI while npm checks the registry. A failed or timed-out
		// check leaves the conversation alone; no package changes without consent.
		void (async () => {
			const result = await pi.exec("npm", ["outdated", "--json", "--depth=0"], {
				cwd: npmDir,
				signal,
				timeout: 5000,
			});
			if (signal.aborted || (result.code !== 0 && result.code !== 1)) return;
			const outdated = JSON.parse(result.stdout || "{}") as Record<string, { current?: string; latest?: string }>;
			const updates = Object.entries(outdated)
				.filter(([, info]) => info && info.current && info.latest && info.current !== info.latest)
				.map(([name, info]) => `${name}: ${info.current} → ${info.latest}`);
			if (!updates.length || signal.aborted) return;
			const accepted = await ctx.ui.confirm("Pi package updates", `${updates.join("\n")}\n\nUpdate all Pi packages now?`);
			if (!accepted || signal.aborted) return;
			ctx.ui.notify("Updating Pi packages…", "info");
			// Update user packages only: never reconcile a project's packages just
			// because a global npm update appeared in this check.
			const update = await pi.exec("pi", ["update", "--extensions", "--no-approve"], { cwd: homedir(), signal });
			if (signal.aborted) return;
			if (update.code !== 0) {
				ctx.ui.notify(`Package update failed: ${update.stderr.trim() || update.stdout.trim() || `exit ${update.code}`}`, "error");
			} else {
				ctx.ui.notify("Pi packages updated. Restart Pi to load the new versions.", "info");
			}
		})().catch(() => {
			if (!signal.aborted) ctx.ui.notify("Could not check Pi package updates; starting normally.", "warning");
		});
	});

	pi.on("session_shutdown", () => {
		controller?.abort();
		controller = undefined;
	});
}
