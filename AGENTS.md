# AGENTS.md

Guidance for coding agents working in this repo (pi, Claude Code,
or anything else that reads the cross-agent AGENTS.md convention).

## What this is

A chezmoi-managed dotfiles repo for an agent-focused terminal workflow:
Neovim is the bulk of it, plus the zsh shell config shared by every terminal
and SSH session, Ghostty (theme only), git tooling (delta, lazygit), and the
pi coding agent (Z.ai/GLM models).

- **Source of truth:** this repo — `private_dot_config/nvim/` for Neovim.
- **Target:** the files in `$HOME` (`~/.config/nvim` etc.) — build artifacts.
  **Never edit them directly.** Edit here, then `chezmoi apply`.
- `private_` prefix exists because `~/.config` is mode 0700; chezmoi preserves that.
- `dot_` prefix maps to a leading `.` in the target. Any dotfile nested inside a
  managed directory **must** use it — chezmoi silently skips source entries
  starting with a literal `.`.

## Architecture

```
dot_zshrc.tmpl              # interactive shell: options, history, aliases, prompt;
                            # the pi() wrapper -- every new conversation gets
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
                            # Ctrl+Option+Enter accepts (both no-ops else);
                            # Option+Delete kills the next word (pi parity).
                            # Option+Enter accepts the autosuggestion,
                            # Option+Tab runs it as-is (both no-ops otherwise)
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
                            # dark_theme -- Ghostty theme names, browsable with
                            # `ghostty +list-themes` -- and tmux_wrap (on|off):
                            # whether pi conversations get tmux sessions
scripts/ghostty-theme.py   # the resolver templates call at apply time (via
                            # chezmoi's `output`): parse+derive each theme
                            # from Ghostty's own catalog -- nothing cached,
                            # nothing goes stale; Ghostty is a prerequisite
                            # for `chezmoi apply` (CI fetches the catalog
                            # from its upstream, iTerm2-Color-Schemes, pinned)
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
                            # theme line from the settings (pair or single)
dot_pi/agent/              # settings.json.tmpl + themes/dotfiles-{light,dark}
                            # .json.tmpl — the pi TUI's themes, generated from
                            # the active themes' roles (stable file names)
```

Adding a plugin = drop a file in `lua/bruce/plugins/` returning a lazy.nvim
spec. No `init.lua` edit.

## Rules for this config

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

**Colors: three appearance settings, zero cached theme data.** Appearance
is edited only via `settings.toml` at the repo root (`theme`,
`light_theme`, `dark_theme` — Ghostty
theme names; `ghostty +list-themes` is the browser). Templates resolve each
name at apply time via `scripts/ghostty-theme.py` (chezmoi `output`),
parsed + derived from Ghostty's own catalog — no overrides, nothing pinned:
what Ghostty ships is what every surface renders (delta falls back to the
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
verbatim, pi rides the slots). Ghostty must be installed where `chezmoi apply` runs. `chezmoi
re-add` skips
template-sourced files (e.g. pi's `settings.json.tmpl`): fold pi's
self-bumps in by hand. See README "Changing the settings" for the
runbook.

**Servers come from Homebrew, not Mason.** Mason is deliberately not installed:
one package manager, versions visible in `Brewfile`, no duplicate copies, no
PATH shadowing. To add a server: add it to `Brewfile`, then to the
`vim.lsp.enable({...})` list in `lua/bruce/plugins/lsp.lua`.

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

```bash
scripts/smoke-test.sh      # from-scratch apply + shell behavior, ~1s -- run
                           # this after EVERY change (see README "Testing
                           # changes" for the VM tiers)
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
