# The color system — one look everywhere

The appearance of everything this repo manages — terminal, shell prompt,
editor, statusline, diffs, and the pi coding agent's TUI — is derived from
**two theme names**. There are no per-app theme files to keep in
sync, no hex codes hardcoded anywhere in managed files, and no palette
fetches at apply time: the themes are bytes in this repo. What the mirror
holds is what every surface renders.

This is the part of the repo with the most machinery behind it, so this
page is the reference. If you only want to change how things look, read
the next section and stop.

## The settings (settings.toml, at the repo root)

Four settings, no hex, no per-app themes:

```toml
theme = "system"              # "system" | "light" | "dark"
light_theme = "Flexoki Light" # theme names — browse the gallery in
                              # iTerm2-Color-Schemes' README; the names
                              # are the file names of the mirror in themes/
dark_theme = "Kanagawa Wave"
tmux_wrap = "on"              # "on" | "off" — pi in detachable tmux sessions?
```

- **`light_theme` / `dark_theme`** are theme names, typed exactly as the
  mirror's file names in `themes/`. Any mirrored theme works; the mirror
  is rooted in [mbadolato/iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)
  (browse its README gallery — screenshots for every scheme) and refreshed
  by `scripts/themes-sync.sh`.
- **`theme`** picks the mode: `system` follows the OS light/dark appearance
  live (Ghostty auto-switches its pair, nvim re-syncs on focus, delta
  detects per invocation); `light`/`dark` pin one look everywhere.
- **`tmux_wrap`** is a behavior knob, not a color one — documented in
  [tmux.md](tmux.md) and [pi.md](pi.md).

To change anything: edit `settings.toml`, then `chezmoi diff && chezmoi
apply`. Every surface follows.

## How it resolves (the committed mirror)

At `chezmoi apply` time, the templates call
[`scripts/theme.py`](../scripts/theme.py) through chezmoi's
`output` function. The script parses each theme straight out of **the
committed mirror in [`themes/`](../themes)** — a verbatim copy of the
`ghostty/` directory of mbadolato/iTerm2-Color-Schemes — and derives
everything from the theme's 16-color palette:

- the raw terminal palette, slots 0–15, kept verbatim;
- **semantic roles** — surfaces (`bg`, `bg_deep`, `surface`), text (`fg`,
  `fg_soft`, `fg_bright`), four greys, accents (red, orange, yellow, green,
  aqua, blue, purple), diff tints, and lualine's mode-segment colors —
  mapped from those same slots;
- the pi TUI's variables and nvim's generated palette module.

Because the mirror ships inside the repo, resolution needs no network
and no Ghostty install — the colors are local bytes, versioned and
bisectable (`git log -p themes/` shows exactly when any palette changed).
`themes/SOURCE.md` records the upstream commit the mirror was taken from;
`scripts/themes-sync.sh` refreshes it by hand when you want newer upstream
themes. Staleness is benign: an out-of-date mirror just means the newest
upstream names do not resolve yet — the resolver fails loudly with the
fix in the message. A hand-written file dropped into `themes/` under a
name overrides the mirrored one, if a palette ever needs pinning.

The script is stdlib-only Python with a query interface
(`appearance`, `--setting <k>`, `--pi <name>`, `--hexes <name>...`, ...).
`DOTFILES_THEMES` and `DOTFILES_SETTINGS_FILE` let tests point it
elsewhere — that's how the smoke test renders off-variants without
touching the repo's settings.

## What each surface renders

| Surface | How it follows the theme |
|---|---|
| **Ghostty** | Two GENERATED user themes, `~/.config/ghostty/themes/dotfiles-{light,dark}` — the config's theme line runs the pair (`light:`/`dark:`, auto-switched by the OS) |
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
2. **One committed mirror**: theme data lives in `themes/` and nowhere
   else; the smoke test fails if a settings.toml name stops resolving
   against it.
3. **No orphan hexes**: the smoke test checks that rendered outputs carry
   only hexes the active themes actually define.
4. **Roles render verbatim**: nvim's generated module must carry the
   resolver's role values byte-for-byte.
5. **SSH-facing surfaces ride the indexed slots** — also smoke-tested.

These are enforced by `scripts/smoke-test.sh` (the color-system step), so
drift is a test failure, not a slow aesthetic decay. CI runs the same
check on every push — with no Ghostty installed, which is itself part of
the guarantee.

## Which files are generated

Everything rendered is a build artifact; edit `settings.toml`, never these:

- `private_dot_config/nvim/lua/bruce/core/theming.lua.tmpl` → nvim's
  `core/theming.lua` (nvim's *only* rendered file)
- `dot_pi/agent/themes/dotfiles-{light,dark}.json.tmpl` → pi's theme pair
  (stable file names regardless of which themes are active — a theme swap
  never renames anything)
- `dot_pi/agent/settings.json.tmpl` → pi's `settings.json`. Only the
  `theme` field is generated (from the mode); the provider/model fields
  are static and *are* edited here — this is the fold-in target for pi's
  self-bumps (see [developing.md](developing.md))
- `dot_local/bin/executable_delta-theme.tmpl` → the delta wrapper
- `dot_gitconfig.tmpl` → the delta fallback lines
- `private_dot_config/ghostty/config.tmpl` → Ghostty's theme line (naming
  the generated user themes)
- `private_dot_config/ghostty/themes/dotfiles-{light,dark}.tmpl` → the
  two generated user theme files Ghostty runs (rendered unconditionally,
  whatever the mode)
- `dot_zshrc.tmpl` → two conditional renders (tmux_wrap default, pinned
  theme)
