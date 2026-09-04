# AGENTS.md

Guidance for coding agents working in this repo (pi, Claude Code,
or anything else that reads the cross-agent AGENTS.md convention).

## What this is

A chezmoi-managed dotfiles repo for an agent-focused terminal workflow:
Neovim is the bulk of it, plus the zsh shell config shared by every terminal
and SSH session, Ghostty (theme only), git tooling (delta, lazygit), tmux
(detachable sessions), and the pi coding agent (Z.ai/GLM models).

`docs/` at the repo root (never installed -- see `.chezmoiignore`) holds one
page per tool plus `docs/developing.md`, the long-form maintainer guide:
edit loop, test pyramid, common tasks, rollback. This file is the condensed
agent-facing version of those rules -- keep the two in step when either
changes.

**macOS only.** The repo is optimized for one install target: a Mac with
Homebrew and zsh. The only remote story is being SSH'd *into* the Mac.
Nothing supports installing on Linux or WSL, and cross-platform machinery
(OS.linux? gates, distro caveats, Linux CI, alternate install paths) should
not be reintroduced.

- **Source of truth:** this repo — `private_dot_config/nvim/` for Neovim.
- **Target:** the files in `$HOME` (`~/.config/nvim` etc.) — build artifacts.
  **Never edit them directly.** Edit here, then `chezmoi apply`.
- `private_` prefix exists because `~/.config` is mode 0700; chezmoi preserves that.
- `dot_` prefix maps to a leading `.` in the target. Any dotfile nested inside a
  managed directory **must** use it — chezmoi silently skips source entries
  starting with a literal `.`.

## Architecture

```
dot_zshrc.tmpl              # interactive shell: options, history, aliases,
                            # clipboard helpers (clipcopy/clippaste, over
                            # pbcopy/pbpaste), prompt; the pi() wrapper --
                            # every new conversation gets
                            # its own named tmux session (never attaches) and
                            # probes the viewing terminal for the theme side.
                            # TWO conditional renders: tmux_wrap=off defaults
                            # PI_TMUX_WRAP to never; a pinned theme renders
                            # PI_THEME_PINNED (the wrapper must not inject
                            # --use-theme over the pin). Guarded fzf /
                            # zsh-autosuggestions / zsh-syntax-highlighting
                            # blocks after compinit; syntax-highlighting is
                            # sourced LAST (it wraps ZLE widgets at load).
                            # Ctrl+Enter runs the autosuggestion as-is,
                            # Ctrl+Option+Enter accepts (both no-ops else;
                            # Ghostty-scoped, csi-u twins for tmux);
                            # Option+forward-delete (fn+Delete) kills the
                            # next word (pi parity).
dot_zprofile               # login-shell PATH (Homebrew, ~/.local/bin)
dot_local/bin/executable_delta-theme.tmpl   # ~/.local/bin: delta, colored for the
                            # configured mode/theme; git + lazygit call it
dot_gitconfig.tmpl         # delta fallback syntax-theme from the theme files
dot_tmux.conf              # tmux, minimal on purpose: pi's extended-keys
                            # (Shift+Enter survives the tmux layer) + OSC52
                            # clipboard + truecolor + mouse-wheel copy-mode
                            # scrollback. Detach/reattach only --
                            # local window management stays Ghostty's job
private_dot_zsh/secrets.example.zsh   # template for ~/.zsh/secrets.zsh
settings.toml              # THE SETTINGS users edit, visible at the repo
                            # root: theme (light|dark|system), light_theme,
                            # dark_theme -- names resolved against themes/,
                            # browsed in the iTerm2-Color-Schemes README
                            # gallery -- and tmux_wrap (on|off):
                            # whether pi conversations get tmux sessions
themes/                    # the committed theme mirror (never installed):
                            # a verbatim copy of iTerm2-Color-Schemes'
                            # ghostty/ directory; themes/SOURCE.md records
                            # the upstream SHA; scripts/themes-sync.sh
                            # refreshes it (by hand, never at apply time)
scripts/theme.py           # the resolver templates call at apply time (via
                            # chezmoi's `output`): parse+derive each theme
                            # from the vendored mirror -- no network, no
                            # Ghostty install needed for `chezmoi apply`
private_dot_config/nvim/
├── init.lua              # sets mapleader, syncs appearance, then requires
│                         # core.* and bruce.lazy
├── lazy-lock.json        # committed; pins exact plugin revisions
└── lua/bruce/
    ├── lazy.lua          # bootstrap + { import = "bruce.plugins" }
    ├── core/theming.lua.tmpl  # GENERATED: mode + both themes' role tables
    │                     # -- nvim's ONLY rendered file
    ├── core/appearance.lua    # mode-aware background + scheme application
    ├── colors/scheme.lua      # the colorscheme, generated from the roles
    └── plugins/          # one spec file per concern, auto-imported
private_dot_config/zsh/ps1.zsh       # the prompt (git state, duration, exit
                            # code); fully indexed colors 0-15 -- static, follows
                            # whatever theme the terminal runs
private_dot_config/ghostty/config.tmpl # terminal appearance only — no shell settings;
                            # theme line names two GENERATED user themes in
                            # ~/.config/ghostty/themes/dotfiles-{light,dark}
                            # (pair or single, from the settings)
private_dot_config/ghostty/themes/      # those two theme files, rendered from
                            # the same resolved palettes every surface uses
dot_pi/agent/              # settings.json.tmpl + themes/dotfiles-{light,dark}
                            # .json.tmpl — the pi TUI's themes, generated from
                            # the active themes' roles (stable file names);
                            # skills/chezmoi-runbook/SKILL.md — this
                            # runbook as a pi skill (/skill:chezmoi-runbook),
                            # smoke-guarded against this file;
                            # extensions/provider-usage.ts — a
                            # footer row with plan quota (z.ai + Claude Pro
                            # OAuth) and output tok/s for the active provider;
                            # extensions/title-screen.ts — the startup splash:
                            # a "PI" block in pi's section-header color
                            # (mdHeading) at a small left indent, captioned
                            # with the model + effort at install (roles only;
                            # re-installed on every session switch;
                            # /builtin-header restores pi's own header)
docs/                      # repo-level docs, never installed: one page per
                            # tool + developing.md (the maintainer guide)
```

Adding a plugin = drop a file in `lua/bruce/plugins/` returning a lazy.nvim
spec. No `init.lua` edit.

## Rules for this config

**macOS only.** The target is a Mac with Homebrew and zsh; SSH *into* the
Mac is the supported remote case (which is why the prompt and pi render in
indexed terminal slots that follow the viewing terminal). Do not add
cross-platform branches, Linux CI, or "works on distro X" caveats — if a
change only makes sense on another OS, it does not belong here.

**One shell everywhere.** `~/.zshrc` + `~/.zprofile` + `~/.config/zsh/ps1.zsh`
are the only shell config; every terminal and SSH session reads them. The
Ghostty config sets nothing shell-related — do not reintroduce a ZDOTDIR or
shell env lines there. History is one shared file, `~/.zsh_history`.

**Secrets never go in this repo.** They live in `~/.zsh/secrets.zsh`
(`private_dot_zsh/secrets.example.zsh` is the template; the real file is in
`.chezmoiignore`). That includes the Z.ai key: `ZAI_API_KEY`. pi's `/login`
may also write a copy to `~/.pi/agent/auth.json`, which takes precedence
over the env var when present — also unmanaged, also never committed.

**No `pcall(require, ...)` guards.** The previous config wrapped every plugin
file in `local ok, x = pcall(require, "..."); if not ok then return end`. That
turned loud, fixable startup errors into silent feature loss — it is why the LSP
was broken for months with no error shown. Let failures be loud.

`pcall` is fine where failure is genuinely expected and not exceptional (e.g.
`vim.treesitter.start` on a filetype with no parser).

**Colors: three appearance settings, one committed mirror.** Appearance
is edited only via `settings.toml` at the repo root (`theme`,
`light_theme`, `dark_theme` — theme names resolved against the vendored
mirror in `themes/`, rooted in mbadolato/iTerm2-Color-Schemes; the
upstream README gallery is the browser; `scripts/themes-sync.sh`
refreshes the mirror by hand). Templates resolve each
name at apply time via `scripts/theme.py` (chezmoi `output`),
parsed + derived from the mirror — no network, no Ghostty install
needed for apply: what the mirror holds is what every surface renders
(delta falls back to the
terminal's own palette; nvim/lualine use a scheme generated from the roles).
Never hardcode a hex or theme name in a managed file — render it from the
resolver or read it via `bruce.core.theming`. Surfaces that travel over
SSH (the prompt, pi's TUI) avoid hexes entirely: they render in the
terminal's indexed slots, which the *viewing* terminal maps through its
own palette — pi's only hexes are the two live-derived tool tints, where
the fixed xterm cube has no honest match (a sparse custom theme whose
slots the author left out also falls back to role hexes — see `pi_vars`).
In nvim, only
`core/theming.lua` is generated; the rest is static Lua. The smoke test's
color-system step is the drift guard (names resolve, no orphan hexes, roles
verbatim, pi rides the slots). `chezmoi
re-add` skips
template-sourced files (e.g. pi's `settings.json.tmpl`): fold pi's
self-bumps in by hand. See docs/developing.md ("pi self-bumps") for the
runbook.

**Servers come from Homebrew, not Mason.** Mason is deliberately not installed:
one package manager, versions visible in `Brewfile`, no duplicate copies, no
PATH shadowing. To add a server: add it to `Brewfile`, then to the
`vim.lsp.enable({...})` list *and* the `exes` table (which drives the
missing-binary warning) in `lua/bruce/plugins/lsp.lua`.

**Prefer built-ins.** Neovim 0.12 already provides commenting (`gc`/`gcc`), LSP
keymaps (`grn` `gra` `grr` `gri` `gO` `K`), and the LSP framework. Do not add
plugins for these.

**Keymaps are load-bearing.** Everything in `core/keymaps.lua` is long-standing
muscle memory. Do not "tidy" them. Two intentional quirks:
- The file explorer is `<leader>.` (a leader chord, like every other action);
  `<C-h>`/`<C-j>`/`<C-k>`/`<C-l>` are uniformly window movement, never actions.
- Terminal mode has `<C-k>`/`<C-h>`/`<C-l>` but no `<C-j>`, because the REPL is
  the bottom split.

## After changing plugins

```
:Lazy sync
chezmoi re-add ~/.config/nvim/lazy-lock.json
```

The lockfile must be committed — it is the reproducibility guarantee and makes a
bad update bisectable via `git log -p -- private_dot_config/nvim/lazy-lock.json`.

## Verifying a change

This runbook also ships as a pi skill (dot_pi/agent/skills/
chezmoi-runbook/SKILL.md → ~/.pi/agent/skills/, `/skill:chezmoi-runbook`)
so pi can be told to verify with one command. AGENTS.md stays the source
of truth: the smoke test asserts every command line the skill teaches
appears verbatim here, so edit both together or tier 1 fails.

```bash
chezmoi cd                  # -> ~/.local/share/chezmoi, if not already there
scripts/smoke-test.sh      # from-scratch apply + shell behavior, ~1s -- run
                           # this after EVERY change (see docs/developing.md
                           # for the full test pyramid and the VM tiers)
chezmoi diff && chezmoi apply
nvim --headless "+checkhealth" "+w! /tmp/h.txt" +qa && grep -E 'ERROR|WARNING' /tmp/h.txt
```

For LSP changes, confirm clients actually attach — this config exists partly
because they silently did not:

```bash
nvim --headless some.py '+lua vim.wait(6000, function() return #vim.lsp.get_clients({bufnr=0}) >= 2 end); for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do print(c.name) end' +qa
```

## Designated successors

If one of these breaks, this is the intended replacement — noted so the decision
does not have to be re-derived:

| Current | Successor | Note |
|---|---|---|
| `tpope/vim-surround` | `mini.surround` | different keys: `gsa`/`gsd`/`gsr` |
| `markdown-preview.nvim` | `toppair/peek.nvim` | Deno-based |
| `blink.cmp` | built-in `vim.o.autocomplete` | 0.12+; loses docs window & snippet ranking |
| lazy.nvim | `vim.pack` | built-in, has its own lockfile; blocked on lazy-loading support |
| `dlyongemallo/diffview.nvim` | `sindrets/diffview.nvim` | the fork exists only because upstream went quiet in 2024 |
