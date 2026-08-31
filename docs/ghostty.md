# Ghostty — the terminal

Ghostty is the terminal emulator this machine standardizes on. The repo
manages exactly one thing for it: **appearance**. The Ghostty config
deliberately sets nothing shell-related — no `ZDOTDIR`, no shell env lines,
no command — because the shell is global by design (see [zsh.md](zsh.md)).
If you ever want to change shell behavior, there is exactly one obvious
place to look, and it is not here.

**Managed file**: `private_dot_config/ghostty/config.tmpl` →
`~/.config/ghostty/config`.

## What's in the config

Almost nothing, on purpose:

- **The theme line** — the only setting, rendered at `chezmoi apply` time
  from `settings.toml`. `theme = "system"` (the default) renders the
  `light:<name>,dark:<name>` pair, which Ghostty auto-switches with the OS
  appearance live — flip the Mac to dark and every Ghostty window follows
  without a restart. A pinned mode (`theme = "light"` or `"dark"`) renders
  the single theme. Everything else in the stack follows the same signal
  (see [theming.md](theming.md)).
- Everything else — font, window chrome, keybindings — is Ghostty defaults.

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

## Ghostty is a prerequisite for `chezmoi apply`

The palette resolver (`scripts/ghostty-theme.py`) reads Ghostty's bundled
theme catalog — the files behind `ghostty +list-themes` — to derive every
surface's colors at apply time. Nothing is cached in this repo, which
means Ghostty must be installed wherever apply runs. This is why the
new-machine steps install the Brewfile **before** applying, and why CI
installs the cask on every runner. Browse themes with:

```bash
ghostty +list-themes      # highlighting a theme previews its 16-color mapping
```

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
