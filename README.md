# dotfiles

Terminal setup, managed with [chezmoi](https://chezmoi.io).

Neovim 0.12 · lazy.nvim · native LSP (ruff + pyright) · snacks.nvim · built for
reviewing code an AI agent wrote.

## New machine

```bash
# 1. Credentials FIRST. This repo is private, so chezmoi's clone needs them.
brew install chezmoi gh
gh auth login          # choose HTTPS
gh auth setup-git      # installs the git credential helper

# 2. Config
chezmoi init --apply brucepucci

# 3. Dependencies (language servers, ripgrep, lazygit, ipython, ...)
brew bundle --file="$(chezmoi source-path)/Brewfile"

# 4. Plugins, pinned to the exact revisions in lazy-lock.json
nvim --headless "+Lazy! restore" +qa
```

> **Step 1 is not optional.** `chezmoi init` clones over HTTPS and this repo is
> private, so without a credential helper it fails with
> `Authentication failed`. There is no SSH key registered on this account, so
> `--ssh` is not a fallback either.

> **Step 3 before opening Neovim.** Servers come from Homebrew, not Mason. If
> you launch `nvim` first you get a warning naming the missing servers — it is
> not silent, but it is avoidable.

If Homebrew is not installed yet, start with
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.

**Requires Neovim 0.12+.** The config refuses to load below that and tells you
so, rather than half-working: `vim.lsp.config`, `vim.hl`, and nvim-treesitter's
`main` branch all need it.

## What is managed

| Path | What |
|---|---|
| `~/.config/nvim/` | The editor |
| `~/.gitconfig`, `~/.config/git/ignore` | Identity, delta pager, zdiff3 conflicts |
| `~/.config/lazygit/config.yml` | delta as lazygit's pager |
| `~/.config/ghostty/config` | Theme, and the `ZDOTDIR` pointing at the shell below |
| `~/.config/zsh-ghostty/` | zsh config for Ghostty sessions — `.zshrc` and `ps1.zsh` |

**Ghostty sessions use their own shell config.** The Ghostty config sets
`ZDOTDIR=~/.config/zsh-ghostty`, so `~/.zshrc` and the oh-my-zsh setup in
`$HOME` are **not** read there. That directory is the one managed here; the
`$HOME` ones are deliberately left alone.

The Ghostty config lives at the XDG path, not
`~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`. Ghostty
reads both on macOS and only the XDG one on Linux — and it **merges** them when
both exist, so there is only ever one.

Not managed, on purpose: `~/.zsh_history` and `.zcompdump*` (private and
generated), `~/.ssh/`, `~/.config/gh/hosts.yml` (auth token), and `~/.oh-my-zsh`
(92MB of third-party code).

## Linux / WSL

Homebrew is the supported install path on every OS. Debian 12 and Ubuntu 22.04
cannot supply Neovim 0.12, `lua-language-server`, `marksman`, or
`tree-sitter-cli >= 0.26.1` from their own repositories, so distro packages are
not an option.

```bash
# Homebrew on Linux (needs sudo once, plus build-essential curl file git)
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

Then follow the four steps above. The Brewfile is OS-aware: it skips the font
cask on Linux and adds `wl-clipboard` + `xclip` there instead.

**Clipboard.** macOS has `pbcopy` built in; Linux does not. Without one of the
clipboard tools, `clipboard=unnamedplus` means every yank **silently** fails to
reach the system clipboard — only `:checkhealth` reports it. The Brewfile
covers Wayland and X11.

**WSL** needs different tools than either:

```bash
# clipboard -- neither wl-clipboard nor xclip works under WSL
curl -sLo /tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip
unzip -p /tmp/win32yank.zip win32yank.exe > ~/.local/bin/win32yank.exe
chmod +x ~/.local/bin/win32yank.exe

# markdown preview needs a way to reach a Windows browser
sudo apt install wslu       # provides wslview
```

**Linux aarch64** (WSL-on-ARM, Graviton, Raspberry Pi): upstream
markdown-preview ships no prebuilt binary for this platform. The build detects
that and falls back to compiling the Node app, so `<leader>mp` still works —
but it needs `npm`, which the Brewfile installs.

## Editing the config

**Edit in the source directory, not in `~/.config/nvim`.** The target is a build
artifact; hand-editing it means the next `chezmoi apply` overwrites your work.

```bash
chezmoi cd                  # -> ~/.local/share/chezmoi
$EDITOR private_dot_config/nvim/lua/bruce/plugins/foo.lua
chezmoi diff                # review
chezmoi apply               # install
```

Adding a plugin means dropping a file into
`private_dot_config/nvim/lua/bruce/plugins/` — they are auto-imported, so no
`init.lua` edit is needed.

## Updating plugins

`lazy-lock.json` is committed on purpose: it is what makes a second machine
reproduce this one, and what makes a bad update bisectable.

```
:Lazy update
# test that things still work
chezmoi re-add ~/.config/nvim/lazy-lock.json
chezmoi cd && git commit -am "plugin update"
```

Skipping the `re-add` is not destructive — the lockfile just drifts, and
`chezmoi diff` will show it.

## Health check

Worth running quarterly. This is what would have caught the config rotting
before: the previous setup had a dead LSP for months and never said so.

```vim
:checkhealth
:Lazy check
```

## Rollback

The pre-migration config is kept at `~/.config/nvim-old` and runs side by side
without touching anything:

```bash
NVIM_APPNAME=nvim-old nvim
```

Full revert:

```bash
mv ~/.config/nvim ~/.config/nvim.new
mv ~/.config/nvim.pre-chezmoi ~/.config/nvim
mv ~/.local/share/nvim.pre-chezmoi ~/.local/share/nvim
mv ~/.local/state/nvim.pre-chezmoi ~/.local/state/nvim
```

Bad plugin update: `:Lazy restore`. Bad config change:
`chezmoi cd && git revert <sha> && chezmoi apply`.

The pre-migration history lives in the archived
[brucepucci/nvim](https://github.com/brucepucci/nvim) repo at tag
`pre-chezmoi-2026-08-27`.

## Docs

- [keymaps.md](private_dot_config/nvim/docs/keymaps.md) — cheatsheet, grouped by task
- [tools.md](private_dot_config/nvim/docs/tools.md) — what each tool is and why it is installed

Both are installed to `~/.config/nvim/docs/`. In Neovim, `<leader>?` opens the
cheatsheet and `<leader>fk` fuzzy-searches every live mapping. Press `<Space>`
and pause for which-key.
