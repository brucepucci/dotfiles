# dotfiles

A chezmoi-managed terminal setup for an **agent-first** workflow: Neovim is
the bulk of it, plus the one zsh shell every terminal and SSH session
shares, Ghostty, git tooling (delta, lazygit), tmux, and the
[pi](https://github.com/earendil-works/pi) coding agent running Z.ai's GLM
models. Built around a simple reality: most code is now *written* by an
agent in one terminal split and *reviewed* by a human in the other — so
the editor is tuned for reading diffs and deciding what to keep, the shell
is tuned for hopping between machines, and everything else stays out of
the way.

**Scope: a Mac, and only a Mac.** One install target — a Mac with Homebrew
and zsh. The one remote story is being SSH'd **into** the Mac: every
terminal and every SSH session reads the same `~/.zshrc`, and the prompt
and pi render in the *viewing* terminal's palette, so a client from any OS
looks right. Installing this on Linux or WSL is explicitly out of scope.

New to the repo? Each tool has its own page in [docs/](docs/):

| Tool / area | Doc | What it covers |
|---|---|---|
| Neovim | [docs/nvim.md](docs/nvim.md) | structure, all 17 plugins, every keybinding grouped (git/review, finding, windows, LSP, REPL…) |
| zsh | [docs/zsh.md](docs/zsh.md) | the one-shell design, history, prompt, shell keybindings & aliases, the pi wrapper, secrets |
| Ghostty | [docs/ghostty.md](docs/ghostty.md) | the terminal — appearance only, the font, why apply needs Ghostty |
| Colors | [docs/theming.md](docs/theming.md) | the whole palette system: two theme names drive every surface, nothing cached |
| tmux + SSH | [docs/tmux.md](docs/tmux.md) | detachable sessions, the phone/SSH workflow, the managed config explained |
| Git tooling | [docs/git.md](docs/git.md) | gitconfig, delta, lazygit, gh — the shell side |
| pi | [docs/pi.md](docs/pi.md) | the coding agent: settings, themes, the tmux wrapper, keys |
| Maintaining this repo | [docs/developing.md](docs/developing.md) | the developer guide: editing, testing, common tasks, rules |

There is also a set of cheatsheet docs *installed into the editor* —
[getting-started](private_dot_config/nvim/docs/getting-started.md) (the
agent-review walkthrough), [keymaps](private_dot_config/nvim/docs/keymaps.md)
(the full cheatsheet), [tools](private_dot_config/nvim/docs/tools.md) (the
tool inventory), and [tmux](private_dot_config/nvim/docs/tmux.md) (the
detach/reattach walkthrough). They live at
`private_dot_config/nvim/docs/`, install to `~/.config/nvim/docs/`, and
open with `<leader>?` in nvim. Repo docs explain the machine; in-editor
docs drive it.

## Why it looks like this

The decisions, so future-you doesn't have to re-derive them:

- **Reviewing is the job.** diffview surveys a whole changeset, gitsigns
  accepts/rejects individual hunks, and staging is the ledger: whatever is
  staged when you open lazygit is precisely what you approved. See
  [docs/nvim.md](docs/nvim.md).
- **One shell everywhere.** Every terminal and SSH session reads the same
  `~/.zshrc`; history is one shared file, merged live. A terminal is just
  a view; the shell doesn't change underneath it. oh-my-zsh and
  powerlevel10k are gone.
- **macOS only, no cross-platform machinery.** Anything that only makes
  sense on another OS doesn't belong here — that surface was removed once
  and shouldn't come back.
- **Homebrew, not Mason; built-ins, not plugins.** One package manager,
  versions visible in the `Brewfile`. Neovim's built-in commenting
  (0.10+), LSP keymaps (0.11+), and LSP framework (0.11+) are used
  instead of plugins for them; the 0.12 floor below is what the rest of
  the config needs (`vim.hl`, nvim-treesitter `main`). The plugin count
  is 17 and shrinking in spirit.
- **Loud failures.** No `pcall(require, ...)` guards. The previous config
  had a silently dead LSP for months because errors were being swallowed;
  this one names what's missing (missing servers warn by name, the config
  refuses to load below Neovim 0.12, the theme resolver fails loudly
  without Ghostty).
- **One look everywhere, by construction.** Two Ghostty theme names in
  `settings.toml` drive every surface — the terminal, prompt, editor,
  statusline, diffs, and pi's TUI — resolved from Ghostty's own catalog at
  apply time with nothing cached. Surfaces that travel over SSH render in
  the terminal's indexed color slots so the *viewing* terminal decides.
  Never a hardcoded hex. See [docs/theming.md](docs/theming.md).
- **Secrets never enter the repo.** `~/.zsh/secrets.zsh` (unmanaged,
  listed in `.chezmoiignore`) holds the keys; pi's `auth.json` and session
  transcripts are unmanaged too.
- **Committed lockfile.** `lazy-lock.json` pins exact plugin revisions —
  a second machine reproduces the first, and a bad update is bisectable
  via `git log -p` on the lockfile.
- **tmux only for detachability.** Local windows are Ghostty's job; tmux
  exists so sessions survive disconnects and rejoin from anywhere — and
  `pi` wraps itself automatically.

## New machine

Six commands on macOS. Order matters — see the notes.

```bash
# 0. Homebrew, if this machine has never had it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 1. Credentials. This repo is PRIVATE, so chezmoi's clone needs them.
brew install chezmoi gh
gh auth login            # choose HTTPS
gh auth setup-git        # installs the git credential helper
#    (needed for the initial private clone; apply re-provides the helper
#    from dot_gitconfig.tmpl afterwards, keychain-free)

# 2. Clone the repo (do NOT apply yet -- the color system reads Ghostty's
#    own theme catalog at apply time, so Ghostty must land first)
chezmoi init brucepucci

# 3. Everything the config needs: Neovim, language servers, ripgrep, fd,
#    lazygit, delta, tmux, ipython, tree-sitter, the Nerd Font, Ghostty
#    itself, the shell QoL trio (fzf, zsh-autosuggestions,
#    zsh-syntax-highlighting), and the pi coding agent (from npm)
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

Then open Ghostty and run `nvim` — or `pi`, once step 6 is done. That is
the whole thing: nothing left to configure by hand — editor, terminal,
shell, git tooling, and coding agent are all in place. From here on, every
change is an edit in this repo plus `chezmoi apply`.

> **Step 1 is not optional.** `chezmoi init` clones over HTTPS, and this repo
> is private, so without a credential helper it fails with
> `Authentication failed`. No SSH key is registered on this account either, so
> `--ssh` is not a fallback.

> **Do step 3 before step 4.** Ghostty must be installed before
> `chezmoi apply` — the palette resolver reads Ghostty's bundled theme
> files to derive every surface's colors, and apply fails loudly without
> it. Language servers come from Homebrew too, not Mason: launching Neovim
> earlier is not fatal — it warns and names what is missing — but
> `Lazy! restore` also needs `tree-sitter` to build parsers.

> **Not using Ghostty?** The Nerd Font is installed by step 3, but only
> Ghostty picks it up automatically. In Terminal.app or iTerm2, set the
> font to JetBrainsMono Nerd Font by hand or icons — and the prompt's git
> branch mark — render as boxes. The shell itself needs nothing: every
> terminal reads the same `~/.zshrc`.

**Requires Neovim 0.12+** (`vim.lsp.config`, `vim.hl`, nvim-treesitter
`main`). Homebrew's `neovim` is current, so this only bites with a
non-Homebrew install.

## What chezmoi manages

| Target | What it is | Doc |
|---|---|---|
| `~/.zshrc`, `~/.zprofile`, `~/.config/zsh/ps1.zsh` | The shell — every terminal, every SSH session | [zsh.md](docs/zsh.md) |
| `~/.config/nvim/` | The editor (17 plugins, pinned) | [nvim.md](docs/nvim.md) |
| `~/.config/ghostty/config` | The terminal's appearance — nothing shell-related | [ghostty.md](docs/ghostty.md) |
| `~/.tmux.conf` | Detachable sessions: pi's extended-keys, OSC 52 clipboard, truecolor | [tmux.md](docs/tmux.md) |
| `~/.gitconfig`, `~/.config/git/ignore` | Identity, delta pager, zdiff3 conflicts | [git.md](docs/git.md) |
| `~/.config/lazygit/config.yml` | delta as lazygit's diff renderer | [git.md](docs/git.md) |
| `~/.local/bin/delta-theme` | Appearance-aware delta wrapper | [git.md](docs/git.md) |
| `~/.pi/agent/settings.json`, `~/.pi/agent/themes/` | pi's settings, generated theme pair, and the `/skill:runbook` verification skill (generated from AGENTS.md) | [pi.md](docs/pi.md) |

Repo-level files that are **never installed** (see `.chezmoiignore`):
this README, `AGENTS.md`, `Brewfile`, `scripts/`, `settings.toml`, and
`docs/`.

Not managed, on purpose: `~/.zsh_history` and `.zcompdump*` (private and
generated), `~/.zsh/secrets.zsh` (API keys — a secret), `~/.ssh/`,
`~/.config/gh/hosts.yml` (auth token), and on the pi side
`~/.pi/agent/auth.json` (optional key copy from `/login`),
`~/.pi/agent/sessions/` (transcripts), and `~/.pi/agent/models-store.json`
(a catalog cache pi refetches itself).

## Changing the settings

Four settings in [settings.toml](settings.toml), right at the repo root —
no hex, no per-app themes:

```toml
theme = "system"                   # "system" | "light" | "dark"
light_theme = "Flexoki Light"
dark_theme = "Kanagawa Wave"
tmux_wrap = "on"                   # "on" | "off": pi in detachable tmux sessions?
```

`light_theme`/`dark_theme` are Ghostty theme names (browse with `ghostty
+list-themes`); `theme` picks follow-the-OS vs pinned; `tmux_wrap` is the
one behavior knob. Edit, `chezmoi diff && chezmoi apply`, and every
surface follows — the full explanation, including what renders where and
why nothing is cached, is in [docs/theming.md](docs/theming.md). The one
prerequisite: **Ghostty must be installed wherever you run
`chezmoi apply`.**

## Editing this config

**Edit in the source repo, never in `$HOME`.** The target is a build
artifact; hand-editing it means the next `chezmoi apply` overwrites your
work.

```bash
chezmoi cd                  # -> ~/.local/share/chezmoi
$EDITOR private_dot_config/nvim/lua/bruce/plugins/foo.lua
chezmoi diff                # review
chezmoi apply               # install
```

Repo-level files (`README.md`, `AGENTS.md`, `docs/`, `Brewfile`,
`settings.toml`) are chezmoi-ignored and never install — edit and commit,
nothing to apply. (`settings.toml` is still *read* at apply time — it
renders every surface.)

Everything else — testing tiers (`scripts/smoke-test.sh`, the macOS VM,
CI), how to add a plugin or an LSP server, the color-system rules, the
designated-successors table, rollback — is in
[docs/developing.md](docs/developing.md), the maintainer's guide.

## Picking up from another device (SSH)

The Mac is a server for your working sessions. pi conversations are
already detachable — typing `pi` in a project directory always starts a
new conversation in its own named tmux session:

```bash
cd code/chezmoi
pi                   # new tmux session "chezmoi" (hint printed), pi inside
# ... work; leave by closing the terminal or Ctrl-b d — the session lives on
tmux a -t chezmoi    # rejoin from ANY terminal: desk, laptop, phone over SSH
```

The session dies when pi exits, so `tmux ls` lists exactly the live
conversations. Anything that isn't pi — nvim, a dev server — wraps by
hand: `tmux new -s work` … `tmux attach -t work`.

Why this works from anywhere: the SSH session reads the same `~/.zshrc`
as the desk terminal (same history, same prompt), and the prompt + pi's
TUI render in the *viewing* terminal's indexed palette — SSH from a
light-mode phone and everything renders light, automatically, because the
terminal in your hand decides. The pi wrapper even probes the connecting
terminal for its light/dark side before creating the session, because
pi's own detection can't see through the tmux layer.

Getting in: enable **Remote Login** (System Settings → General → Sharing);
use Blink Shell or Termius on the phone; put both ends on
[Tailscale](https://tailscale.com) when away from home — **never expose
port 22 to the internet**; keep the Mac awake with `caffeinate -dims`
(a sleeping Mac refuses SSH). Forgot to start under tmux? Every pi
conversation auto-saves — `pi -c` resumes the latest from any machine.
The complete walkthrough — the mental model, phone-client setup, the
handoff end to end, troubleshooting — is installed inside nvim
(`<leader>?` → tmux) and sourced at
[private_dot_config/nvim/docs/tmux.md](private_dot_config/nvim/docs/tmux.md);
[docs/tmux.md](docs/tmux.md) is the repo-side reference (the managed
config, setting by setting, plus the keys and the SSH setup).

## Quick reference

| Action | How |
|---|---|
| Apply config changes | `chezmoi diff && chezmoi apply` |
| Run the test suite | `scripts/smoke-test.sh` (~1s; `--nvim` for plugin restore) |
| Change themes | edit `settings.toml` → `chezmoi apply` |
| Update plugins | `:Lazy update` → `chezmoi re-add ~/.config/nvim/lazy-lock.json` |
| List / rejoin pi conversations | `tmux ls` / `tmux a -t <name>` |
| Resume last pi conversation | `pi -c` |
| In-nvim cheatsheet / keymap search | `<leader>?` / `<leader>fk` |
| Health check | `:checkhealth`, `:Lazy check` |
| The maintainer's guide | [docs/developing.md](docs/developing.md) |

## Rollback

The pre-migration config is kept at `~/.config/nvim-old` and runs side by
side: `NVIM_APPNAME=nvim-old nvim`. Full revert:

```bash
mv ~/.config/nvim ~/.config/nvim.new
mv ~/.config/nvim.pre-chezmoi ~/.config/nvim
mv ~/.local/share/nvim.pre-chezmoi ~/.local/share/nvim
mv ~/.local/state/nvim.pre-chezmoi ~/.local/state/nvim
```

Bad plugin update: `:Lazy restore`. Bad config change: `chezmoi cd && git
revert <sha> && chezmoi apply`. Pre-migration history lives in the archived
[brucepucci/nvim](https://github.com/brucepucci/nvim) repo at tag
`pre-chezmoi-2026-08-27`.
