// Unit harness for dot_pi/agent/extensions/title-screen.ts.
//
// Drives the extension through a fake pi object and asserts the rendered
// splash: art geometry (every row 13 columns, flush left, ONE color for
// the whole block drawn from the role pool, render independent of the
// terminal width), the caption (launch model + effort, dropped entirely
// when pi starts without a model), and the startup gating (reason
// "startup" + tui mode only, like a title screen should). Theme#fg is
// faked as a prototype method reading the receiver, the same call
// mechanics as pi's own Theme -- an unbound extraction throws, so the
// fake catches it (see test-provider-usage.mjs).
//
// Run directly (node scripts/test-title-screen.mjs) or via smoke-test.sh.
// jiti is resolved from pi's install so the TypeScript extension loads
// exactly the way pi loads it (with the same package alias pi's own
// loader installs for built Node mode). Where pi is not installed the
// harness skips (the file-presence assertion in smoke-test.sh still
// covers the managed path everywhere).

import { createRequire } from "node:module";

const PI_PACKAGE_DIR =
	process.env.PI_PACKAGE_DIR ?? "/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent";

let jiti;
try {
	jiti = createRequire(`${PI_PACKAGE_DIR}/package.json`)("jiti");
} catch {
	console.log("  ok  title-screen harness skipped: pi not installed here");
	process.exit(0);
}
const mod = await jiti
	.createJiti(import.meta.url, {
		// the same alias pi's own extension loader installs for built Node
		// mode (loader.js getAliases): the repo has no node_modules upstream
		// of the extension, so the bare specifier would not otherwise resolve
		alias: { "@earendil-works/pi-coding-agent": `${PI_PACKAGE_DIR}/dist/index.js` },
	})
	.import(new URL("../dot_pi/agent/extensions/title-screen.ts", import.meta.url).pathname);

let failures = 0;
const check = (name, cond, extra = "") => {
	if (!cond) failures++;
	console.log(`${cond ? "PASS" : "FAIL"}  ${name}${extra ? `  (${extra})` : ""}`);
};

// pi's Theme#fg is a prototype method that reads this.fgColors -- this fake
// throws the same way if the extension ever extracts it unbound. Its
// <role> markers are literal text, so the harness strips them (plus real
// SGR escapes) to measure display widths.
class FakeTheme {
	constructor() {
		this.marker = "<";
	}
	fg(n, t) {
		return `${this.marker}${n}>${t}`;
	}
}
const strip = (s) => s.replace(/\x1b\[[0-9;]*m/g, "").replace(/<\w+>/g, "");

// ---------- the rendered splash, through the fake theme ----------

const headers = [];
const commands = {};
const handlers = {};
const pi = {
	on: (n, f) => (handlers[n] = f),
	registerCommand: (n, o) => (commands[n] = o),
};
mod.default(pi);

const tuiCtx = () => ({
	mode: "tui",
	hasUI: true,
	model: { provider: "zai", id: "glm-5.3" },
	thinkingLevel: "high",
	ui: { setHeader: (f) => headers.push(f), notify: () => {} },
});

// gating: a title screen shows at startup, in the TUI, and only there
await handlers.session_start({ reason: "resume" }, tuiCtx());
check("resume does not re-show the splash", headers.length === 0);
await handlers.session_start({ reason: "startup" }, { mode: "print", hasUI: false, ui: { setHeader: (f) => headers.push(f) } });
check("print mode shows no splash", headers.length === 0);
await handlers.session_start({ reason: "startup" }, tuiCtx());
check("startup + tui installs the header once", headers.length === 1 && typeof headers[0] === "function");

// The block color is fixed (mdHeading -- pi's section-header role), so the
// component is fully deterministic.
const comp = headers[0](undefined, new FakeTheme());
check("header component exposes render/invalidate", typeof comp.render === "function" && typeof comp.invalidate === "function");
comp.invalidate(); // must be a safe no-op

const lines = comp.render(80);
check("80 cols: blank + 8 art rows + caption", lines.length === 10, lines.length);
check("leading blank line", lines[0] === "");
check("art at the indent, in the section-header role", lines.slice(1, 9).every((l) => l.startsWith("  <mdHeading>") && !l.startsWith("   <")), lines[1]);
check("art rows are the 13-column glyph", lines.slice(1, 9).map(strip).every((s) => s.length === 13 + 2), lines.slice(1, 9).map(strip).join(" | "));
check("caption is model + effort at the indent", lines[9] === "  <dim>glm-5.3<muted> · <dim>high", lines[9]);
check("caption joins on one muted dot", (lines[9]?.match(/<muted> · /g) ?? []).length === 1);

// the render no longer reads the terminal width: identical at any size
check("render is width-independent", JSON.stringify(comp.render(20)) === JSON.stringify(lines) && JSON.stringify(comp.render(200)) === JSON.stringify(lines));

// pi started without a model: the caption drops out entirely
{
	const h = {};
	const hs = [];
	mod.default({ on: (n, f) => (h[n] = f), registerCommand: () => {} });
	await h.session_start({ reason: "startup" }, {
		mode: "tui",
		hasUI: true,
		model: undefined,
		thinkingLevel: undefined,
		ui: { setHeader: (f) => hs.push(f), notify: () => {} },
	});
	const c = hs[0](undefined, new FakeTheme());
	const bare = c.render(80);
	check("no model: caption gone, art only", bare.length === 9 && bare.slice(1, 9).every((l) => l.startsWith("  <mdHeading>")), bare.length);
}

// ---------- commands ----------

await commands["builtin-header"].handler([], tuiCtx());
check("/builtin-header restores pi's header", headers.at(-1) === undefined);
await commands["title-screen"].handler([], tuiCtx());
check("/title-screen re-installs the splash", typeof headers.at(-1) === "function");
await commands["builtin-header"].handler([], { mode: "print", hasUI: false, ui: { setHeader: (f) => headers.push(f), notify: () => {} } });
check("/builtin-header safe outside the tui", headers.at(-1) === undefined);

console.log(failures === 0 ? "\nALL PASS" : `\n${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
