/**
 * title-screen -- the startup splash: a big gradient "PI" over pi's digits.
 *
 * Replaces pi's built-in startup header (logo + keybinding hints) with a
 * title screen, once per process: session_start fires with reason
 * "startup" only (every CLI launch, `pi -c` included); /new, /resume and
 * /reload leave whatever header is already up. /builtin-header restores
 * pi's own header; /title-screen brings the splash back.
 *
 *   ███████╗  ██╗      <- accent (blue)
 *   ██╔═══██╗ ██║      <- accent
 *   ██╔═══██╗ ██║      <- accent
 *   ███████╔╝ ██║      <- mdCode (aqua)
 *   ██╔════╝  ██║      <- mdCode
 *   ██║       ██║      <- mdCode
 *   ██║       ██║      <- dim
 *   ╚═╝       ╚═╝      <- dim
 *   3.14159 26535 ...  <- muted, truncated to the terminal
 *   esc interrupt · ctrl+c/ctrl+d clear/exit · / commands · ! bash · more · vN
 *
 * Colors ride THEME ROLES ONLY -- never a hex, never a raw index -- so the
 * splash follows the active dotfiles-{light,dark} theme and, through its
 * indexed slots, the viewing terminal's palette, even over SSH (the same
 * guarantee the rest of pi's chrome carries). The logo fades blue -> aqua
 * -> dim so it stays legible on both sides of the appearance switch: on
 * light themes the base dissolves into the paper, on dark ones into the
 * void. Styling happens inside render() against the theme pi hands the
 * factory -- the live proxy -- so an OS appearance flip re-tints the
 * splash on the next paint, and render(width) re-centers on resize.
 *
 * The hint line mirrors pi's built-in compact header (interrupt /
 * clear/exit / commands / bash / more) with keys resolved through pi's
 * own keyText, so a custom keybindings.json is honored, plus the version.
 */

import type { ExtensionAPI, Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
import { VERSION, keyText } from "@earendil-works/pi-coding-agent";

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

/** One role per art row, top to bottom: the fade. accent is blue and
 *  mdCode is aqua -- both exact palette slots -- and dim grounds the base. */
const FADE: ThemeColor[] = [
	"accent",
	"accent",
	"accent",
	"mdCode",
	"mdCode",
	"mdCode",
	"dim",
	"dim",
];

// ---------- pi's digits ----------

/** 100 decimal places of pi -- decoration, truncated to the terminal. */
const DIGITS =
	"14159265358979323846264338327950288419716939937510" +
	"58209749445923078164062862089986280348253421170679";

/** "3." plus whole 5-digit groups: the longest line that fits `budget`
 *  columns. null when not even one group fits ("3." + 5 = 7). */
export function piDigits(budget: number): string | null {
	if (budget < 7) return null;
	let line = "3.";
	for (let i = 0; i + 5 <= DIGITS.length; i += 5) {
		const sep = line.length > 2 ? " " : "";
		if (line.length + sep.length + 5 > budget) break;
		line += sep + DIGITS.slice(i, i + 5);
	}
	return line;
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

function makeHeader(theme: Theme) {
	return {
		render(width: number): string[] {
			const lines: string[] = [""];
			// logo, centered, one fade step per row
			const pad = centerPad(width, ART_WIDTH);
			for (let i = 0; i < ART.length; i++) {
				// fg is a prototype method reading this.fgColors -- always
				// called on the receiver, never extracted (an unbound call
				// throws; same trap the provider-usage harness polices).
				lines.push(" ".repeat(pad) + theme.fg(FADE[i]!, ART[i]!));
			}
			// the digits: capped well below the art's visual weight, muted
			// (slot 8) so they stay legible on both light and dark themes
			const digits = piDigits(Math.min(width, 100));
			if (digits !== null) {
				lines.push(" ".repeat(centerPad(width, digits.length)) + theme.fg("muted", digits));
			}
			// the built-in compact header's five hints + the version
			const sep = theme.fg("muted", " · ");
			const hint = (key: string, desc: string) => theme.fg("dim", key) + theme.fg("muted", ` ${desc}`);
			const hints = [
				hint(keyText("app.interrupt"), "interrupt"),
				hint(`${keyText("app.clear")}/${keyText("app.exit")}`, "clear/exit"),
				hint("/", "commands"),
				hint("!", "bash"),
				hint(keyText("app.tools.expand"), "more"),
				theme.fg("dim", `v${VERSION}`),
			].join(sep);
			lines.push(" ".repeat(centerPad(width, visibleWidth(hints))) + hints);
			return lines;
		},
		invalidate() {},
	};
}

// ---------- extension ----------

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (event, ctx) => {
		if (event.reason !== "startup" || ctx.mode !== "tui") return;
		ctx.ui.setHeader((_tui, theme) => makeHeader(theme));
	});

	pi.registerCommand("title-screen", {
		description: "Show the title-screen splash header",
		handler: async (_args, ctx) => {
			if (ctx.mode === "tui") ctx.ui.setHeader((_tui, theme) => makeHeader(theme));
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
