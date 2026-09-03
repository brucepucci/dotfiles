/**
 * provider-usage -- a footer status row for plan quotas + generation speed.
 *
 * Renders (via ctx.ui.setStatus) one line below pi's built-in footer stats,
 * showing only the provider that owns the active model. Segments join on a
 * dim middle dot -- pi's footer collapses runs of spaces, so whitespace is
 * not a separator:
 *
 *   z.ai pro · 5h 3% (resets 14:32) · week 28% (resets Sat 09:07) · 37 tok/s
 *   claude · 5h 0% (resets 18:10) · week 2% (resets Fri 02:00) · 55 tok/s
 *
 * - tok/s: output tokens per second, session average -- generated tokens /
 *   generation time, anchored at the first streamed token (excludes
 *   time-to-first-token), accumulated from pi's message events.
 * - z.ai quota: GET api.z.ai/api/monitor/usage/quota/limit (the endpoint the
 *   z.ai console uses); the key comes from ctx.modelRegistry.getProviderAuth,
 *   which resolves auth.json and $ZAI_API_KEY just like pi's own requests.
 * - Claude quota: GET api.anthropic.com/api/oauth/usage with the OAuth token
 *   getProviderAuth resolves (refreshed when expired) after /login into
 *   Claude Pro/Max. API-key auth has no plan quota and is skipped.
 *
 * The active provider's quota polls every 60s and on model switches; the
 * last known-good quota survives failed polls and ages out after 10 minutes.
 * Fetches are aborted on session teardown and failures never block pi.
 */

import type { ExtensionAPI, ExtensionContext, ThemeColor } from "@earendil-works/pi-coding-agent";

// ---------- types ----------

type QuotaWindow = { label: string; pct: number; resetMs: number | null };
type Quota = { plan: string | null; windows: QuotaWindow[]; fetchedAt: number };
type Fg = (name: ThemeColor, text: string) => string;

const POLL_MS = 60_000;
const STALE_MS = 30_000;
const MAX_AGE_MS = 10 * POLL_MS;
const FETCH_TIMEOUT_MS = 8_000;
const DAY_MS = 24 * 60 * 60 * 1000;
/** Resets further out than this are treated as bogus (weekly is <= 7d). */
const RESET_MAX_AHEAD_MS = 30 * DAY_MS;

// ---------- pure helpers (exported for scripts/test-provider-usage.mjs) ----------

/** Clock time for a pending reset: "14:32" within 24h, "Sat 14:32" beyond.
 *  Returns null for an elapsed reset so callers can drop the clause. */
export function formatReset(resetMs: number, now: number = Date.now()): string | null {
	if (resetMs <= now) return null;
	const d = new Date(resetMs);
	const time = d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false });
	if (resetMs - now < DAY_MS) return time;
	return `${d.toLocaleDateString("en-US", { weekday: "short" })} ${time}`;
}

/** z.ai limits[] entry -> window; unit 3 = hours, 6 = weeks (observed).
 *  nextResetTime is accepted in ms or s; nonsense values become null. */
export function zaiWindow(
	entry: { unit?: number; number?: number; percentage?: number; nextResetTime?: number },
	now: number = Date.now(),
): QuotaWindow | null {
	if (typeof entry.percentage !== "number") return null;
	const label =
		entry.unit === 3 && (entry.number ?? 0) > 0
			? `${entry.number}h`
			: entry.unit === 6 && entry.number === 1
				? "week"
				: entry.unit === 6 && (entry.number ?? 0) > 1
					? `${entry.number}w`
					: "quota";
	let resetMs: number | null = null;
	if (typeof entry.nextResetTime === "number" && entry.nextResetTime > 0) {
		const ms = entry.nextResetTime < 1e12 ? entry.nextResetTime * 1000 : entry.nextResetTime;
		if (ms - now <= RESET_MAX_AHEAD_MS) resetMs = ms;
	}
	return { label, pct: Math.round(entry.percentage), resetMs };
}

/** Sort shorter windows first; unknown labels sink. */
export function sortWindows(windows: QuotaWindow[]): QuotaWindow[] {
	const weight = (label: string) => {
		const h = /^(\d+)h$/.exec(label);
		if (h) return Number(h[1]);
		const w = /^(\d+)w$/.exec(label);
		if (w) return 168 * Number(w[1]);
		return label === "week" ? 168 : 1e6;
	};
	return [...windows].sort((a, b) => weight(a.label) - weight(b.label));
}

/** "z.ai pro · 5h 3% (resets 14:32) · week 28% (resets Sat 09:07) · 37 tok/s"
 *  -- single-character separators, because pi's footer collapses space runs. */
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
		const at = w.resetMs !== null ? formatReset(w.resetMs, opts.now) : null;
		const reset = at ? fg("dim", ` (resets ${at})`) : "";
		parts.push(`${fg("dim", w.label)} ${pct}${reset}`);
	}
	if (opts.tokPerSec !== null) parts.push(fg("dim", `${opts.tokPerSec} tok/s`));
	return parts.join(fg("dim", " · "));
}

// ---------- fetchers ----------

async function fetchJson(url: string, headers: Record<string, string>, signal: AbortSignal): Promise<unknown> {
	const res = await fetch(url, { headers, signal });
	if (!res.ok) throw new Error(`HTTP ${res.status}`);
	return res.json();
}

async function fetchZai(apiKey: string, signal: AbortSignal): Promise<Quota | null> {
	const body = (await fetchJson(
		"https://api.z.ai/api/monitor/usage/quota/limit",
		{ Authorization: apiKey },
		signal,
	)) as { data?: { level?: string; limits?: Array<Parameters<typeof zaiWindow>[0]> } };
	const windows = sortWindows((body.data?.limits ?? []).map((e) => zaiWindow(e)).filter((w): w is QuotaWindow => w !== null));
	if (!windows.length) return null;
	return { plan: body.data?.level ?? null, windows, fetchedAt: Date.now() };
}

function parseReset(iso: string | null | undefined): number | null {
	if (!iso) return null;
	const t = Date.parse(iso);
	return Number.isNaN(t) ? null : t;
}

async function fetchClaude(apiKey: string, signal: AbortSignal): Promise<Quota | null> {
	const body = (await fetchJson(
		"https://api.anthropic.com/api/oauth/usage",
		{
			Authorization: `Bearer ${apiKey}`,
			"anthropic-beta": "oauth-2025-04-20",
			Accept: "application/json",
		},
		signal,
	)) as {
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

// ---------- provider table (the single place a provider is spelled out) ----------

const PROVIDERS: Record<
	string,
	{ head: string; oauthOnly?: boolean; fetch: (apiKey: string, signal: AbortSignal) => Promise<Quota | null> }
> = {
	zai: { head: "z.ai", fetch: fetchZai },
	// The OAuth usage endpoint rejects plain API keys; only Claude Pro/Max
	// logins (AuthResult.source === "OAuth") have plan quota to show.
	anthropic: { head: "claude", oauthOnly: true, fetch: fetchClaude },
};

// ---------- extension ----------

export default function (pi: ExtensionAPI) {
	const caches: Record<string, Quota | undefined> = {};
	const aborts = new Set<AbortController>();
	let outputTokens = 0;
	let genMs = 0;
	let messageStartedAt: number | null = null;
	let awaitingFirstToken = false;
	let started = false;
	let live = false;
	let renderFailureNotified = false;
	let timer: ReturnType<typeof setInterval> | null = null;
	let ctx: ExtensionContext | null = null;

	function provider(): string | null {
		const p = ctx?.model?.provider;
		return p && p in PROVIDERS ? p : null;
	}

	function render(): void {
		// `live` gates stale contexts: after session_shutdown the extension
		// context is disposed and every property getter throws. In-flight
		// fetches settle afterwards, so render() must not touch `ctx` then.
		//
		// The try/catch keeps a rendering bug from taking the session down:
		// render() runs from promise chains where a throw would escape as an
		// unhandled rejection and crash pi. The user is told once (loudly)
		// instead; the row is retried on every poll.
		try {
			if (!live || !ctx?.hasUI) return;
			const p = provider();
			if (!p) return;
			const quota = caches[p];
			const windows = quota && Date.now() - quota.fetchedAt < MAX_AGE_MS ? quota.windows : [];
			const tokPerSec = genMs > 0 ? Math.round(outputTokens / (genMs / 1000)) : null;
			if (!windows.length && tokPerSec === null) {
				ctx.ui.setStatus("provider-usage", undefined);
				return;
			}
			const spec = PROVIDERS[p]!;
			const head = quota?.plan ? `${spec.head} ${quota.plan}` : spec.head;
			const theme = ctx.ui.theme;
			// fg is a prototype method that reads `this.fgColors` -- it must be
			// called on the receiver, never extracted (passes unbound => throws).
			ctx.ui.setStatus("provider-usage", formatRow({ head, windows, tokPerSec, fg: (n, t) => theme.fg(n, t) }));
		} catch (error) {
			if (!renderFailureNotified && live && ctx?.hasUI) {
				renderFailureNotified = true;
				try {
					ctx.ui.notify(`provider-usage: ${error instanceof Error ? error.message : "render failed"}`, "warning");
				} catch {
					// the row is cosmetic; never crash the session over it
				}
			}
		}
	}

	function clear(): void {
		if (live && ctx?.hasUI) ctx.ui.setStatus("provider-usage", undefined);
	}

	function refresh(p: string): void {
		const cached = caches[p];
		if (cached && Date.now() - cached.fetchedAt < STALE_MS) {
			render();
			return;
		}
		const ac = new AbortController();
		aborts.add(ac);
		const signal = AbortSignal.any([ac.signal, AbortSignal.timeout(FETCH_TIMEOUT_MS)]);
		void (async () => {
			if (!live || !ctx) return null;
			// Resolves the stored/env credential like pi's own requests do,
			// refreshing OAuth tokens when expired. undefined -> not configured.
			const auth = await ctx.modelRegistry.getProviderAuth(p).catch(() => undefined);
			// Anthropic: only OAuth logins carry plan quota; an API key would
			// 401 forever against the usage endpoint.
			if (PROVIDERS[p]!.oauthOnly && auth?.source !== "OAuth") return null;
			const apiKey = auth?.auth.apiKey;
			if (!apiKey) return null;
			return PROVIDERS[p]!.fetch(apiKey, signal);
		})()
			.then((quota) => {
				// A failed or empty poll keeps the last known-good quota.
				if (quota) caches[p] = quota;
			})
			.catch(() => {})
			// render() here -- success or failure -- and never from a rejection
			// handler, so a throw cannot chase its own tail through .catch.
			.finally(() => {
				aborts.delete(ac);
				render();
			});
	}

	function refreshActive(): void {
		const p = provider();
		if (p) refresh(p);
	}

	pi.on("session_start", async (_event, extensionCtx) => {
		ctx = extensionCtx;
		// No UI -> nothing can ever be displayed (print/json modes); skip the
		// polls entirely so one-shot runs send no credentials and exit promptly.
		if (started || !ctx.hasUI) return;
		started = true;
		live = true;
		refreshActive();
		timer = setInterval(refreshActive, POLL_MS);
	});

	pi.on("session_shutdown", async () => {
		live = false;
		started = false;
		ctx = null;
		if (timer) clearInterval(timer);
		timer = null;
		for (const ac of aborts) ac.abort();
		aborts.clear();
	});

	pi.on("model_select", async (event, extensionCtx) => {
		ctx = extensionCtx;
		const p = provider();
		if (p) refresh(p);
		else clear();
	});

	pi.on("message_start", async (event, extensionCtx) => {
		ctx = extensionCtx;
		awaitingFirstToken = event.message.role === "assistant";
		if (!awaitingFirstToken) messageStartedAt = null;
	});

	pi.on("message_update", async (event, extensionCtx) => {
		ctx = extensionCtx;
		// Anchor the generation window at the first streamed token so TTFT
		// and prompt processing stay out of the tok/s average.
		if (awaitingFirstToken) {
			awaitingFirstToken = false;
			messageStartedAt = Date.now();
		}
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
		awaitingFirstToken = false;
		render();
	});
}
