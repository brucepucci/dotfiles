/**
 * title-screen -- the startup splash: "PI" in the section-header color,
 * captioned with the model + effort in effect when it installs.
 *
 * Replaces pi's built-in startup header (logo + keybinding hints) with a
 * title screen. session_start fires on every launch AND on /new,
 * /resume, /fork and /reload -- pi resets extension-managed UI (the
 * header with it) before each rebind -- so the splash re-installs on
 * every reason; skipping any would strand the stock header for the rest
 * of the process. /builtin-header restores pi's own header;
 * /title-screen brings the splash back.
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
 * small pad gives them air without floating center. pi's own header
 * spacers provide the surrounding blank rows, so the component adds
 * none; below the glyph's width it falls back to a compact one-liner
 * rather than a wrapped, mangled block.
 *
 * The caption is snapshotted at install time -- the model id and, for
 * reasoning models only, the thinking level then in effect (pi's footer
 * keeps tracking the live values; it spells a reasoning model's off as
 * "thinking off", the caption as plain "off"). pi's agent state
 * initializes the level to "off" and never undefined, so the effort
 * segment is gated on the model, not the level: no model -- no
 * resolvable auth or catalogue -- means no caption at all. No
 * keybinding hints here either: unlike the built-in header, the splash
 * is not expandable, so ctrl+o has nothing to reveal -- /builtin-header
 * brings the hints back.
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";

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
		render(width: number): string[] {
			const pad = " ".repeat(PAD);
			// narrower than the glyph: a compact one-liner instead of a
			// wrapped, mangled block
			if (width < PAD + ART_WIDTH) return [pad + theme.fg(BLOCK_COLOR, "pi")];
			const lines: string[] = [];
			// the logo: one color for every row, at the small left indent
			for (const row of ART) {
				// fg is a prototype method reading this.fgColors -- always
				// called on the receiver, never extracted (an unbound call
				// throws; same trap the provider-usage harness polices).
				lines.push(pad + theme.fg(BLOCK_COLOR, row));
			}
			// the caption: model always when there is one; effort only for
			// reasoning models (pi's footer draws the same line)
			if (caption.model) {
				const parts: string[] = [theme.fg("dim", caption.model)];
				if (caption.effort) parts.push(theme.fg("dim", caption.effort));
				lines.push(pad + parts.join(theme.fg("muted", " · ")));
			}
			return lines;
		},
		invalidate() {},
	};
}

// ---------- extension ----------

export default function (pi: ExtensionAPI) {
	// pi resets extension-managed UI -- the header with it -- before every
	// session (re)bind: fresh launches, session replacement (/new, /resume,
	// /fork) and /reload alike. The splash must therefore install on EVERY
	// session_start; filtering by reason would strand the stock header
	// after the first switch.
	const install = (ctx: ExtensionContext) => {
		if (ctx.mode !== "tui") return; // setHeader is a no-op outside the tui
		// snapshot at install time: the model id and, for reasoning models
		// only, the thinking level then in effect (pi's footer keeps
		// tracking the live ones)
		const model = ctx.model?.id;
		const effort = ctx.model?.reasoning ? ctx.thinkingLevel : undefined;
		ctx.ui.setHeader((_tui, theme) => makeHeader(theme, { model, effort }));
	};

	pi.on("session_start", async (_event, ctx) => install(ctx));

	pi.registerCommand("title-screen", {
		description: "Show the title-screen splash header",
		handler: async (_args, ctx) => install(ctx),
	});

	pi.registerCommand("builtin-header", {
		description: "Restore pi's built-in startup header",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") return; // keep the no-op from lying via notify
			ctx.ui.setHeader(undefined);
			ctx.ui.notify("Built-in header restored", "info");
		},
	});
}
