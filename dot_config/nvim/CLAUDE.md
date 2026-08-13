# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a personal Neovim configuration using Lua, managed by chezmoi as part of
the `dotfiles` repo. The live copy is `~/.config/nvim`; the tracked source is
`~/.local/share/chezmoi/dot_config/nvim`. After editing the live copy, run
`chezmoi re-add` so the change is recorded.

The structure follows a modular approach:

- `init.lua` - Entry point: core options, core keymaps, then the plugin manager
- `lua/bruce/` - Main configuration namespace
  - `core/` - Core Neovim settings (options, keymaps, colorscheme)
  - `lazy.lua` - lazy.nvim bootstrap and the full plugin specification
  - `plugins/` - Individual plugin configurations, each in its own file
- `lazy-lock.json` - Exact plugin commits; tracked, and updated by `:Lazy update`

## Plugin Management

Uses lazy.nvim. Plugins are declared in `lua/bruce/lazy.lua`, and each plugin's
configuration lives in its own file under `lua/bruce/plugins/`, invoked from the
spec's `config` function so it runs only once the plugin loads.

To add a plugin: add a spec entry in `lua/bruce/lazy.lua`, create its config file
under `lua/bruce/plugins/`, point `config` at it, then `chezmoi re-add`.

Do not add `require("bruce.plugins.<name>")` calls to `init.lua` — that was the
packer-era pattern and it defeats lazy loading.

Key plugins installed:
- LSP ecosystem: Mason, nvim-lspconfig, lspsaga
- File navigation: nvim-tree, telescope
- Completion: nvim-cmp with various sources
- Syntax highlighting: treesitter (`main` branch — new API)
- UI enhancements: lualine, catppuccin theme
- REPL functionality: Iron.nvim for interactive Python development
- Code editing: autoclose brackets, Python PEP8 indentation
- Commenting is Neovim's built-in `vim._comment` (`gc`/`gcc`), not a plugin
- Markdown workflow: render-markdown.nvim for in-buffer rendering, markdown-preview.nvim for browser preview

## Key Leader Mappings

Leader key is set to space. Important keymaps defined in `lua/bruce/core/keymaps.lua`:
- `<leader>.` - Toggle file explorer (nvim-tree)
- `<leader>ff` - Find files (telescope)
- `<leader>fs` - Live grep search (telescope)
- `<leader>st/sT` - Split windows vertically/horizontally
- `<leader>tt` - New tab
- `<leader>`` - Toggle REPL window visibility
- `<C-CR>` - Send line/selection to REPL (Iron.nvim; needs kitty-protocol terminal)
- `<leader>mp/ms/mm` - Markdown preview start/stop/toggle

LSP mappings (`<leader>gd`, `<leader>gD`, `<leader>rn`, `<leader>d`, `<leader>/`)
are buffer-local and created by an `LspAttach` autocmd in
`lua/bruce/plugins/lsp/lspconfig.lua`, not in `keymaps.lua`.

Note that `vim-tmux-navigator` claims `<C-h/j/k/l>` and overrides the `<C-w>`
mappings in `keymaps.lua`, including the `<C-h>` → `:NvimTreeToggle` line, which
is dead. See `key_mappings.md`.

## LSP Configuration

LSP setup is split across files in `lua/bruce/plugins/lsp/`:
- Mason auto-installs pylsp (Python LSP server)
- `lspconfig.lua` configures servers with Neovim's built-in `vim.lsp.config()` /
  `vim.lsp.enable()` API (0.11+). Do not reintroduce
  `require("lspconfig").<server>.setup({})` — it is deprecated and slated for
  removal in nvim-lspconfig v3.
- Lspsaga provides enhanced LSP UI

pylsp has all of its bundled linters and formatters disabled, so there are no
Python diagnostics at present.

## REPL Configuration

Iron.nvim provides interactive Python development:
- Uses iPython with `--no-autoindent` flag
- REPL opens in horizontal split at bottom (30 lines)
- Configured in `lua/bruce/plugins/iron.lua`
- Loaded on the first Python buffer
- Key bindings allow sending code to REPL and toggling window visibility

## Markdown Configuration

Markdown workflow uses two complementary plugins:
- render-markdown.nvim provides beautiful in-buffer rendering with custom icons and styling
- markdown-preview.nvim offers browser-based live preview with math and diagram support
- Configured in `lua/bruce/plugins/render-markdown.lua` and `lua/bruce/plugins/markdown-preview.lua`
- Both load on the `markdown` filetype

## Development Notes

- Uses 4-space indentation consistently
- Safe plugin loading with pcall() pattern throughout. Be careful: this pattern
  silently swallows genuine errors, and has hidden real bugs here before — if a
  feature appears to do nothing, check whether its `require` is failing.
- Modular structure allows easy addition/removal of plugin configurations
- Some commented code exists showing alternative configurations
- Python-specific enhancements with PEP8 indentation and REPL integration
- Markdown workflow optimized for note-taking with minimal setup

## Verifying Changes

Config changes should be checked by actually starting Neovim, not by reading
alone:

```bash
nvim --headless -c 'checkhealth' -c 'qa!'
nvim --headless <file.py> -c 'lua print(vim.lsp.get_clients({bufnr=0})[1].name)' -c 'qa!'
```
