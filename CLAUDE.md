# CLAUDE.md

Guidance for Claude Code working in this repo.

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
dot_zshrc                  # interactive shell: options, history, aliases, prompt
dot_zprofile               # login-shell PATH (Homebrew)
private_dot_zsh/secrets.example.zsh   # template for ~/.zsh/secrets.zsh
private_dot_config/nvim/
├── init.lua              # sets mapleader, then requires core.* and bruce.lazy
├── lazy-lock.json        # committed; pins exact plugin revisions
└── lua/bruce/
    ├── lazy.lua          # bootstrap + { import = "bruce.plugins" }
    ├── core/             # options, keymaps, autocmds, maximize
    └── plugins/          # one spec file per concern, auto-imported
private_dot_config/zsh/ps1.zsh   # the prompt (git state, duration, exit code)
private_dot_config/ghostty/config # terminal appearance only — no shell settings
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

**Servers come from Homebrew, not Mason.** Mason is deliberately not installed:
one package manager, versions visible in `Brewfile`, no duplicate copies, no
PATH shadowing. To add a server: add it to `Brewfile`, then to the
`vim.lsp.enable({...})` list in `lua/bruce/plugins/lsp.lua`.

**Prefer built-ins.** Neovim 0.12 already provides commenting (`gc`/`gcc`), LSP
keymaps (`grn` `gra` `grr` `gri` `gO` `K`), and the LSP framework. Do not add
plugins for these.

**Keymaps are load-bearing.** Everything in `core/keymaps.lua` is long-standing
muscle memory. Do not "tidy" them. Two intentional quirks:
- `<C-h>` is the file explorer, not focus-left. Focus-left is built-in `<C-w>h`.
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
