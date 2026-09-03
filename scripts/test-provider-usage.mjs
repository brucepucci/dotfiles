// Unit harness for dot_pi/agent/extensions/provider-usage.ts.
//
// Drives the extension through a fake pi object with stubbed fetch, and --
// importantly -- asserts footer rendering *through pi's sanitizeStatusText*,
// the same transform the built-in footer applies to extension statuses.
// Run directly (node scripts/test-provider-usage.mjs) or via smoke-test.sh.
//
// Needs node >= 20.3 (AbortSignal.any). jiti is resolved from pi's install
// so the TypeScript extension loads exactly the way pi loads it.

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
	console.error(`FAIL  cannot resolve jiti from ${PI_PACKAGE_DIR} (set PI_PACKAGE_DIR?)`);
	process.exit(1);
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

const makeCtx = (provider, hasUI = true) => ({
	hasUI,
	ui: {
		setStatus: (k, v) => statuses.set(k, v),
		theme: { fg: (n, t) => `<${n}>${t}` },
	},
	model: { provider },
	modelRegistry: { getProviderAuth: async () => ({ auth: { apiKey: "test-key" } }) },
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
