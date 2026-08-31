# The color system — one look everywhere

The appearance of everything this repo manages — terminal, shell prompt,
editor, statusline, diffs, and the pi coding agent's TUI — is derived from
**two Ghostty theme names**. There are no per-app theme files to keep in
sync, no hex codes hardcoded anywhere in managed files, and no cached
palette data that can go stale. What Ghostty ships is what every surface
renders.

This is the part of the repo with the most machinery behind it, so this
page is the reference. If you only want to change how things look, read
the next section and stop.

## The settings (settings.toml, at the repo root)

Four settings, no hex, no per-app themes:

```toml
theme = "system"              # "system" | "light" | "dark"
light_theme = "Flexoki Light" # Ghostty theme names — browse with
dark_theme = "Kanagawa Wave"  # `ghostty +list-themes`
tmux_wrap = "on"              # "on" | "off" — pi in detachable tmux sessions?
```

- **`light_theme` / `dark_theme`** are Ghostty theme names, typed exactly
  as `ghostty +list-themes` shows them. Any theme in Ghostty's catalog
  works — including ones added by a future Ghostty update — because
  nothing is pinned here.
- **`theme`** picks the mode: `system` follows the OS light/dark appearance
  live (Ghostty auto-switches its pair, nvim re-syncs on focus, delta
  detects per invocation); `light`/`dark` pin one look everywhere.
- **`tmux_wrap`** is a behavior knob, not a color one — documented in
  [tmux.md](tmux.md) and [pi.md](pi.md).

To change anything: edit `settings.toml`, then `chezmoi diff && chezmoi
apply`. Every surface follows.

## How it resolves (nothing cached)

At `chezmoi apply` time, the templates call
[`scripts/ghostty-theme.py`](../scripts/ghostty-theme.py) through chezmoi's
`output` function. The script parses each theme straight out of Ghostty's
own catalog (the files behind `ghostty +list-themes`) and derives
everything from the theme's 16-color palette:

- the raw terminal palette, slots 0–15, kept verbatim;
- **semantic roles** — surfaces (`bg`, `bg_deep`, `surface`), text (`fg`,
  `fg_soft`, `fg_bright`), four greys, accents (red, orange, yellow, green,
  aqua, blue, purple), diff tints, and lualine's mode-segment colors —
  mapped from those same slots;
- the pi TUI's variables and nvim's generated palette module.

Because resolution happens at apply time from Ghostty itself, the only
thing that can pin a color value is Ghostty — there is no catalog in this
repo to keep fresh. Ghostty must therefore be installed wherever
`chezmoi apply` runs; without it the resolver fails loudly.

The script is stdlib-only Python with a query interface
(`appearance`, `--setting <k>`, `--pi <name>`, `--hexes <name>...`, ...).
`DOTFILES_GHOSTTY_THEMES` and `DOTFILES_SETTINGS_FILE` let tests point it
elsewhere — that's how the smoke test renders off-variants without
touching the repo's settings.

## What each surface renders

| Surface | How it follows the theme |
|---|---|
| **Ghostty** | Runs the theme itself (`light:`/`dark:` pair, auto-switched by the OS) |
| **zsh prompt** | Indexed colors 0–15 — the *viewing* terminal resolves them through its own palette |
| **nvim + lualine** | A colorscheme **generated** from the theme's roles at apply time (`core/theming.lua` is nvim's only rendered file; everything else is static Lua reading it) |
| **delta** | `syntax-theme = none` — bat syntax colors off, so diffs render in the theme's own ANSI palette; the `delta-theme` wrapper picks light/dark per invocation |
| **pi's TUI** | Theme files whose vars ride terminal-indexed colors, so pi follows the *viewing* terminal — even over SSH |

## The SSH rule: indexed colors, not hexes

Surfaces that travel over SSH — the prompt, pi's TUI — avoid hexes
entirely. A hex describes a color on the *rendering* machine; an indexed
slot (0–15) is resolved by the *viewing* terminal through whatever palette
it is running. SSH from a light-mode laptop into this Mac and the prompt
and pi render light, automatically, because the terminal in your hands
decides — the Mac never ships a palette across the wire.

The deliberate exceptions in pi's themes:

- **Shades with no honest slot** (surface, dim grey) ride the fixed xterm
  color cube (16–255), which every terminal renders identically by spec.
- **The two tool tints** (`tint_green` / `tint_red`) stay live-derived
  hexes: the cube has no muted olive/rust, and nearest-mapping them
  collapses the success/error cue into two greys.
- **Sparse custom themes**: if a theme's author never set a palette slot
  that would otherwise be ridden, that role's hex is emitted instead of
  the index (the viewing terminal's own color there would silently diverge
  from nvim/lualine's rendering of the same theme).

## The mode: system vs pinned

- `theme = "system"` (default): everything follows the OS live. Ghostty
  switches itself; nvim re-syncs on `FocusGained` (needs tmux's
  `focus-events` when inside tmux); delta probes `defaults read -g
  AppleInterfaceStyle` per invocation; the pi wrapper asks the terminal
  before creating the session (pi's own detection can't see through the
  tmux layer — see [pi.md](pi.md)).
- `theme = "light"` / `"dark"`: the pin renders a single theme into
  Ghostty's config, a single theme into pi's `settings.json`, nvim's
  module carries the pinned mode, and the pi wrapper skips its probe
  entirely (injecting `--use-theme` would override the pin).

## The rules (what keeps this from rotting)

1. **Never hardcode a hex or theme name in a managed file** — render it
   from the resolver or read it via the generated module.
2. **Nothing cached**: no theme data lives in the repo; the smoke test
   fails if a theme name stops resolving.
3. **No orphan hexes**: the smoke test checks that rendered outputs carry
   only hexes the active themes actually define.
4. **Roles render verbatim**: nvim's generated module must carry the
   resolver's role values byte-for-byte.
5. **SSH-facing surfaces ride the indexed slots** — also smoke-tested.

These are enforced by `scripts/smoke-test.sh` (the color-system step), so
drift is a test failure, not a slow aesthetic decay. CI runs the same
check on every push against a real Ghostty install.

## Which files are generated

Everything rendered is a build artifact; edit `settings.toml`, never these:

- `private_dot_config/nvim/lua/bruce/core/theming.lua.tmpl` → nvim's
  `core/theming.lua` (nvim's *only* rendered file)
- `dot_pi/agent/themes/dotfiles-{light,dark}.json.tmpl` → pi's theme pair
  (stable file names regardless of which themes are active — a theme swap
  never renames anything)
- `dot_local/bin/executable_delta-theme.tmpl` → the delta wrapper
- `dot_gitconfig.tmpl` → the delta fallback lines
- `private_dot_config/ghostty/config.tmpl` → Ghostty's theme line
- `dot_zshrc.tmpl` → two conditional renders (tmux_wrap default, pinned
  theme)
