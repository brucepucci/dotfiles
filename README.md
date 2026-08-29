# dotfiles

Terminal setup, managed with [chezmoi](https://chezmoi.io).

Neovim 0.12 · lazy.nvim · native LSP (ruff + pyright) · snacks.nvim · pi +
GLM via Z.ai · built for reviewing code an AI agent wrote.

## New machine

Six commands on macOS. Order matters — see the notes.

```bash
# 0. Homebrew, if this machine has never had it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 1. Credentials. This repo is PRIVATE, so chezmoi's clone needs them.
brew install chezmoi gh
gh auth login            # choose HTTPS
gh auth setup-git        # installs the git credential helper

# 2. Config -> ~/.config/nvim, ~/.zshrc, ~/.zprofile, ~/.config/ghostty
chezmoi init --apply brucepucci

# 3. Everything the config needs: Neovim, language servers, ripgrep, fd,
#    lazygit, delta, ipython, tree-sitter, the Nerd Font, Ghostty itself,
#    and the pi coding agent (installed from npm)
brew bundle --file="$(chezmoi source-path)/Brewfile"

# 4. Plugins, at the exact revisions pinned in lazy-lock.json
nvim --headless "+Lazy! restore" +qa

# 5. The one manual step: secrets never go in git.
#    pi's Z.ai key -- get one from https://z.ai, then:
pi                        # /login -> zai -> paste the key
#    (or: export ZAI_API_KEY=... before launching pi)
#
#    Shell secrets (GitHub token, API keys), if you use them:
#    cp ~/.zsh/secrets.example.zsh ~/.zsh/secrets.zsh   # then fill it in, chmod 600
```

Then open Ghostty and run `nvim` — or `pi`, once step 5 is done. That is the
whole thing: nothing is left to configure or install by hand — editor,
terminal, shell, git tooling, and coding agent are all in place. From here on,
every change is an edit in this repo plus `chezmoi apply`.

> **Step 1 is not optional.** `chezmoi init` clones over HTTPS, and this repo
> is private, so without a credential helper it fails with
> `Authentication failed`. No SSH key is registered on this account either, so
> `--ssh` is not a fallback.

> **Do step 3 before step 4.** Language servers come from Homebrew, not Mason.
> Launching Neovim earlier is not fatal — it warns and names what is missing —
> but `Lazy! restore` also needs `tree-sitter` to build parsers.

> **Not using Ghostty?** The Nerd Font is installed by step 3, but only Ghostty
> picks it up automatically. In Terminal.app or iTerm2, set the font to
> JetBrainsMono Nerd Font by hand or icons — and the prompt's git branch mark —
> render as boxes. The shell itself needs nothing: every terminal reads the
> same `~/.zshrc`.

**Requires Neovim 0.12+.** Below that the config refuses to load and says so,
rather than half-working: `vim.lsp.config`, `vim.hl`, and nvim-treesitter's
`main` branch all need it. Homebrew's `neovim` is current, so this only bites
if you install Neovim some other way.

## What is managed

| Path | What |
|---|---|
| `~/.zshrc`, `~/.zprofile` | The shell — every terminal and every SSH session |
| `~/.config/zsh/ps1.zsh` | The prompt: git state, duration, exit code |
| `~/.config/nvim/` | The editor |
| `~/.gitconfig`, `~/.config/git/ignore` | Identity, delta pager, zdiff3 conflicts |
| `~/.config/lazygit/config.yml` | delta as lazygit's pager |
| `~/.config/ghostty/config` | Ghostty's theme — nothing shell-related |
| `~/.pi/agent/settings.json` | pi coding agent: dark theme, `zai` provider, `glm-5.3` default |

**One shell everywhere.** Ghostty, Terminal.app, iTerm2, and anyone SSH-ing
into this machine all get the same zsh: `~/.zprofile` sets the login PATH,
`~/.zshrc` carries options, aliases, completion and keybindings, and
`~/.config/zsh/ps1.zsh` renders the prompt. History is a single shared file
(`~/.zsh_history` with `SHARE_HISTORY`), so a command typed in one terminal is
immediately searchable from another. oh-my-zsh and powerlevel10k are gone —
the Ghostty setup they were replaced by is now the default everywhere, and the
Ghostty config itself sets nothing shell-related.

Secrets — GitHub token, API keys — belong in `~/.zsh/secrets.zsh`, which
`~/.zshrc` sources when present. That file is deliberately unmanaged (see
below): secrets never go in git.

The Ghostty config lives at the XDG path, not
`~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`. Ghostty
reads both on macOS and only the XDG one on Linux — and it **merges** them when
both exist, so there is only ever one.

Not managed, on purpose: `~/.zsh_history` and `.zcompdump*` (private and
generated), `~/.zsh/secrets.zsh` (API keys and tokens — a secret), `~/.ssh/`,
and `~/.config/gh/hosts.yml` (auth token). For pi: `~/.pi/agent/auth.json`
(the Z.ai API key — a secret), `~/.pi/agent/sessions/` (transcripts), and
`~/.pi/agent/models-store.json` (a catalog cache pi refetches from Z.ai).

## pi + Z.ai

`pi` is the terminal coding agent, running Z.ai's GLM models on their Coding
Plan. `zai` is a **built-in** pi provider, so the whole setup is three pieces:

1. the npm package — `@earendil-works/pi-coding-agent`, installed by the
   Brewfile alongside its one hard dependency, `node`;
2. `~/.pi/agent/settings.json` — chezmoi-managed; sets the dark theme and the
   `zai` / `glm-5.3` startup defaults (change them in pi with `/model` +
   Ctrl+S);
3. the API key — stored by `/login` in `~/.pi/agent/auth.json` (step 5 above),
   since it is a secret and cannot live in this repo.

`settings.json` also carries `lastChangelogVersion`, which pi bumps by itself
on updates, so `chezmoi diff` will show that one field drifting after an
upgrade — harmless, like a lazy-lock drift. If you change model defaults via
`/model`, fold them back in:

```bash
chezmoi re-add ~/.pi/agent/settings.json
```

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
