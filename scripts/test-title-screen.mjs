// Unit harness for dot_pi/agent/extensions/title-screen.ts.
//
// Drives the extension through a fake pi object and asserts the rendered
// splash: art geometry (every row the same width, ONE color for the whole
// block, drawn from the role pool), the caption (project url + the launch
// model and effort, centered, segments dropping when pi starts without a
// model), and the startup gating (reason "startup" + tui mode only, like
// a title screen should). Theme#fg is faked as a prototype method reading
// the receiver, the same call mechanics as pi's own Theme -- an unbound
// extraction throws, so the fake catches it (see test-provider-usage.mjs).
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
// throws the same way if the extension ever extracts it unbound.
class FakeTheme {
	constructor() {
		this.marker = "<";
	}
	fg(n, t) {
		return `${this.marker}${n}>${t}`;
	}
}

// ---------- pure helpers ----------

check("visibleWidth strips SGR escapes", mod.visibleWidth("\x1b[1;38;5;4mab\x1b[0m") === 2, mod.visibleWidth("\x1b[1;38;5;4mab\x1b[0m"));
check("visibleWidth plain string", mod.visibleWidth("pi") === 2);

check("centerPad centers on wide terminals", mod.centerPad(80, 13) === 33, mod.centerPad(80, 13));
check("centerPad rounds down", mod.centerPad(21, 8) === 6, mod.centerPad(21, 8));
check("centerPad clamps to 0 when it does not fit", mod.centerPad(12, 13) === 0);

// the color pool: roles only -- the repo's whole theming contract in one
// array -- and pickColor maps an rng uniformly onto it
check("pool is three roles", mod.COLOR_POOL.length === 3, mod.COLOR_POOL.join(","));
check("pool carries no hexes/raw indices", mod.COLOR_POOL.every((c) => ["accent", "mdCode", "dim"].includes(c)), mod.COLOR_POOL.join(","));
check("pickColor rng=0 -> first", mod.pickColor(() => 0) === "accent");
check("pickColor rng just under 1/3 -> first", mod.pickColor(() => 0.3299) === "accent");
check("pickColor rng mid -> second", mod.pickColor(() => 0.34) === "mdCode");
check("pickColor rng 2/3+ -> third", mod.pickColor(() => 0.67) === "dim");
check("pickColor rng ->1 stays in pool", mod.pickColor(() => 0.999) === "dim");
check("pickColor default rng works", ["accent", "mdCode", "dim"].includes(mod.pickColor()));

// ---------- the rendered splash, through the fake theme ----------

const headers = [];
const commands = {};
const handlers = {};
const pi = {
	on: (n, f) => (handlers[n] = f),
	registerCommand: (n, o) => (commands[n] = o),
};
mod.default(pi);

const PROJECT_URL = "https://github.com/earendil-works/pi";
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

// Pin the draw: rng 0.9 -> "dim". The factory is invoked once; the whole
// block must share that one role.
const realRandom = Math.random;
Math.random = () => 0.9;
const comp = headers[0](undefined, new FakeTheme());
Math.random = realRandom;
check("header component exposes render/invalidate", typeof comp.render === "function" && typeof comp.invalidate === "function");
comp.invalidate(); // must be a safe no-op

// 80 columns: art centered at pad 33, one role across all rows, caption
// centered on its visible width. Fake theme marks fg() calls as <role>text.
const lines = comp.render(80);
check("80 cols: blank + 8 art rows + caption", lines.length === 10, lines.length);
check("leading blank line", lines[0] === "");
const fades = lines.slice(1, 9).map((l) => /^ {33}<(\w+)>/.exec(l)?.[1]);
check("one role colors the whole block", fades.every((c) => c === "dim"), fades.join(","));
// with the fake theme the <role> markers are literal text, so expected
// visible width = pad + marker + art row
const artVisible = lines.slice(1, 9).map((l) => mod.visibleWidth(l));
check("art rows all 33 + marker + 13 columns", artVisible.every((w) => w === 33 + 3 + 2 + 13), artVisible.join(","));
const caption = lines[9] ?? "";
check("caption names the project url", caption.includes(PROJECT_URL), caption.slice(0, 48));
check("caption names the launch model", caption.includes("<dim>glm-5.3"));
check("caption names the launch effort", caption.includes("<dim>high"));
check("caption joins url/model/effort on two muted dots", (caption.match(/<muted> · /g) ?? []).length === 2, caption);
check("caption centered on its visible width", caption === " ".repeat(mod.centerPad(80, mod.visibleWidth(caption))) + caption.trimStart(), mod.visibleWidth(caption));

// narrow terminals: art left-aligns at pad 3, caption overflows without pad
const narrow = comp.render(20);
check("20 cols: art at pad 3", narrow.length === 10 && narrow[1]?.startsWith("   <dim>"), narrow[1]?.slice(0, 20));
check("20 cols: caption overflows flush left", narrow[9]?.startsWith("<dim>"), narrow[9]?.slice(0, 24));

// pi started without a model: the url stands alone
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
	Math.random = () => 0; // -> "accent"
	const c = hs[0](undefined, new FakeTheme());
	Math.random = realRandom;
	const bare = c.render(80);
	check("no model: caption is the bare url", bare.length === 10 && bare[9]?.trim() === `<dim>${PROJECT_URL}` && (bare[9].match(/<muted>/g) ?? []).length === 0, bare[9]?.trim());
	check("no model: block still fully colored", bare.slice(1, 9).every((l) => l.startsWith(" ".repeat(33) + "<accent>")));
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
