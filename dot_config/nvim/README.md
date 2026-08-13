# Neovim Configuration

A modular Neovim configuration built with Lua, featuring LSP support, file
navigation, autocompletion, and modern UI enhancements.

This directory is managed by [chezmoi](https://www.chezmoi.io/) from the
`dotfiles` repo — see that repo's README for the edit/apply/push workflow. Files
here can be edited directly, but run `chezmoi re-add` afterwards so the change is
recorded.

## Prerequisites

- **Neovim 0.11+** (`brew install neovim`) — 0.11 is the floor for the LSP setup;
  0.12 for treesitter
- **Git**
- **A Nerd Font** (optional but recommended for icons)
- **ripgrep** — required for telescope live grep: `brew install ripgrep`
- **Node.js** — markdown preview, npm-based LSP servers: `brew install node`
- **iPython** — the Python REPL: `brew install ipython`
- **tree-sitter CLI** — builds parsers: `brew install tree-sitter-cli`
- **A C compiler** — `telescope-fzf-native` and treesitter parsers compile locally

On a machine set up with chezmoi, everything except Neovim itself is installed
by `run_onchange_before_00-install-packages.sh.tmpl`.

## Installation

### With chezmoi (preferred)

```bash
brew install neovim chezmoi
chezmoi init --apply git@github.com:brucepucci/dotfiles.git
```

This writes the config to `~/.config/nvim`, installs the external tools, then
installs every plugin, LSP server and treesitter parser. Launch `nvim` and it is
ready.

### Standalone

Copy this directory to `~/.config/nvim` and start `nvim`. lazy.nvim bootstraps
itself on first launch and installs everything from `lazy-lock.json`.

## Verifying

```bash
nvim --version && rg --version && node --version && tree-sitter --version
```

Inside Neovim:

```vim
:Lazy            " plugin status — everything should show as installed
:checkhealth     " no ERROR lines expected
:Mason           " language servers; pylsp should be installed
:LspInfo         " open a .py file first; pylsp should be attached
```

Warnings from `:checkhealth` about missing Go, Rust, Ruby, PHP, Java or Julia
toolchains are expected — they come from Mason and only matter if you install a
language server that needs them.

### Feature smoke test

1. **File explorer**: `Space .`
2. **File search**: `Space f f`, then `Space f s` for live grep
3. **Markdown**: open a `.md` file for in-buffer rendering; `Space m p` for the
   browser preview
4. **LSP**: open a `.py` file — completion, go-to-definition (`Space g D`),
   rename (`Space r n`)
5. **Python REPL**: `` Space ` ``

## Layout

```
init.lua                     entry point: options, keymaps, then lazy
lua/bruce/
  core/
    options.lua              editor settings
    keymaps.lua              key mappings (leader is Space)
    colorscheme.lua          catppuccin-macchiato
  lazy.lua                   plugin manager bootstrap + full plugin spec
  plugins/                   one config file per plugin
    lsp/
      mason.lua              language server installation
      lspconfig.lua          server configuration and LSP keymaps
      lspsaga.lua            LSP UI
lazy-lock.json               exact plugin commits — commit this
key_mappings.md              full key mapping reference
```

Each plugin is declared in `lua/bruce/lazy.lua` and configured in its own file
under `lua/bruce/plugins/`, wired together by the spec's `config` function.

## Plugin Management

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim).

### Adding a plugin

1. Add an entry to the `spec` table in `lua/bruce/lazy.lua`
2. If it needs configuration, create `lua/bruce/plugins/<name>.lua` and point the
   entry's `config` at it:
   ```lua
   {
     "author/plugin-name",
     event = "VeryLazy",
     config = function()
       require("bruce.plugins.plugin-name")
     end,
   }
   ```
3. Restart Neovim — lazy.nvim installs it automatically — or run `:Lazy sync`
4. `chezmoi re-add` to record both the spec and the updated `lazy-lock.json`

### Updating and pinning

```vim
:Lazy update     " update plugins and rewrite lazy-lock.json
:Lazy restore    " reset every plugin to the commit in lazy-lock.json
:Lazy clean      " remove plugins no longer in the spec
:Lazy profile    " startup time per plugin
```

`lazy-lock.json` pins every plugin to an exact commit and is tracked in the
dotfiles repo, so a new machine reproduces this one exactly. After `:Lazy
update`, run `chezmoi re-add` and commit the lockfile.

## LSP

Neovim 0.11+ supplies the LSP framework itself; `nvim-lspconfig` only ships the
per-server defaults, which Neovim discovers from the runtimepath. Servers are
configured with `vim.lsp.config()` and turned on with `vim.lsp.enable()` in
`lua/bruce/plugins/lsp/lspconfig.lua`. The older
`require("lspconfig").<server>.setup({})` style is deprecated and is not used
here.

Mason installs the server binaries; `mason-lspconfig`'s `ensure_installed` keeps
`pylsp` present. Note that `ensure_installed` is skipped in headless Neovim, so
scripted installs use `:MasonInstall` directly.

`pylsp` is configured with its bundled linters and formatters (flake8,
pycodestyle, pyflakes, mccabe, autopep8, yapf) all disabled, leaving completion,
hover and go-to-definition. That means **there are currently no Python
diagnostics**; wiring up ruff would be the natural next step.

## Treesitter

`nvim-treesitter` is on its rewritten `main` branch, which installs parsers but
enables no features by itself. `lua/bruce/plugins/treesitter.lua` installs the
parsers Neovim does not bundle and starts highlighting per filetype. Neovim
already ships c, lua, markdown, markdown_inline, query, vim and vimdoc.

## Troubleshooting

| Symptom | Check |
|---|---|
| A plugin is missing | `:Lazy` — look for it in the list; `:Lazy sync` |
| Telescope live grep finds nothing | `rg` on `PATH` |
| No completion or diagnostics in Python | `:LspInfo`, then `:Mason` |
| No syntax highlighting for a language | parser installed? `tree-sitter` on `PATH`? |
| Markdown preview does nothing | `node` present, and `npm install` ran in the plugin's `app/` |
| Icons render as boxes | terminal is not using a Nerd Font |
| `⌃ + Return` does nothing in the REPL | terminal limitation — see `key_mappings.md` |

Other useful commands: `:messages` for errors scrolled past, `:Lazy profile` for
slow startup, and `:checkhealth <plugin>` for a specific plugin.

## Key Mappings

See [key_mappings.md](key_mappings.md) for the full reference, including which
mapping wins where two collide.

## Customization

- `lua/bruce/core/options.lua` — editor settings
- `lua/bruce/core/keymaps.lua` — key mappings
- `lua/bruce/core/colorscheme.lua` — theme
- `lua/bruce/lazy.lua` — plugin list and lazy-loading rules
- `lua/bruce/plugins/` — individual plugin configuration
