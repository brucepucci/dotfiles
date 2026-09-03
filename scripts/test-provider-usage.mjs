// Unit harness for dot_pi/agent/extensions/provider-usage.ts.
//
// Drives the extension through a fake pi object with stubbed fetch, and --
// importantly -- asserts footer rendering *through pi's sanitizeStatusText*,
// the same transform the built-in footer applies to extension statuses.
// Run directly (node scripts/test-provider-usage.mjs) or via smoke-test.sh.
//
// Needs node >= 20.3 (AbortSignal.any). jiti is resolved from pi's install
// so the TypeScript extension loads exactly the way pi loads it.
//
// Principle: fakes for pi objects must match the real object's CALL
// MECHANICS, not just its shape. Theme#fg is a prototype method reading
// this.fgColors, so the theme fake is a class (an arrow fake cannot catch
// an unbound extraction). Status text goes through sanitizeStatusText
// because the footer collapses space runs. Round-1 #2 and round-2 B-1
// both slipped past shape-only fakes.

import { createRequire } from "node:module";

// The expectations below are written in UTC; re-exec under TZ=UTC so the
// harness is deterministic regardless of the host timezone.
if (process.env.TZ !== "UTC") {
	const { spawnSync } = await import("node:child_process");
	const r = spawnSync(process.execPath, process.argv.slice(1), {
		env: { ...process.env, TZ: "UTC" },
		stdio: "inherit",
	});
	process.exit(r.status ?? 1);
}

const PI_PACKAGE_DIR =
	process.env.PI_PACKAGE_DIR ?? "/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent";

let jiti;
try {
	jiti = createRequire(`${PI_PACKAGE_DIR}/package.json`)("jiti");
} catch {
	// Behavioral checks run where pi lives (like the nvim steps in the
	// smoke test); CI runners have no pi install. The file-presence
	// assertion in smoke-test.sh still covers the managed path everywhere.
	console.log("  ok  provider-usage harness skipped: pi not installed here");
	process.exit(0);
}
const mod = await jiti.createJiti(import.meta.url).import(
	new URL("../dot_pi/agent/extensions/provider-usage.ts", import.meta.url).pathname,
);

let failures = 0;
const check = (name, cond, extra = "") => {
	if (!cond) failures++;
	console.log(`${cond ? "PASS" : "FAIL"}  ${name}${extra ? `  (${extra})` : ""}`);
};

// pi's own footer transform (dist/modes/interactive/components/footer.js) --
// what extension statuses actually pass through before display.
const sanitizeStatusText = (text) => text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();

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

const DAY = 24 * 3600e3;
const NOW = Date.parse("2026-09-03T12:00:00Z");

// ---------- pure helpers ----------

check("formatReset <24h -> clock time", mod.formatReset(NOW + 5 * 3600e3, NOW) === "17:00", mod.formatReset(NOW + 5 * 3600e3, NOW));
check("formatReset >24h -> weekday + time", mod.formatReset(NOW + 30 * 3600e3, NOW) === "Fri 18:00", mod.formatReset(NOW + 30 * 3600e3, NOW));
check("formatReset elapsed -> null", mod.formatReset(NOW - 60e3, NOW) === null);

const w5h = mod.zaiWindow({ unit: 3, number: 5, percentage: 1.4, nextResetTime: NOW + 3600e3 }, NOW);
const wWeek = mod.zaiWindow({ unit: 6, number: 1, percentage: 28, nextResetTime: NOW + 4 * DAY }, NOW);
check("zaiWindow 5h (ms epoch)", w5h?.label === "5h" && w5h.pct === 1 && w5h.resetMs === NOW + 3600e3);
check("zaiWindow week", wWeek?.label === "week" && wWeek.pct === 28);
check("zaiWindow seconds -> ms", mod.zaiWindow({ unit: 3, number: 5, percentage: 0, nextResetTime: Math.floor((NOW + 3600e3) / 1000) }, NOW)?.resetMs === NOW + 3600e3);
check("zaiWindow reset >30d ahead -> null resetMs", mod.zaiWindow({ unit: 3, number: 5, percentage: 0, nextResetTime: NOW + 60 * DAY }, NOW)?.resetMs === null);
check("zaiWindow number:0 -> 'quota' label", mod.zaiWindow({ unit: 3, number: 0, percentage: 5 }, NOW)?.label === "quota");
check("zaiWindow no percentage -> null", mod.zaiWindow({ unit: 3, number: 5 }) === null);

const sorted = mod.sortWindows([mod.zaiWindow({ unit: 6, number: 2, percentage: 0 }, NOW), wWeek, w5h]);
check("sortWindows 5h < week < 2w", sorted.map((w) => w.label).join(",") === "5h,week,2w", sorted.map((w) => w.label).join(","));
check("sortWindows unknown sinks", mod.sortWindows([{ label: "quota", pct: 0, resetMs: null }, w5h])[0].label === "5h");

// formatRow THROUGH the footer's sanitizer -- whitespace is not a separator.
const id = (_n, t) => t;
const row = mod.formatRow({
	head: "z.ai pro",
	windows: [w5h, wWeek],
	tokPerSec: 37,
	fg: id,
	now: NOW,
});
check(
	"formatRow full, survives sanitizeStatusText",
	sanitizeStatusText(row) === "z.ai pro · 5h 1% (resets 13:00) · week 28% (resets Mon 12:00) · 37 tok/s",
	sanitizeStatusText(row),
);
const rowPast = mod.formatRow({
	head: "claude",
	windows: [{ label: "5h", pct: 12, resetMs: NOW - 60e3 }],
	tokPerSec: 9,
	fg: id,
	now: NOW,
});
check("elapsed reset drops the (resets …) clause", sanitizeStatusText(rowPast) === "claude · 5h 12% · 9 tok/s", sanitizeStatusText(rowPast));
const rowBare = mod.formatRow({ head: "z.ai", windows: [], tokPerSec: 42, fg: id });
check("bare row (tok/s only)", sanitizeStatusText(rowBare) === "z.ai · 42 tok/s", sanitizeStatusText(rowBare));

const colors = [];
const capture = (n, t) => (colors.push(n), t);
mod.formatRow({ head: "x", windows: [{ label: "5h", pct: 95, resetMs: null }], tokPerSec: null, fg: capture });
check("pct >90 uses error", colors.includes("error"), colors.join(","));
colors.length = 0;
mod.formatRow({ head: "x", windows: [{ label: "5h", pct: 75, resetMs: null }], tokPerSec: null, fg: capture });
check("pct >70 uses warning", colors.includes("warning"), colors.join(","));
colors.length = 0;
mod.formatRow({ head: "x", windows: [{ label: "5h", pct: 3, resetMs: null }], tokPerSec: null, fg: capture });
check("pct low uses dim only", !colors.includes("error") && !colors.includes("warning"), colors.join(","));

// ---------- lifecycle against a fake pi ----------

const statuses = new Map();
let fetchMode = "ok"; // ok | fail | hang
let zaiCalls = 0;
let claudeCalls = 0;
let hangingReject;
globalThis.fetch = async (_url, opts) => {
	const url = String(_url);
	const isZai = url.includes("api.z.ai");
	if (isZai) zaiCalls++;
	else claudeCalls++;
	if (fetchMode === "fail") return { ok: false, status: 500, json: async () => ({}) };
	if (fetchMode === "hang")
		return new Promise((_resolve, reject) => {
			hangingReject = reject;
			opts?.signal?.addEventListener("abort", () => reject(new Error("aborted")));
		});
	return {
		ok: true,
		json: async () =>
			isZai
				? {
						success: true,
						data: {
							level: "pro",
							limits: [
								{ type: "CREDIT_LIMIT", unit: 3, number: 5, percentage: 1, nextResetTime: NOW + 3600e3 },
								{ type: "CREDIT_LIMIT", unit: 6, number: 1, percentage: 28, nextResetTime: NOW + 4 * DAY },
							],
						},
					}
				: {
						five_hour: { utilization: 0, resets_at: new Date(NOW + 3600e3).toISOString() },
						seven_day: { utilization: 2.0, resets_at: new Date(NOW + 4 * DAY).toISOString() },
					},
	};
};

const makeCtx = (provider, hasUI = true, authResult = { auth: { apiKey: "test-key" }, source: "OAuth" }) => ({
	hasUI,
	ui: {
		setStatus: (k, v) => statuses.set(k, v),
		notify: () => {},
		theme: new FakeTheme(),
	},
	model: { provider },
	modelRegistry: { getProviderAuth: async () => authResult },
});

const handlers = {};
const settle = () => new Promise((r) => setTimeout(r, 20));
const realNow = Date.now();
const shiftClock = (ms) => {
	Date.now = () => realNow + ms;
};

// Print mode: no UI, no credential traffic.
{
	const h = {};
	mod.default({ on: (n, f) => (h[n] = f), ui: { setStatus: () => {} } });
	const before = zaiCalls + claudeCalls;
	await h.session_start({}, makeCtx("zai", false));
	await settle();
	check("hasUI false: no quota requests", zaiCalls + claudeCalls === before);
}

const pi = { on: (n, f) => (handlers[n] = f), ui: { setStatus: (k, v) => statuses.set(k, v) } };
mod.default(pi);

await handlers.session_start({}, makeCtx("zai"));
await settle();
check("z.ai row rendered (plan + windows)", (statuses.get("provider-usage") ?? "").includes("z.ai pro"), statuses.get("provider-usage"));
check("theme.fg invoked with receiver (B-1)", (statuses.get("provider-usage") ?? "").includes("<dim>z.ai pro"), statuses.get("provider-usage"));
check("no tok/s before first response", !statuses.get("provider-usage").includes("tok/s"));

// Response with a TTFT gap: anchor must be the first streamed token, not start.
await handlers.message_start({ message: { role: "assistant" } }, makeCtx("zai"));
await new Promise((r) => setTimeout(r, 30)); // "TTFT" -- must be excluded
await handlers.message_update({ message: { role: "assistant" } }, makeCtx("zai"));
const genStart = Date.now();
await new Promise((r) => setTimeout(r, 30)); // generation time
await handlers.message_end({ message: { role: "assistant", usage: { output: 3000 } } }, makeCtx("zai"));
const tok = Number((statuses.get("provider-usage") ?? "").match(/(\d+) tok\/s/)?.[1] ?? 0);
// 3000 tokens over the ~30ms generation sleep: ~100k tok/s. If TTFT (the
// first 30ms sleep) were included the rate would halve to ~50k.
check("tok/s anchored at first streamed token (TTFT excluded)", tok > 75_000, `${tok} tok/s`);

// A response with no streamed updates accumulates nothing.
const before2 = statuses.get("provider-usage");
await handlers.message_start({ message: { role: "assistant" } }, makeCtx("zai"));
await handlers.message_end({ message: { role: "assistant", usage: { output: 9999 } } }, makeCtx("zai"));
check("no-anchor response accumulates nothing", statuses.get("provider-usage") === before2);

// Switch to anthropic.
await handlers.model_select({ model: { provider: "anthropic" } }, makeCtx("anthropic"));
await settle();
check("claude row rendered", (statuses.get("provider-usage") ?? "").includes("claude"), statuses.get("provider-usage"));

// Switch to an unsupported provider -> row hidden.
await handlers.model_select({ model: { provider: "openai" } }, makeCtx("openai"));
check("row cleared for other providers", statuses.get("provider-usage") === undefined);

// Back to z.ai: served from cache without a new request.
const zaiBefore = zaiCalls;
await handlers.model_select({ model: { provider: "zai" } }, makeCtx("zai"));
await settle();
check("fresh cache served without refetch", zaiCalls === zaiBefore);
check("row restored from cache", (statuses.get("provider-usage") ?? "").includes("z.ai pro"));

// Stale cache + failing poll: the last known-good quota survives.
shiftClock(31_000); // past STALE_MS
fetchMode = "fail";
await handlers.model_select({ model: { provider: "zai" } }, makeCtx("zai"));
await settle();
check("failed poll preserves cached quota", (statuses.get("provider-usage") ?? "").includes("5h"), statuses.get("provider-usage"));

// ...until it ages out (MAX_AGE_MS).
shiftClock(11 * 60e3);
await handlers.model_select({ model: { provider: "zai" } }, makeCtx("zai"));
await settle();
check("aged-out quota hides, tok/s remains", (statuses.get("provider-usage") ?? "").includes("tok/s") && !(statuses.get("provider-usage") ?? "").includes("5h"), statuses.get("provider-usage"));
Date.now = () => realNow;
fetchMode = "ok";

// M-1: Anthropic API-key auth must be skipped (no plan quota; would 401
// forever); only OAuth-sourced credentials may hit the usage endpoint.
{
	const before = claudeCalls;
	const h = {};
	const st = new Map();
	mod.default({ on: (n, f) => (h[n] = f), ui: { setStatus: (k, v) => st.set(k, v) } });
	await h.session_start({}, makeCtx("anthropic", true, { auth: { apiKey: "sk-ant-api" }, source: "ANTHROPIC_API_KEY" }));
	await settle();
	check("M-1: API-key anthropic skipped", claudeCalls === before && statuses.get("provider-usage") === undefined, `claudeCalls=${claudeCalls - before}`);
}
{
	const before = claudeCalls;
	const h = {};
	const st = new Map();
	mod.default({ on: (n, f) => (h[n] = f), ui: { setStatus: (k, v) => st.set(k, v) } });
	await h.session_start({}, makeCtx("anthropic", true, { auth: { apiKey: "oauth-token" }, source: "OAuth" }));
	await settle();
	check("M-1: OAuth anthropic still fetched", claudeCalls === before + 1 && (statuses.get("provider-usage") ?? "").includes("claude"), `claudeCalls=+${claudeCalls - before}`);
}

// A render() that throws must not take the session down, and must not
// spam notifications on every poll (round-2 B-1 hardening).
{
	const h = {};
	const notifications = [];
	const throwCtx = {
		hasUI: true,
		ui: {
			setStatus: () => {
				throw new Error("boom");
			},
			notify: (m) => notifications.push(m),
			theme: new FakeTheme(),
		},
		model: { provider: "zai" },
		modelRegistry: { getProviderAuth: async () => ({ auth: { apiKey: "k" }, source: "stored" }) },
	};
	mod.default({ on: (n, f) => (h[n] = f), ui: { setStatus: () => {} } });
	await h.session_start({}, throwCtx);
	await settle();
	check("render throw survives, notifies once", notifications.length === 1, JSON.stringify(notifications));
	shiftClock(31_000);
	await h.model_select({ model: { provider: "zai" } }, throwCtx);
	await settle();
	check("render failure notifies once, not per poll", notifications.length === 1);
	Date.now = () => realNow;
}

// Teardown while a fetch is in flight: aborted, and settling must not crash
// (stale ctx must never be touched after session_shutdown).
fetchMode = "hang";
let hangAborted = false;
globalThis.fetch = async (_url, opts) =>
	new Promise((_resolve, reject) => {
		opts?.signal?.addEventListener("abort", () => {
			hangAborted = true;
			reject(new Error("aborted"));
		});
	});
shiftClock(31_000); // make the anthropic cache stale so a fetch actually fires
await handlers.model_select({ model: { provider: "anthropic" } }, makeCtx("anthropic"));
await new Promise((r) => setTimeout(r, 20)); // let the fetch start
await handlers.session_shutdown({}, null);
check("shutdown aborts in-flight fetch", hangAborted, `aborted=${hangAborted}`);
await settle(); // the aborted fetch rejects into .catch(render) -> must no-op
check("process survives settle-after-shutdown", true);

console.log(failures === 0 ? "\nALL PASS" : `\n${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
