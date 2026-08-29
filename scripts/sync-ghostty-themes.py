#!/usr/bin/env python3
"""sync-ghostty-themes.py -- Ghostty's theme catalog -> this repo's palette files.

Every theme browsable with `ghostty +list-themes` ships as a file in
Ghostty's resources (16-color palette + background/foreground/cursor).
This script imports them into `colors/<theme name>.toml`, one file per
theme, deriving the semantic [roles] (bg, surface, fg, greys, accents,
tints, statusline colors...) that the chezmoi templates need but Ghostty
does not name. It then regenerates `.chezmoidata/colors.toml`, the
aggregate the templates read as `.colors."Theme Name"`.

Editing model:
  * [terminal] is Ghostty's data, verbatim. Re-running the script refreshes
    it (say, after a Ghostty upgrade changed a theme).
  * [roles] starts machine-derived from the 16 colors. Tweak any theme by
    hand; add `curated = true` under [meta] and the script will never
    overwrite your roles again ([apps] hints are always preserved too).
  * Themes that vanish from Ghostty are reported, never deleted.

Usage:
  sync-ghostty-themes.py            # import + regenerate aggregate
  sync-ghostty-themes.py --check    # aggregate freshness only (no Ghostty
                                    # needed; used by scripts/smoke-test.sh)
  sync-ghostty-themes.py --ghostty-dir /path/to/themes   # override source

No third-party imports: the TOML this reads/writes is a controlled subset
(hand-parsed), and python3.6+ is everywhere this repo runs.
"""

import argparse
import glob
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLORS_DIR = os.path.join(REPO, "colors")
AGGREGATE = os.path.join(REPO, ".chezmoidata", "colors.toml")

GHOSTTY_THEME_DIRS = [
    "/Applications/Ghostty.app/Contents/Resources/ghostty/themes",  # macOS cask
    "/opt/homebrew/Caskroom/ghostty/*/ghostty/themes",              # homebrew alt
    os.path.expanduser("~/.local/share/ghostty/themes"),            # linux, user
    "/usr/share/ghostty/themes",                                    # linux, system
]

# Keys of a Ghostty theme file we keep, and the defaults when absent
# (upstream files occasionally omit cursor/selection entries).
TERMINAL_KEYS = [
    ("background", None),
    ("foreground", None),
    ("cursor-color", None),
    ("cursor-text", None),
    ("selection-background", None),
    ("selection-foreground", None),
]

ROLE_ORDER = [
    "bg", "bg_deep", "surface", "fg", "fg_soft", "fg_bright",
    "grey", "grey_dim", "grey_neutral", "grey_soft",
    "red", "orange", "yellow", "green", "aqua", "blue", "purple",
    "tint_green", "tint_red",
    "statusline", "statusline_accent", "statusline_fg", "on_accent",
    "mode_red", "mode_green", "mode_yellow", "mode_blue", "mode_purple",
]


# ---------------------------------------------------------------------------
# color math
# ---------------------------------------------------------------------------

def parse_hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hex_str(rgb):
    return "#%02x%02x%02x" % rgb


def blend(a, b, t):
    """a towards b by t in 0..1 (0.25 = quarter of the way to b)."""
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def luminance(rgb):
    def chan(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (chan(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


# ---------------------------------------------------------------------------
# Ghostty theme file parsing / role derivation
# ---------------------------------------------------------------------------

def parse_ghostty_theme(path):
    term = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            # ghostty palette lines are `palette = N=#hex` -- the number and
            # the color both sit on the value side of the first `=`
            m = re.fullmatch(r"palette\s*=\s*(\d+)\s*=\s*(\S+)", line)
            if m:
                term["palette_%s" % m.group(1)] = m.group(2)
                continue
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip()
            if key in dict(TERMINAL_KEYS):
                term[key] = value
    if "background" not in term or "foreground" not in term:
        return None  # not a usable theme (some catalog entries are stubs)
    term.setdefault("cursor-color", term["foreground"])
    term.setdefault("cursor-text", term["background"])
    term.setdefault("selection-background", term["foreground"])
    term.setdefault("selection-foreground", term["background"])
    for i in range(16):
        term.setdefault("palette_%d" % i, term["background"])
    return term


def derive_roles(term):
    p = {i: parse_hex(term["palette_%d" % i]) for i in range(16)}
    bg, fg = parse_hex(term["background"]), parse_hex(term["foreground"])
    dark = luminance(fg) > luminance(bg)
    edge = (0, 0, 0) if dark else (255, 255, 255)  # "deeper" recess direction

    accent_avg = blend(p[1], blend(p[3], p[4], 0.5), 0.5)
    on_accent = bg if contrast(bg, accent_avg) >= contrast(fg, accent_avg) else fg

    roles = {
        "bg": term["background"],
        "bg_deep": hex_str(blend(bg, edge, 0.25)),
        "surface": hex_str(blend(bg, fg, 0.12)),
        "fg": term["foreground"],
        "fg_soft": hex_str(blend(fg, bg, 0.30)),
        "fg_bright": term["palette_15"] if dark else hex_str(blend(fg, (0, 0, 0), 0.35)),
        "grey": hex_str(blend(fg, bg, 0.45)),
        "grey_dim": hex_str(blend(fg, bg, 0.65)),
        "grey_neutral": hex_str(blend(fg, bg, 0.35)),
        "grey_soft": hex_str(blend(fg, bg, 0.55)),
        "red": term["palette_1"],
        "orange": hex_str(blend(p[1], p[3], 0.5)),
        "yellow": term["palette_3"],
        "green": term["palette_2"],
        "aqua": term["palette_6"],
        "blue": term["palette_4"],
        "purple": term["palette_5"],
        "tint_green": hex_str(blend(bg, p[2], 0.18)),
        "tint_red": hex_str(blend(bg, p[1], 0.18)),
        "statusline": hex_str(blend(bg, fg, 0.08)),
        "statusline_accent": hex_str(blend(bg, fg, 0.18)),
        "statusline_fg": term["foreground"],
        "on_accent": hex_str(on_accent),
        "mode_red": term["palette_1"],
        "mode_green": term["palette_2"],
        "mode_yellow": term["palette_3"],
        "mode_blue": term["palette_4"],
        "mode_purple": term["palette_5"],
    }
    return roles


# ---------------------------------------------------------------------------
# our colors/<name>.toml subset: sections, flat "key = value" lines
# ---------------------------------------------------------------------------

def parse_palette_file(path):
    data = {"meta": {}, "terminal": {}, "roles": {}, "apps": {}, "apps.nvim": {}}
    section = "meta"
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            m = re.fullmatch(r"\[([^\]]+)\]", line)
            if m:
                section = m.group(1)
                data.setdefault(section, {})
                continue
            key, _, value = line.partition("=")
            value = value.strip().strip('"')
            data[section][key.strip()] = value
    return data


def toml_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def write_palette_file(path, name, term, roles, apps, nvim, curated, updated):
    lines = [
        "# %s" % name,
        "# [terminal] is synced verbatim from Ghostty (ghostty +list-themes).",
        "# [roles] map the 16 colors onto what our apps need; %s" % (
            "CURATED -- hand-tuned, never overwritten by the sync script."
            if curated else
            "derived from them by scripts/sync-ghostty-themes.py -- edit freely."
        ),
        "# [apps] carries optional per-app hints (delta syntax theme, nvim",
        "# colorscheme); templates fall back to derived/neutral values without them.",
        "",
    ]
    if updated:
        lines.append("# updated from Ghostty: %s" % updated)
        lines.append("")
    lines.append("[meta]")
    lines.append("curated = %s" % ("true" if curated else "false"))
    lines.append("")
    lines.append("[terminal]")
    for key, _ in TERMINAL_KEYS:
        lines.append("%s = %s" % (key, toml_str(term[key])))
    for i in range(16):
        lines.append("palette_%d = %s" % (i, toml_str(term["palette_%d" % i])))
    lines.append("")
    lines.append("[roles]")
    for role in ROLE_ORDER:
        lines.append("%s = %s" % (role, toml_str(roles[role])))
    lines.append("")
    lines.append("[apps]")
    lines.append('delta_syntax_theme = %s' % toml_str(apps["delta_syntax_theme"]))
    lines.append("")
    lines.append("[apps.nvim]")
    lines.append("colorscheme = %s" % toml_str(nvim["colorscheme"]))
    if nvim.get("contrast"):
        lines.append("contrast = %s" % toml_str(nvim["contrast"]))
    if nvim.get("foreground"):
        lines.append("foreground = %s" % toml_str(nvim["foreground"]))
    lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def write_aggregate(all_themes):
    lines = [
        "# colors.toml -- GENERATED aggregate of colors/*.toml. Do not edit:",
        "# edit colors/<theme>.toml (or run scripts/sync-ghostty-themes.py to",
        "# import/refresh from Ghostty), then regenerate. Served to templates",
        "# as .colors.\"<ghostty theme name>\".",
        "",
    ]
    for name in sorted(all_themes):
        t = all_themes[name]
        q = toml_str(name)
        lines.append("[colors.%s]" % q)
        for key, _ in TERMINAL_KEYS:
            lines.append("%s = %s" % (key, toml_str(t["terminal"][key])))
        for i in range(16):
            lines.append("palette_%d = %s" % (i, toml_str(t["terminal"]["palette_%d" % i])))
        lines.append("")
        lines.append("[colors.%s.roles]" % q)
        for role in ROLE_ORDER:
            lines.append("%s = %s" % (role, toml_str(t["roles"][role])))
        lines.append("")
        lines.append("[colors.%s.apps]" % q)
        lines.append('delta_syntax_theme = %s' % toml_str(t["apps"]["delta_syntax_theme"]))
        lines.append("")
        lines.append("[colors.%s.apps.nvim]" % q)
        lines.append("colorscheme = %s" % toml_str(t["nvim"]["colorscheme"]))
        if t["nvim"].get("contrast"):
            lines.append("contrast = %s" % toml_str(t["nvim"]["contrast"]))
        if t["nvim"].get("foreground"):
            lines.append("foreground = %s" % toml_str(t["nvim"]["foreground"]))
        lines.append("")
    with open(AGGREGATE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


# ---------------------------------------------------------------------------
# actions
# ---------------------------------------------------------------------------

def find_ghostty_dir(explicit):
    if explicit:
        return explicit if os.path.isdir(explicit) else None
    for pattern in GHOSTTY_THEME_DIRS:
        for cand in sorted(glob.glob(pattern), reverse=True):
            if os.path.isdir(cand):
                return cand
    return None


def sync(ghostty_dir):
    if not ghostty_dir:
        print("error: no Ghostty themes directory found (install Ghostty, or",
              "pass --ghostty-dir)", file=sys.stderr)
        return 1
    os.makedirs(COLORS_DIR, exist_ok=True)
    imported = kept = 0
    for path in sorted(os.listdir(ghostty_dir)):
        full = os.path.join(ghostty_dir, path)
        if not os.path.isfile(full):
            continue
        term = parse_ghostty_theme(full)
        if term is None:
            continue
        name = path
        dest = os.path.join(COLORS_DIR, name + ".toml")
        if os.path.exists(dest):
            old = parse_palette_file(dest)
            roles = old["roles"] if old["meta"].get("curated") == "true" else derive_roles(term)
            apps = old["apps"]
            nvim = old["apps.nvim"]
            curated = old["meta"].get("curated") == "true"
            write_palette_file(dest, name, term, roles, apps, nvim, curated, None)
            kept += 1
        else:
            apps = {"delta_syntax_theme": "none"}
            nvim = {"colorscheme": ""}
            write_palette_file(dest, name, term, derive_roles(term), apps, nvim, False, None)
            imported += 1
    aggregate()
    print("synced %d new theme(s), refreshed %d; aggregate regenerated" % (imported, kept))
    return 0


def aggregate():
    all_themes = {}
    for path in sorted(glob.glob(os.path.join(COLORS_DIR, "*.toml"))):
        data = parse_palette_file(path)
        if "background" not in data["terminal"]:
            print("error: %s has no [terminal] section; not a palette file?" % path,
                  file=sys.stderr)
            return 1
        all_themes[os.path.basename(path)[:-5]] = {
            "terminal": data["terminal"],
            "roles": data["roles"],
            "apps": {"delta_syntax_theme": data["apps"].get("delta_syntax_theme", "none")},
            "nvim": data["apps.nvim"],
        }
    write_aggregate(all_themes)
    return 0


def check():
    """Aggregate must match colors/ exactly (no Ghostty needed)."""
    before = open(AGGREGATE, encoding="utf-8").read() if os.path.exists(AGGREGATE) else ""
    if aggregate() != 0:
        return 1
    after = open(AGGREGATE, encoding="utf-8").read()
    if before != after:
        open(AGGREGATE, "w", encoding="utf-8").write(before)  # restore
        print("error: .chezmoidata/colors.toml is stale vs colors/ --",
              "run scripts/sync-ghostty-themes.py", file=sys.stderr)
        return 1
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true",
                    help="verify the aggregate matches colors/ (no Ghostty needed)")
    ap.add_argument("--ghostty-dir", help="path to Ghostty's themes directory")
    args = ap.parse_args()
    if args.check:
        sys.exit(check())
    sys.exit(sync(find_ghostty_dir(args.ghostty_dir)))


if __name__ == "__main__":
    main()
