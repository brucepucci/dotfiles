// Unit harness for dot_pi/agent/extensions/title-screen.ts.
//
// Drives the extension through a fake pi object and asserts the rendered
// splash: art geometry (every row the same width), the fade (one theme
// role per row, blue -> aqua -> dim, never brightening downward), the
// digit line (whole 5-digit groups of pi, never over budget), and the
// startup gating (reason "startup" + tui mode only, like a title screen
// should). Theme#fg is faked as a prototype method reading the receiver,
// the same call mechanics as pi's own Theme -- an unbound extraction
// throws, so the fake catches it (see test-provider-usage.mjs).
//
// Run directly (node scripts/test-title-screen.mjs) or via smoke-test.sh.
// jiti is resolved from pi's install so the TypeScript extension loads
// exactly the way pi loads it. Where pi is not installed the harness
// skips (the file-presence assertion in smoke-test.sh still covers the
// managed path everywhere).

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
check("visibleWidth plain string", mod.visibleWidth("3.14159") === 7);

check("centerPad centers on wide terminals", mod.centerPad(80, 13) === 33, mod.centerPad(80, 13));
check("centerPad rounds down", mod.centerPad(21, 8) === 6, mod.centerPad(21, 8));
check("centerPad clamps to 0 when it does not fit", mod.centerPad(12, 13) === 0);

// pi's digits: the first 100 places, transcribed independently of the
// extension so an accidental edit cannot pass against itself.
const PI_100 =
	"3." +
	"14159265358979323846264338327950288419716939937510" +
	"58209749445923078164062862089986280348253421170679";

check("piDigits: room for exactly one group", mod.piDigits(7) === "3.14159", mod.piDigits(7));
check("piDigits: no room -> null", mod.piDigits(6) === null);
const d80 = mod.piDigits(80);
check("piDigits(80): 13 groups, 79 columns", d80?.length === 79, d80);
check("piDigits(80) is a prefix of pi", PI_100.startsWith(d80?.replaceAll(" ", "") ?? "?"), d80);
const d1000 = mod.piDigits(1000);
check("piDigits(1000) carries all 100 places", d1000?.replaceAll(" ", "") === PI_100, d1000?.slice(0, 30));
check(
	"piDigits groups are 5 wide after '3.'",
	(d1000?.slice(2).split(" ") ?? []).every((g) => g.length === 5),
);
let overBudget = [];
for (let b = 0; b <= 120; b++) {
	const line = mod.piDigits(b);
	if (line !== null && line.length > b) overBudget.push(`${b}:${line.length}`);
}
check("piDigits never exceeds its budget", overBudget.length === 0, overBudget.join(","));
let offGrid = [];
for (let b = 7; b <= 120; b++) {
	const line = mod.piDigits(b);
	// "3." + n groups joined by single spaces -> length 6n + 1
	if (line !== null && (line.length - 1) % 6 !== 0) offGrid.push(`${b}:${line.length}`);
}
check("piDigits truncates on group boundaries only", offGrid.length === 0, offGrid.join(","));

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
	ui: { setHeader: (f) => headers.push(f), notify: () => {} },
});

// gating: a title screen shows at startup, in the TUI, and only there
await handlers.session_start({ reason: "resume" }, tuiCtx());
check("resume does not re-show the splash", headers.length === 0);
await handlers.session_start({ reason: "startup" }, { mode: "print", hasUI: false, ui: { setHeader: (f) => headers.push(f) } });
check("print mode shows no splash", headers.length === 0);
await handlers.session_start({ reason: "startup" }, tuiCtx());
check("startup + tui installs the header once", headers.length === 1 && typeof headers[0] === "function");

const comp = headers[0](undefined, new FakeTheme());
check("header component exposes render/invalidate", typeof comp.render === "function" && typeof comp.invalidate === "function");
comp.invalidate(); // must be a safe no-op

// 80 columns: art centered at pad 33, digits fill 79, hints centered on
// their visible width. Fake theme marks fg() calls as <role>text.
const lines = comp.render(80);
check("80 cols: blank + 8 art rows + digits + hints", lines.length === 11, lines.length);
check("leading blank line", lines[0] === "");
const fades = ["accent", "accent", "accent", "mdCode", "mdCode", "mdCode", "dim", "dim"];
// with the fake theme the <role> markers are literal text, so expected
// visible width = pad + marker + art row
const artVisible = lines.slice(1, 9).map((l) => mod.visibleWidth(l));
check(
	"art rows all 33 + marker + 13 columns",
	artVisible.every((w, i) => w === 33 + fades[i].length + 2 + 13),
	artVisible.join(","),
);
lines.slice(1, 9).forEach((line, i) => {
	check(`art row ${i} faded ${fades[i]} and centered`, line.startsWith(" ".repeat(33) + `<${fades[i]}>`), line.slice(0, 44));
});
check("digits row exact: muted, centered, 13 groups", lines[9] === `<muted>${d80}`, lines[9]?.slice(0, 30));
const hintsVisible = mod.visibleWidth(lines[10]);
check("hints centered on their visible width", lines[10] === " ".repeat(mod.centerPad(80, hintsVisible)) + lines[10].trimStart(), hintsVisible);
for (const desc of ["interrupt", "clear/exit", "commands", "bash", "more"]) {
	check(`hints carry '${desc}'`, (lines[10] ?? "").includes(` ${desc}`));
}
check("hints join on muted middle dots", (lines[10]?.match(/<muted> · /g) ?? []).length === 5);
check("hints carry the version", /v\d/.test(lines[10] ?? ""), (lines[10] ?? "").slice(-30));

// narrow terminals: art left-aligns at pad 0, digits shrink to whole groups
const narrow = comp.render(20);
check("20 cols: art at pad 3, digits 19 wide", narrow.length === 11 && narrow[9] === `<muted>${mod.piDigits(20)}`, narrow[9]);
check("20 cols: art rows 16 visible columns", narrow.slice(1, 9).every((l) => l.startsWith(" ".repeat(3) + "<")), narrow[1]?.slice(0, 20));
const tiny = comp.render(12);
check("12 cols: one digit group survives, art flush left", tiny.length === 11 && tiny[1]?.startsWith("<accent>") && tiny[9] === "  <muted>3.14159", tiny[9]);
const micro = comp.render(6);
check("6 cols: digits dropped, art flush left", micro.length === 10 && micro[1]?.startsWith("<accent>"), micro.length);

// ---------- commands ----------

await commands["builtin-header"].handler([], tuiCtx());
check("/builtin-header restores pi's header", headers.at(-1) === undefined);
await commands["title-screen"].handler([], tuiCtx());
check("/title-screen re-installs the splash", typeof headers.at(-1) === "function");
await commands["builtin-header"].handler([], { mode: "print", hasUI: false, ui: { setHeader: (f) => headers.push(f), notify: () => {} } });
check("/builtin-header safe outside the tui", headers.at(-1) === undefined);

console.log(failures === 0 ? "\nALL PASS" : `\n${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
