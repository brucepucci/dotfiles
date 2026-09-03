/**
 * provider-usage -- a footer status row for plan quotas + generation speed.
 *
 * Renders (via ctx.ui.setStatus) one line below pi's built-in footer stats,
 * showing only the provider that owns the active model:
 *
 *   z.ai pro  5h 3% (resets 14:32)  week 28% (resets Sat 09:07)  37 tok/s
 *   claude  5h 0% (resets 18:10)  week 2% (resets Fri 02:00)  55 tok/s
 *
 * - tok/s: output tokens per second, session average (convention: generated
 *   tokens / generation time), accumulated from message_start/message_end.
 * - z.ai quota: GET api.z.ai/api/monitor/usage/quota/limit (the endpoint the
 *   z.ai console uses); key from ~/.pi/agent/auth.json, else $ZAI_API_KEY.
 * - Claude quota: GET api.anthropic.com/api/oauth/usage with the OAuth token
 *   pi stores after /login (Claude Pro/Max). API-key auth has no plan quota
 *   and is silently skipped.
 *
 * Quota polls every 60s and on model switches; fetches are fire-and-forget
 * and failures just hide the affected segments.
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ---------- types ----------

type QuotaWindow = { label: string; pct: number; resetMs: number | null };
type Quota = { plan: string | null; windows: QuotaWindow[]; fetchedAt: number };
type Cache = { quota?: Quota; failedAt?: number };
type Fg = (name: string, text: string) => string;

const POLL_MS = 60_000;
const STALE_MS = 30_000;
const DAY_MS = 24 * 60 * 60 * 1000;

// ---------- pure helpers (exported for testing) ----------

/** "14:32" for resets within 24h, "Sat 14:32" beyond. */
export function formatReset(resetMs: number, now: number = Date.now()): string {
	const d = new Date(resetMs);
	const time = d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false });
	if (resetMs - now < DAY_MS) return time;
	return `${d.toLocaleDateString("en-US", { weekday: "short" })} ${time}`;
}

/** z.ai limits[] entry -> window; unit 3 = hours, 6 = weeks (observed). */
export function zaiWindow(entry: {
	unit?: number;
	number?: number;
	percentage?: number;
	nextResetTime?: number;
}): QuotaWindow | null {
	if (typeof entry.percentage !== "number") return null;
	const label =
		entry.unit === 3 && entry.number
			? `${entry.number}h`
			: entry.unit === 6 && entry.number === 1
				? "week"
				: entry.unit === 6 && entry.number
					? `${entry.number}w`
					: "quota";
	return { label, pct: Math.round(entry.percentage), resetMs: entry.nextResetTime ?? null };
}

/** Sort shorter windows first; unknown labels sink. */
export function sortWindows(windows: QuotaWindow[]): QuotaWindow[] {
	const weight = (label: string) =>
		/^(\d+)h$/.test(label) ? Number(label.slice(0, -1)) : label === "week" ? 168 : 1e6;
	return [...windows].sort((a, b) => weight(a.label) - weight(b.label));
}

/** "z.ai pro  5h 3% (resets 14:32)  week 28% (resets Sat 09:07)  37 tok/s" */
export function formatRow(opts: {
	head: string;
	windows: QuotaWindow[];
	tokPerSec: number | null;
	fg: Fg;
	now?: number;
}): string {
	const { fg } = opts;
	const parts: string[] = [fg("dim", opts.head)];
	for (const w of opts.windows) {
		const pct = w.pct > 90 ? fg("error", `${w.pct}%`) : w.pct > 70 ? fg("warning", `${w.pct}%`) : fg("dim", `${w.pct}%`);
		const reset = w.resetMs ? fg("dim", ` (resets ${formatReset(w.resetMs, opts.now)})`) : "";
		parts.push(`${fg("dim", w.label)} ${pct}${reset}`);
	}
	if (opts.tokPerSec !== null) parts.push(fg("dim", `${opts.tokPerSec} tok/s`));
	return parts.join("  ");
}

// ---------- credentials (re-read each fetch so pi's OAuth refreshes are picked up) ----------

function authEntry(provider: string): { type?: string; key?: string; access?: string } | undefined {
	try {
		return JSON.parse(readFileSync(join(homedir(), ".pi", "agent", "auth.json"), "utf8"))?.[provider];
	} catch {
		return undefined;
	}
}

function zaiKey(): string | undefined {
	return authEntry("zai")?.key ?? process.env.ZAI_API_KEY;
}

function claudeOAuthToken(): string | undefined {
	const entry = authEntry("anthropic");
	return entry?.type === "oauth" ? entry.access : undefined;
}

// ---------- fetchers ----------

async function fetchJson(url: string, headers: Record<string, string>): Promise<unknown> {
	const res = await fetch(url, { headers, signal: AbortSignal.timeout(8000) });
	if (!res.ok) throw new Error(`HTTP ${res.status}`);
	return res.json();
}

async function fetchZai(): Promise<Quota | null> {
	const key = zaiKey();
	if (!key) return null;
	const body = (await fetchJson("https://api.z.ai/api/monitor/usage/quota/limit", { Authorization: key })) as {
		data?: { level?: string; limits?: Array<Parameters<typeof zaiWindow>[0]> };
	};
	const windows = sortWindows((body.data?.limits ?? []).map(zaiWindow).filter((w): w is QuotaWindow => w !== null));
	if (!windows.length) return null;
	return { plan: body.data?.level ?? null, windows, fetchedAt: Date.now() };
}

function parseReset(iso: string | null | undefined): number | null {
	if (!iso) return null;
	const t = Date.parse(iso);
	return Number.isNaN(t) ? null : t;
}

async function fetchClaude(): Promise<Quota | null> {
	const token = claudeOAuthToken();
	if (!token) return null;
	const body = (await fetchJson("https://api.anthropic.com/api/oauth/usage", {
		Authorization: `Bearer ${token}`,
		"anthropic-beta": "oauth-2025-04-20",
		Accept: "application/json",
	})) as {
		five_hour?: { utilization?: number; resets_at?: string | null } | null;
		seven_day?: { utilization?: number; resets_at?: string | null } | null;
	};
	const windows: QuotaWindow[] = [];
	if (typeof body.five_hour?.utilization === "number")
		windows.push({ label: "5h", pct: Math.round(body.five_hour.utilization), resetMs: parseReset(body.five_hour.resets_at) });
	if (typeof body.seven_day?.utilization === "number")
		windows.push({ label: "week", pct: Math.round(body.seven_day.utilization), resetMs: parseReset(body.seven_day.resets_at) });
	if (!windows.length) return null;
	return { plan: null, windows, fetchedAt: Date.now() };
}

// ---------- extension ----------

export default function (pi: ExtensionAPI) {
	const caches: Record<string, Cache> = {};
	let outputTokens = 0;
	let genMs = 0;
	let messageStartedAt: number | null = null;
	let started = false;
	let timer: ReturnType<typeof setInterval> | null = null;
	let ctx: ExtensionContext | null = null;

	function provider(): "zai" | "anthropic" | null {
		const p = ctx?.model?.provider;
		return p === "zai" || p === "anthropic" ? p : null;
	}

	function themeFg(): Fg {
		const theme = (ctx?.ui as unknown as { theme?: { fg?: Fg } } | undefined)?.theme;
		return typeof theme?.fg === "function" ? (name, text) => theme.fg!(name, text) : (_name, text) => text;
	}

	function render(): void {
		const p = provider();
		if (!ctx?.hasUI || !p) return;
		const cache = caches[p];
		const tokPerSec = genMs > 0 ? Math.round(outputTokens / (genMs / 1000)) : null;
		const windows = cache?.quota?.windows ?? [];
		if (!windows.length && tokPerSec === null) {
			ctx.ui.setStatus("provider-usage", undefined);
			return;
		}
		const head = p === "zai" ? `z.ai${cache?.quota?.plan ? ` ${cache.quota.plan}` : ""}` : "claude";
		ctx.ui.setStatus("provider-usage", formatRow({ head, windows, tokPerSec, fg: themeFg() }));
	}

	function clear(): void {
		ctx?.hasUI && ctx.ui.setStatus("provider-usage", undefined);
	}

	function refresh(p: "zai" | "anthropic", force = false): void {
		const cache = caches[p];
		if (!force && cache?.quota && Date.now() - cache.quota.fetchedAt < STALE_MS) {
			render();
			return;
		}
		void (p === "zai" ? fetchZai() : fetchClaude())
			.then((quota) => {
				caches[p] = quota ? { quota } : { failedAt: Date.now() };
				render();
			})
			.catch(() => {
				caches[p] = { failedAt: Date.now() };
				render();
			});
	}

	function refreshAll(): void {
		refresh("zai");
		refresh("anthropic");
	}

	pi.on("session_start", async (_event, extensionCtx) => {
		ctx = extensionCtx;
		if (started) return;
		started = true;
		refreshAll();
		timer = setInterval(refreshAll, POLL_MS);
	});

	pi.on("session_shutdown", async () => {
		if (timer) clearInterval(timer);
		timer = null;
		started = false;
	});

	pi.on("model_select", async (event, extensionCtx) => {
		ctx = extensionCtx;
		const p = event.model?.provider;
		if (p === "zai" || p === "anthropic") refresh(p);
		else clear();
	});

	pi.on("message_start", async (event, extensionCtx) => {
		ctx = extensionCtx;
		if (event.message.role === "assistant") messageStartedAt = Date.now();
	});

	pi.on("message_end", async (event, extensionCtx) => {
		ctx = extensionCtx;
		if (event.message.role !== "assistant") return;
		const usage = (event.message as { usage?: { output?: number } }).usage;
		if (messageStartedAt !== null && usage?.output) {
			genMs += Math.max(0, Date.now() - messageStartedAt);
			outputTokens += usage.output;
		}
		messageStartedAt = null;
		render();
	});
}
