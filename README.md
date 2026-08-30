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

# 5. The one manual step: secrets never go in git. Create
#    ~/.zsh/secrets.zsh from the installed template and fill in your keys:
cp ~/.zsh/secrets.example.zsh ~/.zsh/secrets.zsh
chmod 600 ~/.zsh/secrets.zsh
$EDITOR ~/.zsh/secrets.zsh   # ZAI_API_KEY (https://z.ai), GITHUB_TOKEN, ...
#    pi reads ZAI_API_KEY from the environment; gh keeps working via its
#    own hosts.yml either way. (pi's /login is an alternative: it writes
#    ~/.pi/agent/auth.json, which then takes precedence over the variable.)
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
| `~/.pi/agent/settings.json` | pi coding agent: appearance-following theme pair, `zai` provider, `glm-5.3` default |
| `.chezmoidata/palette.toml` | The three settings that drive every color (repo-only — never applied) |
| `colors/` | Curated theme overrides only (repo-only); everything else resolves from Ghostty at apply time |

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
(an optional copy of the Z.ai key written by `/login` — it takes precedence
over `ZAI_API_KEY` when present), `~/.pi/agent/sessions/` (transcripts), and
`~/.pi/agent/models-store.json` (a catalog cache pi refetches from Z.ai).

## pi + Z.ai

`pi` is the terminal coding agent, running Z.ai's GLM models on their Coding
Plan. `zai` is a **built-in** pi provider, so the whole setup is three pieces:

1. the npm package — `@earendil-works/pi-coding-agent`, installed by the
   Brewfile alongside its one hard dependency, `node`;
2. `~/.pi/agent/settings.json` — chezmoi-managed; sets the dark theme and the
   `zai` / `glm-5.3` startup defaults (change them in pi with `/model` +
   Ctrl+S);
3. the API key — `ZAI_API_KEY` in `~/.zsh/secrets.zsh` (step 5 above), in
   the same place as every other key: it is a secret like the rest and
   cannot live in this repo. pi's `/login` is an alternative that writes
   `~/.pi/agent/auth.json` instead; when that file exists it takes
   precedence over the environment variable.

`settings.json` also carries `lastChangelogVersion`, which pi bumps by itself
on updates, so `chezmoi diff` will show that one field drifting after an
upgrade — harmless, like a lazy-lock drift. The file is a chezmoi template
(its `theme` pair renders from the palette, below), and `chezmoi re-add`
skips template-sourced files — so after changing model defaults via `/model`,
fold them into `dot_pi/agent/settings.json.tmpl` by hand:

```bash
chezmoi cd
$EDITOR dot_pi/agent/settings.json.tmpl   # port defaultModel etc.
chezmoi diff && chezmoi apply
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

## Testing changes

Three tiers, by cost. Tier 1 runs in about a second and should follow every
change to the shell config; tier 3 is a real macOS VM for full new-machine
runs before big changes.

```bash
# 1. Seconds, no VM. Applies the repo into a pristine throwaway HOME and
#    exercises the result the way real sessions do: fresh-window shell,
#    the legacy ZDOTDIR guard, SSH prompt segment, history shared across
#    shells, EDITOR fallback, secrets staying out, ghostty config hygiene,
#    the light/dark mode wiring (ghostty theme line, nvim mode module,
#    delta-theme wrapper exercised with fake `defaults`/`delta` shims),
#    and the color-system checks (both theme names resolve, no orphan
#    hexes, roles render verbatim).
scripts/smoke-test.sh              # --nvim also restores plugins (~2 min)

# 2. ~1 min. The same, inside a clean Debian 12 userland on the colima VM.
#    Catches "works on my mac" assumptions (GNU vs BSD ls, no Homebrew,
#    nvim absent so the EDITOR fallback branch actually runs).
scripts/test-linux-vm.sh           # --full adds Homebrew-on-Linux + brew
                                   # bundle + plugin restore (~25 min): the
                                   # "New machine" steps on Linux, verbatim

# 3. The real thing: a disposable macOS VM via tart (Virtualization
#    framework; first run downloads a ~15 GB image, clones are cheap).
brew install tart
tart clone ghcr.io/cirruslabs/macos-sequoia:latest dotfiles-test
tart run dotfiles-test             # Cirrus images ship ssh admin/admin
ssh admin@$(tart ip dotfiles-test) # then run New-machine steps 0-4 inside
tart delete dotfiles-test          # done -- throw it away
```

CI runs tier 1 on Ubuntu for every push and PR
(`.github/workflows/smoke.yml`). Tiers 1-2 cover everything chezmoi manages;
only tier 3 exercises `brew bundle`, the GUI apps, and the terminal
emulators themselves.

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

## Changing how everything looks

Three settings in [.chezmoidata/palette.toml](.chezmoidata/palette.toml) — no
hex, no per-app themes:

```toml
[palette]
theme = "system"                   # "system" | "light" | "dark"
light_theme = "Gruvbox Light Hard"
dark_theme = "Gruvbox Material Dark"
```

- **`light_theme` / `dark_theme`** are Ghostty theme names — browse with
  `ghostty +list-themes` (highlighting one there previews its 16-color
  mapping). Type the name exactly as shown, `chezmoi diff && chezmoi apply`,
  and every surface follows: Ghostty runs the theme itself; the zsh prompt
  renders in indexed colors it inherits from the terminal; pi's TUI themes
  are generated from the theme's palette; delta uses the theme's bat syntax
  theme when it has one (else `none` — the terminal's own colors, still
  cohesive); nvim and lualine use the theme's curated colorscheme when it
  names one, else a colorscheme generated from the palette.
- **`theme`** picks the mode: `system` follows the OS light/dark appearance
  live — Ghostty auto-switches its pair, nvim re-syncs on focus, delta
  detects per invocation; `light`/`dark` pin one look everywhere, always,
  regardless of what the OS says.

The data behind a name is resolved **at apply time, nothing cached**: for
each of the two names, `scripts/ghostty-theme.py` serves a curated override
from `colors/<name>.toml` when one exists — otherwise it parses the theme
straight out of Ghostty's own catalog and derives everything from its
16-color palette. That means new Ghostty themes work the moment you type
their name, there is no catalog in this repo to keep fresh, and a curated
override is the only file that pins values. Two rules:

- Want a theme to look exactly a certain way? Create `colors/<name>.toml`
  (copy a Gruvbox one, adjust `[roles]`, keep `curated = true`). The two
  Gruvbox themes ship curated this way, preserving the colors this stack
  has always rendered. A curated override needs Ghostty for nothing —
  which is also why CI (no Ghostty) and a fresh-machine bootstrap (Ghostty
  not yet installed) work with the default pair.
- A non-curated theme needs Ghostty installed on the machine you run
  `chezmoi apply` from; otherwise the resolver fails loudly and tells you
  to curate or install.

Everything rendered — the pi themes, nvim's `core/theming.lua`, the
ghostty/delta/gitconfig lines — is a build artifact; the smoke test fails
if a name stops resolving, a rendered output carries a hex the active
themes don't define, or a surface stops matching the settings.

pi specifics: its theme files are named `dotfiles-{light,dark}.json`
regardless of which themes are active (a theme swap never renames files),
and `settings.json` picks the pair — or a single theme when the mode is
pinned.

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
