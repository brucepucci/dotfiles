/**
 * title-screen -- the startup splash: "PI" in the section-header color,
 * captioned with the launch model + effort.
 *
 * Replaces pi's built-in startup header (logo + keybinding hints) with a
 * title screen, once per process: session_start fires with reason
 * "startup" only (every CLI launch, `pi -c` included); /new, /resume and
 * /reload leave whatever header is already up. /builtin-header restores
 * pi's own header; /title-screen brings the splash back.
 *
 * The block is ONE color for the whole splash: the mdHeading role, the
 * same role pi renders its [Context] / [Skills] / [Extensions] startup
 * section headers with. Roles only, never a hex, never a raw index, so
 * the splash follows the active dotfiles-{light,dark} theme and, through
 * its indexed slots, the viewing terminal's palette, even over SSH (the
 * same guarantee the rest of pi's chrome carries). Styling happens
 * inside render() against the theme pi hands the factory -- the live
 * proxy -- so an OS appearance flip re-tints the splash on the next
 * paint.
 *
 * Everything sits at a two-space indent: the block glyphs are visually
 * heavy, and flush against the terminal border they look cramped -- the
 * small pad gives them air without floating center. The caption is
 * frozen at launch -- the model and thinking level pi started with
 * (the footer tracks the live ones) -- and drops out entirely when pi
 * starts without a model. No keybinding hints here; they live one
 * ctrl+o away in the built-in header, restorable any time with
 * /builtin-header.
 */

import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";

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

/** The whole splash's left indent -- enough air that the block glyphs
 *  don't sit on the terminal border. */
const PAD = 2;

/** The one color for the whole block: the role behind pi's own startup
 *  section headers ([Context], [Skills], [Extensions] -- interactive-mode
 *  sectionHeader defaults to it), so the splash reads as pi's chrome. */
const BLOCK_COLOR = "mdHeading" as const;

// ---------- the header component ----------

function makeHeader(theme: Theme, caption: { model?: string; effort?: string }) {
	return {
		render(_width: number): string[] {
			const lines: string[] = [""];
			// the logo: one color for every row, at the small left indent
			const pad = " ".repeat(PAD);
			for (const row of ART) {
				// fg is a prototype method reading this.fgColors -- always
				// called on the receiver, never extracted (an unbound call
				// throws; same trap the provider-usage harness polices).
				lines.push(pad + theme.fg(BLOCK_COLOR, row));
			}
			// the caption: the launch model + effort, dropped entirely when
			// pi started without a model
			const sep = theme.fg("muted", " · ");
			const parts: string[] = [];
			if (caption.model) parts.push(theme.fg("dim", caption.model));
			if (caption.effort) parts.push(theme.fg("dim", caption.effort));
			if (parts.length > 0) lines.push(pad + parts.join(sep));
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
		ctx.ui.setHeader((_tui, theme) => makeHeader(theme, { model, effort }));
	});

	pi.registerCommand("title-screen", {
		description: "Show the title-screen splash header",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") return;
			const model = ctx.model?.id;
			const effort = ctx.thinkingLevel;
			ctx.ui.setHeader((_tui, theme) => makeHeader(theme, { model, effort }));
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
