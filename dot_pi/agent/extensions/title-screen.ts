/**
 * title-screen -- the startup splash: "PI" in one random palette role,
 * captioned with the project url and the launch model + effort.
 *
 * Replaces pi's built-in startup header (logo + keybinding hints) with a
 * title screen, once per process: session_start fires with reason
 * "startup" only (every CLI launch, `pi -c` included); /new, /resume and
 * /reload leave whatever header is already up. /builtin-header restores
 * pi's own header; /title-screen brings the splash back (and draws a new
 * color).
 *
 *   ███████╗  ██╗
 *   ██╔═══██╗ ██║
 *   ██╔═══██╗ ██║
 *   ███████╔╝ ██║
 *   ██╔════╝  ██║
 *   ██║       ██║
 *   ██║       ██║
 *   ╚═╝       ╚═╝
 *   https://github.com/earendil-works/pi · glm-5.3 · high
 *
 * The block is ONE color for the whole splash, drawn per launch from
 * three theme roles -- accent (blue), mdCode (aqua), dim. Roles only,
 * never a hex, never a raw index, so the splash follows the active
 * dotfiles-{light,dark} theme and, through its indexed slots, the
 * viewing terminal's palette, even over SSH (the same guarantee the
 * rest of pi's chrome carries). Styling happens inside render() against
 * the theme pi hands the factory -- the live proxy -- so an OS
 * appearance flip re-tints the splash on the next paint, and
 * render(width) re-centers on resize.
 *
 * The caption is frozen at launch: it names the model and thinking level
 * pi started with (the footer tracks the live ones). It carries no
 * keybinding hints -- pi's compact hints live one ctrl+o away in the
 * built-in header, restorable any time with /builtin-header.
 */

import type { ExtensionAPI, Theme, ThemeColor } from "@earendil-works/pi-coding-agent";

// ---------- the logo ----------

/** ANSI Shadow "PI", one row-step larger than the stock glyph (8 rows x 13
 *  columns: the bowl and each stem gain a row, the hatches gain a column). */
const ART = [
	"███████╗  ██╗",
	"██╔═══██╗ ██║",
	"██╔═══██╗ ██║",
	"███████╔╝ ██║",
	"██╔════╝  ██║",
	"██║       ██║",
	"██║       ██║",
	"╚═╝       ╚═╝",
];

const ART_WIDTH = 13;

/** The pool the splash draws from, one color for the whole block: the
 *  three roles the old fade used. accent is blue and mdCode is aqua --
 *  both exact palette slots -- and dim is the quiet launch. */
export const COLOR_POOL = ["accent", "mdCode", "dim"] as const;

/** One role for the whole block, redrawn per launch. Takes the rng so the
 *  harness can pin it; defaults to Math.random. */
export function pickColor(rng: () => number = Math.random): ThemeColor {
	return COLOR_POOL[Math.floor(rng() * COLOR_POOL.length)]!;
}

// ---------- layout helpers (exported for scripts/test-title-screen.mjs) ----------

const ANSI_RE = /\x1b\[[0-9;]*m/g;

/** Display columns of a string that may carry SGR escapes. */
export function visibleWidth(s: string): number {
	return s.replace(ANSI_RE, "").length;
}

/** Left padding that centers `w` visible columns in a `width`-column
 *  terminal; 0 when it does not fit. */
export function centerPad(width: number, w: number): number {
	return Math.max(0, Math.floor((width - w) / 2));
}

// ---------- the header component ----------

function makeHeader(
	theme: Theme,
	color: ThemeColor,
	caption: { url: string; model?: string; effort?: string },
) {
	return {
		render(width: number): string[] {
			const lines: string[] = [""];
			// the logo: one color for every row, centered
			const pad = centerPad(width, ART_WIDTH);
			for (const row of ART) {
				// fg is a prototype method reading this.fgColors -- always
				// called on the receiver, never extracted (an unbound call
				// throws; same trap the provider-usage harness polices).
				lines.push(" ".repeat(pad) + theme.fg(color, row));
			}
			// the caption: project url + the launch model + effort; the
			// model/effort segments drop out when pi started without one
			const sep = theme.fg("muted", " · ");
			const parts = [theme.fg("dim", caption.url)];
			if (caption.model) parts.push(theme.fg("dim", caption.model));
			if (caption.effort) parts.push(theme.fg("dim", caption.effort));
			const line = parts.join(sep);
			lines.push(" ".repeat(centerPad(width, visibleWidth(line))) + line);
			return lines;
		},
		invalidate() {},
	};
}

// ---------- extension ----------

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (event, ctx) => {
		if (event.reason !== "startup" || ctx.mode !== "tui") return;
		const model = ctx.model?.id;
		const effort = ctx.thinkingLevel;
		ctx.ui.setHeader((_tui, theme) => makeHeader(theme, pickColor(), {
			url: "https://github.com/earendil-works/pi",
			model,
			effort,
		}));
	});

	pi.registerCommand("title-screen", {
		description: "Show the title-screen splash header",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") return;
			const model = ctx.model?.id;
			const effort = ctx.thinkingLevel;
			ctx.ui.setHeader((_tui, theme) => makeHeader(theme, pickColor(), {
				url: "https://github.com/earendil-works/pi",
				model,
				effort,
			}));
		},
	});

	pi.registerCommand("builtin-header", {
		description: "Restore pi's built-in startup header",
		handler: async (_args, ctx) => {
			ctx.ui.setHeader(undefined);
			ctx.ui.notify("Built-in header restored", "info");
		},
	});
}
