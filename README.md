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

# 2. Clone the repo (do NOT apply yet -- the color system reads Ghostty's
#    own theme catalog at apply time, so Ghostty must land first)
chezmoi init brucepucci

# 3. Everything the config needs: Neovim, language servers, ripgrep, fd,
#    lazygit, delta, tmux, ipython, tree-sitter, the Nerd Font, Ghostty
#    itself, and the pi coding agent (installed from npm)
brew bundle --file="$(chezmoi source-path)/Brewfile"

# 4. Config -> ~/.config/nvim, ~/.zshrc, ~/.zprofile, ~/.config/ghostty
chezmoi apply

# 5. Plugins, at the exact revisions pinned in lazy-lock.json
nvim --headless "+Lazy! restore" +qa

# 6. The one manual step: secrets never go in git. Create
#    ~/.zsh/secrets.zsh from the installed template and fill in your keys:
cp ~/.zsh/secrets.example.zsh ~/.zsh/secrets.zsh
chmod 600 ~/.zsh/secrets.zsh
$EDITOR ~/.zsh/secrets.zsh   # ZAI_API_KEY (https://z.ai), GITHUB_TOKEN, ...
#    pi reads ZAI_API_KEY from the environment; gh keeps working via its
#    own hosts.yml either way. (pi's /login is an alternative: it writes
#    ~/.pi/agent/auth.json, which then takes precedence over the variable.)
```

Then open Ghostty and run `nvim` — or `pi`, once step 6 is done. That is the
whole thing: nothing is left to configure or install by hand — editor,
terminal, shell, git tooling, and coding agent are all in place. From here on,
every change is an edit in this repo plus `chezmoi apply`.

> **Step 1 is not optional.** `chezmoi init` clones over HTTPS, and this repo
> is private, so without a credential helper it fails with
> `Authentication failed`. No SSH key is registered on this account either, so
> `--ssh` is not a fallback.

> **Do step 3 before step 4.** Ghostty must be installed before
> `chezmoi apply` — the palette resolver reads Ghostty's bundled theme
> files (the catalog behind `ghostty +list-themes`) to derive every
> surface's colors, and apply fails loudly without it. Language servers
> come from Homebrew too, not Mason: launching Neovim earlier is not fatal
> — it warns and names what is missing — but `Lazy! restore` also needs
> `tree-sitter` to build parsers.

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
| `~/.tmux.conf` | tmux, kept minimal: pi's extended-keys, OSC 52 clipboard, truecolor passthrough — detachable sessions only |
| `~/.pi/agent/settings.json` | pi coding agent: appearance-following theme pair, `zai` provider, `glm-5.3` default |
| `theme.toml` | The three settings that drive every color — visible at the repo root (never applied; themes resolve from Ghostty at apply time) |

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

`pi` itself is wrapped by `~/.zshrc`: every new conversation gets its own
tmux session so it survives disconnects and rejoins from any device — see
"Picking up from another device".

## Picking up from another device

**pi handles tmux itself.** Every `pi` started in a project directory runs
inside its own tmux session — typing `pi` is the whole interface, and it
always starts a **new** conversation, never a stray attach:

```bash
cd code/chezmoi
pi                   # new tmux session "chezmoi" (hint printed), pi inside
# ... work; leave by closing the terminal or Ctrl-b d — the session lives on
tmux a -t chezmoi    # rejoin from ANY terminal: desk, laptop, phone over SSH
```

Naming: the project directory's basename, numbered siblings on collision
(`chezmoi`, `chezmoi-2`, …), or a topic — `pi -n "auth refactor"` names the
session `auth-refactor` *and* pi's own session display name. A session dies
when pi exits, so `tmux ls` lists exactly the live conversations — nothing
dangles. pi runs unwrapped already inside a tmux session (a manual session
keeps its own bare pi), from `$HOME`, for one-shot runs (`pi -p`, `--help`,
management subcommands), or with `PI_TMUX_WRAP=never` — and the wrapper is
guarded like everything else: no tmux installed means plain pi.

For anything that isn't pi — nvim, a dev server, plain shells — start it
under tmux by hand:

```bash
tmux new -s work     # manual session (same survival properties)
# ... work: shells, nvim ...
tmux attach -t work  # reattach, from any terminal, local or over SSH
```

Getting in from elsewhere:

- **Enable SSH**: System Settings → General → Sharing → Remote Login.
- **Phone clients**: Blink Shell (mosh-aware — the best option over cellular)
  or Termius on iOS; Termius or Termux on Android.
- **Away from home**: put the machines on
  [Tailscale](https://tailscale.com) and SSH over it. Never expose port 22
  to the internet.
- **Flaky cellular**: `mosh` survives phone sleep and IP changes where SSH
  drops; pair it with tmux (mosh deliberately has no scrollback — tmux
  provides it). Not in the Brewfile; install server-side if you want it.

Two things to know:

- With two clients attached, the **most recent** one sets the size for
  everyone (`window-size latest`, the default on tmux 3.7). Detach the
  desktop side when you leave (`Ctrl-b d`), or reattach with
  `tmux attach -d` to take over from a lingering connection. The view
  itself mirrors to every attached client, live.
- Forgot to start under tmux? pi conversations still carry over: every one
  is saved under `~/.pi/agent/sessions/`, so from the phone
  `cd <project> && pi -c` resumes the latest (`pi -r` to pick from a list,
  `/export` for a read-only HTML dump) — in a new wrapped session. That
  restores the conversation, not live state — an in-flight tool run or open
  splits don't come along.

The managed `~/.tmux.conf` is deliberately minimal: pi's documented
`extended-keys` settings (without them `Shift+Enter` collapses to plain
Enter under tmux), OSC 52 clipboard (yanks reach the connecting device),
and truecolor passthrough (nvim's generated colorscheme keeps its exact
colors). No prefix remap, no plugins — local window management stays
Ghostty's job, and tmux shells are just more zsh reading the same
`~/.zshrc`: one shell everywhere, history shared, prompt following whatever
palette the connecting terminal runs.

Quick reference — the full walkthrough (mental model, phone-client setup,
troubleshooting) is in
[tmux.md](private_dot_config/nvim/docs/tmux.md):

| Action | Keys / command |
|---|---|
| New pi conversation (auto-wrapped, named) | `pi` (in the project dir) |
| Named topic conversation | `pi -n "auth refactor"` |
| Detach | `Ctrl-b` `d` |
| Rejoin — lands straight inside the running pi | `tmux a -t <name>` |
| Scroll / copy mode | `Ctrl-b` `[` (exit: `q`) |
| List live conversations | `tmux ls` |
| Take over from another client | `tmux attach -d -t <name>` |
| Retire a session for good | `tmux kill-session -t <name>` |

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
#    the color-system checks (both theme names resolve, no orphan
#    hexes, roles render verbatim), the tmux config's shape
#    (extended keys, clipboard, truecolor — no tmux binary needed),
#    and the pi->tmux wrapper (creates named sessions, never
#    attaches; guards fall through to plain pi).
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

Three settings in [theme.toml](theme.toml), right at the repo root — no
hex, no per-app themes:

```toml
theme = "system"                   # "system" | "light" | "dark"
light_theme = "Gruvbox Light Hard"
dark_theme = "Gruvbox Material Dark"
```

- **`light_theme` / `dark_theme`** are Ghostty theme names — browse with
  `ghostty +list-themes` (highlighting one there previews its 16-color
  mapping). Type the name exactly as shown, `chezmoi diff && chezmoi apply`,
  and every surface follows: Ghostty runs the theme itself; the zsh prompt
  renders in indexed colors it inherits from the terminal; pi's TUI themes
  are generated from the theme's palette; delta disables bat syntax colors
  so diffs render in the theme's own ANSI palette; nvim and lualine use a
  colorscheme generated from the theme's own palette.
- **`theme`** picks the mode: `system` follows the OS light/dark appearance
  live — Ghostty auto-switches its pair, nvim re-syncs on focus, delta
  detects per invocation; `light`/`dark` pin one look everywhere, always,
  regardless of what the OS says.

The data behind a name is resolved **at apply time, nothing cached**:
`scripts/ghostty-theme.py` parses each theme straight out of Ghostty's own
catalog — the files behind `ghostty +list-themes` — and derives everything
from its 16-color palette. New Ghostty themes work the moment you type
their name, there is no catalog in this repo to keep fresh, and the only
thing that pins values is Ghostty itself. Apps without a derivable
equivalent follow the terminal instead: delta disables bat syntax colors
(so diffs render in the theme's own ANSI palette) and nvim/lualine use a
colorscheme generated from the theme's roles — one look, everywhere, by
construction.

The one prerequisite: **Ghostty must be installed wherever you run
`chezmoi apply`** — without it the resolver fails loudly. That is why the
new-machine steps install Ghostty (brew bundle) before applying, and CI
fetches the theme catalog (pinned commit of its upstream,
iTerm2-Color-Schemes) before the smoke test.

Everything rendered — the pi themes, nvim's `core/theming.lua`, the
delta/gitconfig lines — is a build artifact; the smoke test fails
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
- [tmux.md](private_dot_config/nvim/docs/tmux.md) — full walkthrough: the detach/reattach habit, phone setup, troubleshooting

All are installed to `~/.config/nvim/docs/`. In Neovim, `<leader>?` opens the
cheatsheet and `<leader>fk` fuzzy-searches every live mapping. Press `<Space>`
and pause for which-key.
