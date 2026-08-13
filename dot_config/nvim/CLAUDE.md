# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a personal Neovim configuration using Lua. The structure follows a modular approach:

- `init.lua` - Entry point that requires all modules in order
- `lua/bruce/` - Main configuration namespace
  - `core/` - Core Neovim settings (options, keymaps, colorscheme)
  - `plugins-setup.lua` - Packer plugin manager configuration with all plugin declarations
  - `plugins/` - Individual plugin configurations, each in its own file

## Plugin Management

Uses Packer.nvim for plugin management. All plugins are declared in `lua/bruce/plugins-setup.lua` with their configurations in separate files under `lua/bruce/plugins/`.

Key plugins installed:
- LSP ecosystem: Mason, nvim-lspconfig, lspsaga
- File navigation: nvim-tree, telescope
- Completion: nvim-cmp with various sources
- Syntax highlighting: treesitter
- UI enhancements: lualine, catppuccin theme
- REPL functionality: Iron.nvim for interactive Python development
- Code editing: autoclose brackets, Python PEP8 indentation, commenting
- Markdown workflow: render-markdown.nvim for in-buffer rendering, markdown-preview.nvim for browser preview

## Key Leader Mappings

Leader key is set to space. Important keymaps defined in `lua/bruce/core/keymaps.lua`:
- `<leader>.` - Toggle file explorer (nvim-tree)
- `<leader>ff` - Find files (telescope)
- `<leader>fs` - Live grep search (telescope)
- `<leader>st/sT` - Split windows vertically/horizontally
- `<leader>tt` - New tab
- `<leader>`` - Toggle REPL window visibility
- `<C-CR>` - Send line/selection to REPL (Iron.nvim)
- `<leader>mp/ms/mm` - Markdown preview start/stop/toggle

## LSP Configuration

LSP setup is split across files in `lua/bruce/plugins/lsp/`:
- Mason auto-installs pylsp (Python LSP server)
- Lspconfig handles server configuration
- Lspsaga provides enhanced LSP UI

## REPL Configuration

Iron.nvim provides interactive Python development:
- Uses iPython with `--no-autoindent` flag
- REPL opens in horizontal split at bottom (30 lines)
- Configured in `lua/bruce/plugins/iron.lua`
- Key bindings allow sending code to REPL and toggling window visibility

## Markdown Configuration

Markdown workflow uses two complementary plugins:
- render-markdown.nvim provides beautiful in-buffer rendering with custom icons and styling
- markdown-preview.nvim offers browser-based live preview with math and diagram support
- Configured in `lua/bruce/plugins/render-markdown.lua` and `lua/bruce/plugins/markdown-preview.lua`
- Auto-activates when opening `.md` files

## Development Notes

- Uses 4-space indentation consistently
- Safe plugin loading with pcall() pattern throughout
- Modular structure allows easy addition/removal of plugin configurations
- Some commented code exists showing alternative configurations
- Python-specific enhancements with PEP8 indentation and REPL integration
- Markdown workflow optimized for note-taking with minimal setup