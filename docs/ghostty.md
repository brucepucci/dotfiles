# Ghostty — the terminal

Ghostty is the terminal emulator this machine standardizes on. The repo
manages exactly one thing for it: **appearance**. The Ghostty config
deliberately sets nothing shell-related — no `ZDOTDIR`, no shell env lines,
no command — because the shell is global by design (see [zsh.md](zsh.md)).
If you ever want to change shell behavior, there is exactly one obvious
place to look, and it is not here.

**Managed files**: `private_dot_config/ghostty/config.tmpl` →
`~/.config/ghostty/config`, plus
`private_dot_config/ghostty/themes/dotfiles-{light,dark}.tmpl` → the two
generated theme files in `~/.config/ghostty/themes/`.

## What's in the config

Almost nothing, on purpose:

- **The theme line** — the only setting, rendered at `chezmoi apply` time
  from `settings.toml`. It names the two generated user themes,
  `dotfiles-light` and `dotfiles-dark`, which chezmoi renders into
  `~/.config/ghostty/themes/` from the same vendored palettes every other
  surface uses (see [theming.md](theming.md)). `theme = "system"` (the
  default) writes the `light:dotfiles-light,dark:dotfiles-dark` pair,
  which Ghostty auto-switches with the OS appearance live — flip the Mac
  to dark and every Ghostty window follows without a restart. A pinned
  mode (`theme = "light"` or `"dark"`) renders the single name. The
  terminal therefore shows exactly the palette nvim, lualine, and pi
  derived from the same theme files — and no Ghostty install is needed
  to *apply* the config: the palettes come from this repo's mirror.
- Everything else — font, window chrome, keybindings — is Ghostty defaults.
- Browsing themes happens upstream, not in the terminal: the gallery in
  [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)'
  README shows every scheme the mirror can hold.

## Why the XDG path

The config lives at `~/.config/ghostty/config`, not
`~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`.
macOS Ghostty reads both and **merges** them when both exist, so keeping
only the XDG one means there is only ever one source of truth. If you ever
see a stray setting that isn't in the managed file, check for a leftover
file in Application Support.

## The font

Ghostty's default face is JetBrains Mono **Nerd Font** — the icon glyphs
the prompt, pickers, and statusline render (branch marks, file icons,
diagnostic signs) come from it. The Brewfile installs the font cask
(`font-jetbrains-mono-nerd-font`) so it's available for the *other*
terminals too — but Terminal.app and iTerm2 do not pick it up
automatically. If you use one of those, set the font by hand or icons
render as placeholder boxes. The shell itself needs nothing.

## The theme mirror (why apply needs no Ghostty)

The colors Ghostty renders are generated *by this repo*: the resolver
(`scripts/theme.py`) derives every surface's palettes from the committed
mirror in `themes/` (rooted in iTerm2-Color-Schemes) at apply time —
including the `dotfiles-{light,dark}` theme files Ghostty loads from its
config themes directory. Ghostty the app is the terminal, never a
prerequisite: a machine without it can still `chezmoi apply` (which is
exactly what CI does), and the Brewfile ordering no longer matters for
the colors.

## Keybindings worth knowing

These are Ghostty **defaults**, not customizations — listed because the
whole workflow leans on them (splits are how pi and nvim sit side by
side):

| Key | Action |
|---|---|
| `⌘D` | Split right |
| `⌘⇧D` | Split down |
| `⌘[` / `⌘]` | Move between splits |
| `⌘T` | New tab |
| `⌘N` | New window |
| `⌘W` | Close split/tab |
| `⌘+` / `⌘-` | Font size |

Also relevant: Ghostty sends ctrl-modified Enters in the `modifyOtherKeys`
CSI form, which is what the zsh autosuggestion shortcuts (Ctrl-Enter /
Ctrl-Option-Enter) are built on — see [zsh.md](zsh.md#keybindings).

## Division of labor with tmux

Local window management — windows, splits, tabs — stays Ghostty's job.
tmux exists only to make sessions **detachable** (reattach from a phone
over SSH). Ghostty and tmux never fight over the same responsibility; see
[tmux.md](tmux.md).
