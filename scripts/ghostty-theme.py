#!/usr/bin/env python3
"""ghostty-theme.py -- resolve a Ghostty theme into the data our templates need.

Called by the chezmoi templates themselves (via the `output` template
function) at apply time, so no theme data is ever cached in this repo:

  ghostty-theme.py <name>           # JSON: {terminal, roles, apps}
  ghostty-theme.py --get <name> <path>   # one value, e.g. roles.bg or
                                         # apps.nvim.colorscheme
  ghostty-theme.py --hexes <name>...     # every hex the theme(s) define

Resolution order for a name:
  1. colors/<name>.toml exists -- it is a CURATED OVERRIDE (hand-tuned,
     self-contained: terminal palette + roles + app hints). Used verbatim;
     Ghostty is not consulted. The two Gruvbox themes ship curated this way,
     which is what keeps the applied tree (and CI, which has no Ghostty)
     independent of a Ghostty install.
  2. Otherwise the theme is parsed from Ghostty's own catalog (the files
     behind `ghostty +list-themes`) and every derived value -- roles, app
     fallbacks -- is computed from its 16-color palette. New Ghostty themes
     work with zero repo changes; nothing here can go stale.

Roles derived from the 16 colors map the terminal palette onto what our
apps need: surfaces (bg/surface/statusline), text (fg/fg_soft/fg_bright),
greys, accents (red..purple + a blended orange), diff tints, and lualine's
mode-segment colors. See colors/Gruvbox*.toml for the shape.

Exits nonzero with a pointed message for unknown names (apply fails loudly)
or when a non-curated theme is requested on a machine without Ghostty.

No third-party imports; python3 stdlib only.
"""

import glob
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLORS_DIR = os.path.join(REPO, "colors")

GHOSTTY_THEME_DIRS = [
    "/Applications/Ghostty.app/Contents/Resources/ghostty/themes",  # macOS cask
    "/opt/homebrew/Caskroom/ghostty/*/ghostty/themes",              # homebrew alt
    os.path.expanduser("~/.local/share/ghostty/themes"),            # linux, user
    "/usr/share/ghostty/themes",                                    # linux, system
]

# Keys of a Ghostty theme file we keep, in output order.
TERMINAL_KEYS = [
    "background",
    "foreground",
    "cursor-color",
    "cursor-text",
    "selection-background",
    "selection-foreground",
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
    """a towards b by t in 0..1 (0.25 = a quarter of the way to b)."""
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
# source 1: ghostty's own theme file
# ---------------------------------------------------------------------------

def find_ghostty_dir():
    # explicit override first (also how tests simulate a machine without
    # Ghostty, e.g. CI)
    env = os.environ.get("DOTFILES_GHOSTTY_THEMES")
    if env:
        return env if os.path.isdir(env) else None
    for pattern in GHOSTTY_THEME_DIRS:
        for cand in sorted(glob.glob(pattern), reverse=True):
            if os.path.isdir(cand):
                return cand
    return None


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
            if key in TERMINAL_KEYS:
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

    return {
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


# ---------------------------------------------------------------------------
# source 2: our curated override (colors/<name>.toml)
# ---------------------------------------------------------------------------

def parse_palette_file(path):
    """Parse the controlled subset we write: flat `key = "value"` lines under
    [section] headers; comments with #."""
    data = {}
    section = None
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
            if section is None or "=" not in line:
                continue
            key, _, value = line.partition("=")
            data[section][key.strip()] = value.strip().strip('"')
    return data


def resolve(name):
    """-> {terminal, roles, apps}, or exits nonzero with a pointed message."""
    override = os.path.join(COLORS_DIR, name + ".toml")
    if os.path.exists(override):
        data = parse_palette_file(override)
        term = data.get("terminal", {})
        roles = data.get("roles", {})
        apps = data.get("apps", {})
        nvim = data.get("apps.nvim", {})
        if not term or not roles:
            die("%s exists but lacks [terminal]/[roles] -- fix or remove it"
                % os.path.relpath(override, REPO))
        # normalize: every key the templates touch is always present
        for i in range(16):
            term.setdefault("palette_%d" % i, term["background"])
        for key in TERMINAL_KEYS:
            term.setdefault(key, term["background"])
    else:
        ghostty_dir = find_ghostty_dir()
        if not ghostty_dir:
            die("theme '%s' has no curated override in colors/ and Ghostty's "
                "theme catalog was not found (is Ghostty installed?)" % name)
        path = os.path.join(ghostty_dir, name)
        if not os.path.isfile(path):
            die("theme '%s' is neither curated in colors/ nor in Ghostty's "
                "catalog (browse names with `ghostty +list-themes`)" % name)
        term = parse_ghostty_theme(path)
        if term is None:
            die("Ghostty's '%s' theme file has no background/foreground" % name)
        roles = derive_roles(term)
        apps, nvim = {}, {}

    return {
        "terminal": {key: term[key] for key in TERMINAL_KEYS}
        | {"palette_%d" % i: term["palette_%d" % i] for i in range(16)},
        "roles": {key: roles[key] for key in ROLE_ORDER},
        "apps": {
            "delta_syntax_theme": apps.get("delta_syntax_theme", "none"),
            "nvim": {
                "colorscheme": nvim.get("colorscheme", ""),
                "contrast": nvim.get("contrast", ""),
                "foreground": nvim.get("foreground", ""),
            },
        },
    }


def die(msg):
    print("ghostty-theme: %s" % msg, file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# cli
# ---------------------------------------------------------------------------

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__.split("\n", 2)[2], file=sys.stderr)
        sys.exit(2)

    if args[0] == "--hexes":
        if len(args) < 2:
            die("--hexes needs at least one theme name")
        hexes = set()
        for name in args[1:]:
            data = resolve(name)
            hexes.update(data["terminal"].values())
            hexes.update(data["roles"].values())
        for h in sorted(hexes):
            print(h)
        return

    if args[0] == "--get":
        if len(args) != 3:
            die("usage: --get <theme> <path>   (e.g. roles.bg, apps.nvim.colorscheme)")
        data = resolve(args[1])
        node = data
        for part in args[2].split("."):
            if not isinstance(node, dict) or part not in node:
                die("no such path '%s' for theme '%s'" % (args[2], args[1]))
            node = node[part]
        print(node)
        return

    if len(args) != 1:
        die("expected exactly one theme name (quote names with spaces)")
    print(json.dumps(resolve(args[0]), sort_keys=True))


if __name__ == "__main__":
    main()
