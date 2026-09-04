/**
 * title-screen -- the startup splash: "PI" in one random palette role,
 * captioned with the launch model + effort.
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
 *   glm-5.3 · high
 *
 * The block is ONE color for the whole splash, drawn per launch from
 * three theme roles -- accent (blue), mdCode (aqua), dim. Roles only,
 * never a hex, never a raw index, so the splash follows the active
 * dotfiles-{light,dark} theme and, through its indexed slots, the
 * viewing terminal's palette, even over SSH (the same guarantee the
 * rest of pi's chrome carries). Styling happens inside render() against
 * the theme pi hands the factory -- the live proxy -- so an OS
 * appearance flip re-tints the splash on the next paint.
 *
 * Everything sits flush left: pi's chrome is left-aligned, so the
 * splash lines up with it instead of floating center. The caption is
 * frozen at launch -- the model and thinking level pi started with
 * (the footer tracks the live ones) -- and drops out entirely when pi
 * starts without a model. No keybinding hints here; they live one
 * ctrl+o away in the built-in header, restorable any time with
 * /builtin-header.
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

/** The pool the splash draws from, one color for the whole block: the
 *  three roles the first cut faded through. accent is blue and mdCode is
 *  aqua -- both exact palette slots -- and dim is the quiet launch. */
export const COLOR_POOL = ["accent", "mdCode", "dim"] as const;

/** One role for the whole block, redrawn per launch. Takes the rng so the
 *  harness can pin it; defaults to Math.random. */
export function pickColor(rng: () => number = Math.random): ThemeColor {
	return COLOR_POOL[Math.floor(rng() * COLOR_POOL.length)]!;
}

// ---------- the header component ----------

function makeHeader(theme: Theme, color: ThemeColor, caption: { model?: string; effort?: string }) {
	return {
		render(_width: number): string[] {
			const lines: string[] = [""];
			// the logo: one color for every row, flush left
			for (const row of ART) {
				// fg is a prototype method reading this.fgColors -- always
				// called on the receiver, never extracted (an unbound call
				// throws; same trap the provider-usage harness polices).
				lines.push(theme.fg(color, row));
			}
			// the caption: the launch model + effort, dropped entirely when
			// pi started without a model
			const sep = theme.fg("muted", " · ");
			const parts: string[] = [];
			if (caption.model) parts.push(theme.fg("dim", caption.model));
			if (caption.effort) parts.push(theme.fg("dim", caption.effort));
			if (parts.length > 0) lines.push(parts.join(sep));
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
		ctx.ui.setHeader((_tui, theme) => makeHeader(theme, pickColor(), { model, effort }));
	});

	pi.registerCommand("title-screen", {
		description: "Show the title-screen splash header",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") return;
			const model = ctx.model?.id;
			const effort = ctx.thinkingLevel;
			ctx.ui.setHeader((_tui, theme) => makeHeader(theme, pickColor(), { model, effort }));
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
