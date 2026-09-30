// Unit harness: mock npm/pi; exercise the real Pi 0.87.1 extension selector
// during a delayed registry response. Never contact the registry or update packages.
import { createRequire } from "node:module";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { PI_PACKAGE_DIR } from "./lib/pi-package-dir.mjs";

let jiti;
try {
	jiti = createRequire(`${PI_PACKAGE_DIR}/package.json`)("jiti");
} catch {
	console.log("  ok  package-update harness skipped: pi not installed here");
	process.exit(0);
}
const mod = await jiti.createJiti(import.meta.url).import(new URL("../dot_pi/agent/extensions/package-update-prompt.ts", import.meta.url).pathname);
const dir = mkdtempSync(join(tmpdir(), "pi-package-update-"));
mkdirSync(join(dir, "npm"));
writeFileSync(join(dir, "npm", "package.json"), "{}");
const oldDir = process.env.PI_CODING_AGENT_DIR;
process.env.PI_CODING_AGENT_DIR = dir;
let failures = 0;
function check(label, ok) {
	if (!ok) failures++;
	console.log(`${ok ? "PASS" : "FAIL"}  ${label}`);
}
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const deferred = () => {
	let resolve;
	const promise = new Promise((done) => { resolve = done; });
	return { promise, resolve };
};

async function run({ reason = "startup", mode = "tui", offline = false, stdout = "{}", code = 0,
	updateCode = 0, shutdown = false, npmResult, ui } = {}) {
	const handlers = {};
	const commands = {};
	const calls = [];
	const notifications = [];
	let dialogs = 0;
	mod.default({
		on: (name, handler) => { handlers[name] = handler; },
		registerCommand: (name, command) => { commands[name] = command; },
		exec: async (cmd, args, options) => {
			calls.push([cmd, args, options]);
			if (cmd === "npm") return npmResult ? npmResult : { stdout, code, stderr: "", killed: false };
			return { stdout: "", code: updateCode, stderr: updateCode ? "failed" : "", killed: false };
		},
	});
	const ctx = {
		mode, cwd: dir,
		ui: ui ?? {
			confirm: async () => { dialogs++; return true; },
			select: async () => { dialogs++; return "Yes"; },
			notify: (text, level) => notifications.push([text, level]),
		},
	};
	if (offline) process.env.PI_OFFLINE = "1";
	const start = handlers.session_start({ reason }, ctx);
	if (shutdown) handlers.session_shutdown();
	await start;
	await flush();
	if (offline) delete process.env.PI_OFFLINE;
	return { calls, dialogs, notifications, handlers, commands, ctx };
}

try {
	const outdated = JSON.stringify({ "@gotgenes/pi-permission-system": { current: "36.0.0", latest: "36.1.0" } });
	let result = await run({ stdout: outdated });
	check("available updates: status with explicit command, no modal or update", result.calls.length === 1
		&& result.calls[0][0] === "npm" && result.calls[0][1].join(" ") === "outdated --json --depth=0"
		&& result.dialogs === 0 && result.notifications.some(([s]) => s.includes("/update-pi-packages")));
	await result.commands["update-pi-packages"].handler("", result.ctx);
	check("explicit command updates user packages only and asks for restart", result.calls.length === 2
		&& result.calls[1][0] === "pi" && result.calls[1][1].join(" ") === "update --extensions --no-approve"
		&& result.dialogs === 0 && result.notifications.some(([s]) => s.includes("Restart Pi")));
	result = await run({ stdout: outdated, updateCode: 1 });
	await result.commands["update-pi-packages"].handler("", result.ctx);
	check("update errors are reported", result.notifications.some(([, level]) => level === "error"));
	result = await run({ stdout: "{}" });
	check("no updates: up-to-date notice, no modal", result.dialogs === 0 && result.calls.length === 1
		&& result.notifications.some(([s]) => s === "Installed npm Pi packages are up to date."));
	result = await run({ stdout: "invalid", code: 2 });
	check("failed npm probe reports uncertainty", result.dialogs === 0 && result.calls.length === 1
		&& result.notifications.some(([s, level]) => s.includes("Could not check") && level === "warning"));
	result = await run({ stdout: "invalid", code: 1 });
	check("invalid npm output reports uncertainty", result.notifications.some(([s, level]) => s.includes("Could not check") && level === "warning"));
	result = await run({ reason: "reload", stdout: outdated });
	check("reload does not recheck", result.calls.length === 0);
	result = await run({ mode: "print", stdout: outdated });
	check("noninteractive modes do not probe or notify", result.calls.length === 0 && result.notifications.length === 0);
	result = await run({ offline: true, stdout: outdated });
	check("offline mode reports skipped check", result.calls.length === 0
		&& result.notifications.some(([s]) => s.includes("offline")));
	result = await run({ stdout: outdated, shutdown: true });
	check("shutdown cancels the pending check", result.calls.length === 1 && result.notifications.length === 0);

	// Reproduce the review's ordering using Pi's actual selector implementation:
	// a permission dialog is already open when the delayed npm result arrives.
	const [{ InteractiveMode }, { initTheme }] = await Promise.all([
		import(pathToFileURL(join(PI_PACKAGE_DIR, "dist/modes/interactive/interactive-mode.js"))),
		import(pathToFileURL(join(PI_PACKAGE_DIR, "dist/modes/interactive/theme/theme.js"))),
	]);
	initTheme("dark");
	const piMode = Object.create(InteractiveMode.prototype);
	piMode.ui = { setFocus: () => {}, requestRender: () => {} };
	piMode.editorContainer = { clear: () => {}, addChild: () => {} };
	piMode.editor = {};
	piMode.disposeActiveSelector = () => {};
	const pending = deferred();
	const permission = piMode.showExtensionSelector("Permission", ["Allow", "Deny"]);
	const selector = piMode.extensionSelector;
	const notice = [];
	result = await run({ npmResult: pending.promise, ui: {
		notify: (message) => notice.push(message),
		confirm: (...args) => piMode.showExtensionConfirm(...args),
		select: (...args) => piMode.showExtensionSelector(...args),
	} });
	pending.resolve({ stdout: outdated, code: 1, stderr: "", killed: false });
	await flush();
	check("delayed update check does not replace Pi's permission selector", piMode.extensionSelector === selector
		&& notice.some((message) => message.includes("/update-pi-packages")));
	selector.onSelectCallback("Allow");
	check("permission dialog resolves normally", await permission === "Allow");

	rmSync(join(dir, "npm", "package.json"));
	result = await run();
	check("no installed packages: notice without probe", result.calls.length === 0
		&& result.notifications.some(([s]) => s.includes("No installed npm Pi packages")));
} finally {
	if (oldDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
	else process.env.PI_CODING_AGENT_DIR = oldDir;
	rmSync(dir, { recursive: true, force: true });
}
if (failures) process.exitCode = 1;
else console.log("ALL PASS");
