// Unit harness for dot_pi/agent/extensions/title-screen.ts.
//
// Drives the extension through a fake pi object and asserts the rendered
// splash: art geometry (13-column glyph, two-space indent, compact
// fallback below 15 columns, render independent of width above that),
// the fixed section-header role (mdHeading, the role behind pi's own
// [Context]/[Skills]/[Extensions] startup headers), the caption (model
// always when present; effort only for reasoning models -- pi's agent
// state initializes thinkingLevel to "off", never undefined, so a
// fabricated undefined would assert an impossible state), the gating
// (installed on EVERY session_start reason -- pi resets extension UI
// before each rebind, so skipping one strands the stock header -- but
// never outside the tui), and both commands. Theme#fg is faked as a
// prototype method reading the receiver, the same call mechanics as
// pi's own Theme -- an unbound extraction throws, so the fake catches
// it (see test-provider-usage.mjs).
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
// No specifier alias needed: the extension imports from pi's package
// type-only, and jiti's TS transform erases those before resolution.
const mod = await jiti
	.createJiti(import.meta.url)
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
mod.default({
	on: (n, f) => (handlers[n] = f),
	registerCommand: (n, o) => (commands[n] = o),
});

// pi's real command handlers receive (args: string, ctx) -- match the
// call mechanics, not just the shape.
const tuiCtx = () => ({
	mode: "tui",
	hasUI: true,
	model: { provider: "zai", id: "glm-5.3", reasoning: true },
	thinkingLevel: "high",
	ui: { setHeader: (f) => headers.push(f), notify: () => {} },
});

// gating: installed in the tui, on EVERY session_start reason (pi resets
// extension-managed UI before each rebind -- /new, /resume, /fork and
// /reload included -- so a skipped reason strands the stock header)
await handlers.session_start({ reason: "startup" }, tuiCtx());
check("startup installs", headers.length === 1);
for (const reason of ["new", "resume", "fork", "reload"]) {
	await handlers.session_start({ reason }, tuiCtx());
	check(`${reason} re-installs (pi reset the header first)`, headers.length === 2 + ["new", "resume", "fork", "reload"].indexOf(reason));
}
await handlers.session_start({ reason: "startup" }, { mode: "print", hasUI: false, ui: { setHeader: (f) => headers.push(f) } });
check("print mode installs nothing", headers.length === 5, headers.length);

// the last installed factory, rendered through the fake theme
const comp = headers.at(-1)(undefined, new FakeTheme());
check("header component exposes render/invalidate", typeof comp.render === "function" && typeof comp.invalidate === "function");
comp.invalidate(); // must be a safe no-op

const lines = comp.render(80);
check("80 cols: 8 art rows + caption, no leading blank (pi's Spacer handles that)", lines.length === 9, lines.length);
check("art at the indent, in the section-header role", lines.slice(0, 8).every((l) => l.startsWith("  <mdHeading>")), lines[0]);
check("art rows are the 13-column glyph", lines.slice(0, 8).map(strip).every((s) => s.length === 13 + 2), lines.slice(0, 8).map(strip).join(" | "));
check("caption is model + effort at the indent", lines[8] === "  <dim>glm-5.3<muted> · <dim>high", lines[8]);
check("caption joins on one muted dot", (lines[8]?.match(/<muted> · /g) ?? []).length === 1);

// above the compact threshold the render never reads the terminal width
check(
	"render is width-independent above the art width",
	JSON.stringify(comp.render(20)) === JSON.stringify(lines) && JSON.stringify(comp.render(200)) === JSON.stringify(lines),
);
// below it: a compact one-liner instead of a wrapped, mangled block
const narrow = comp.render(14);
check("below the art width: compact one-liner", narrow.length === 1 && narrow[0] === "  <mdHeading>pi", narrow[0]);
check("art-width boundary renders the block", comp.render(15).length === 9);

// caption variants pi can actually produce:
{
	const hs = [];
	const render = (model, thinkingLevel) => {
		handlers.session_start({ reason: "startup" }, {
			mode: "tui",
			hasUI: true,
			model,
			thinkingLevel,
			ui: { setHeader: (f) => hs.push(f), notify: () => {} },
		});
		return hs.at(-1)(undefined, new FakeTheme()).render(80);
	};
	// non-reasoning model: no effort segment, ever (mirrors pi's footer)
	check(
		"non-reasoning model: caption is the bare model",
		render({ provider: "openai", id: "gpt-5-mini", reasoning: false }, "high").at(-1) === "  <dim>gpt-5-mini",
	);
	// reasoning model parked at off: the level shows (footer: "thinking off")
	check(
		"reasoning model at off: caption carries 'off'",
		render({ provider: "zai", id: "glm-5.3", reasoning: true }, "off").at(-1) === "  <dim>glm-5.3<muted> · <dim>off",
	);
	// no model: caption drops out entirely (agent state's "off" must not leak)
	const none = render(undefined, "off");
	check(
		"no model: caption gone, art only",
		none.length === 8 && none.every((l) => l.includes("<mdHeading>")),
		none.length,
	);
}

// ---------- commands ----------

await commands["builtin-header"].handler("", tuiCtx());
check("/builtin-header restores pi's header", headers.at(-1) === undefined);
await commands["title-screen"].handler("", tuiCtx());
check("/title-screen re-installs the splash", typeof headers.at(-1) === "function");
{
	// outside the tui both commands must be true no-ops -- RPC's setHeader
	// is a no-op while notify is real, so an unguarded handler would claim
	// success while doing nothing
	const sentinel = "SENTINEL";
	const saw = [];
	const rpcishCtx = {
		mode: "rpc",
		hasUI: true,
		model: { provider: "zai", id: "glm-5.3", reasoning: true },
		thinkingLevel: "high",
		ui: { setHeader: (f) => saw.push(f), notify: () => saw.push("NOTIFY") },
	};
	saw.push(sentinel);
	await commands["builtin-header"].handler("", rpcishCtx);
	check("/builtin-header no-ops outside the tui (no false success)", saw.at(-1) === sentinel, saw.join(","));
	await commands["title-screen"].handler("", rpcishCtx);
	check("/title-screen no-ops outside the tui", saw.at(-1) === sentinel, saw.join(","));
}

console.log(failures === 0 ? "\nALL PASS" : `\n${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
