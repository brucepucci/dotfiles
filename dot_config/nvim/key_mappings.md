# Key Mappings

**Leader Key**: `Space`

## Core Navigation & Editing

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `jk` (insert mode) | Core Neovim | Exit insert mode to normal mode |
| `Space n h` | Core Neovim | Clear search highlights |
| `x` | Core Neovim | Delete character without copying to register |
| `Space +` | Core Neovim | Increment number under cursor |
| `Space -` | Core Neovim | Decrement number under cursor |

## Window Management

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space s t` | Core Neovim | Split window vertically |
| `Space s T` | Core Neovim | Split window horizontally |
| `Space s e` | Core Neovim | Make split windows equal width & height |
| `Space s w` | Core Neovim | Close current split window |
| `Space s m` | vim-maximizer | Toggle split window maximization |
| `⌃ + j` | Core Neovim | Move to window below and enter terminal mode (for REPL) |
| `⌃ + k` | Core Neovim | Move to window above |
| `⌃ + h` | Core Neovim | Move to window left |
| `⌃ + l` | Core Neovim | Move to window right |

## Tab Management

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space t t` | Core Neovim | Open new tab |
| `Space t w` | Core Neovim | Close current tab |
| `Space t l` | Core Neovim | Go to next tab |
| `Space t h` | Core Neovim | Go to previous tab |

## File Operations & Navigation

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space .` | nvim-tree | Toggle file explorer |
| `Space f f` | telescope.nvim | Find files in current working directory |
| `Space f s` | telescope.nvim | Live grep search in files |
| `Space f c` | telescope.nvim | Find string under cursor in current directory |
| `Space f b` | telescope.nvim | List open buffers |
| `Space f h` | telescope.nvim | List available help tags |

## Buffer Management

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space f b` | telescope.nvim | List and switch between open buffers |
| `Space b d` | Core Neovim | Delete current buffer |

## Telescope Navigation (Insert Mode)

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `⌃ + k` | telescope.nvim | Move to previous result in telescope |
| `⌃ + j` | telescope.nvim | Move to next result in telescope |
| `⌃ + q` | telescope.nvim | Send selected items to quickfix list |
| `⌃ + d` | telescope.nvim | Delete buffer (only in buffer picker) |

## Autocompletion (Insert Mode)

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `⌃ + k` | nvim-cmp | Select previous completion suggestion |
| `⌃ + j` | nvim-cmp | Select next completion suggestion |
| `⌃ + b` | nvim-cmp | Scroll completion documentation up |
| `⌃ + f` | nvim-cmp | Scroll completion documentation down |
| `⌃ + Space` | nvim-cmp | Show completion suggestions |
| `⌃ + e` | nvim-cmp | Close completion window |
| `Return` | nvim-cmp | Confirm selected completion |

## LSP Navigation (Lspsaga)

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `⌃ + f` | lspsaga.nvim | Scroll down in LSP preview window |
| `⌃ + b` | lspsaga.nvim | Scroll up in LSP preview window |
| `Return` | lspsaga.nvim | Open file with definition preview |

## Comments

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `g c c` (normal mode) | Comment.nvim | Toggle line comment |
| `g c` (visual mode) | Comment.nvim | Toggle comment for selection |
| `g b c` (normal mode) | Comment.nvim | Toggle block comment |
| `g b` (visual mode) | Comment.nvim | Toggle block comment for selection |

## Python REPL (Iron.nvim)

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `⌃ + Return` (normal mode) | iron.nvim | Send current line to IPython REPL |
| `⌃ + Return` (visual mode) | iron.nvim | Send selected text to IPython REPL |
| `Space `` | iron.nvim | Toggle REPL window visibility (show/hide) |
| `Space r q` | iron.nvim | Exit REPL |
| `Space c l` | iron.nvim | Clear REPL |

## Markdown Workflow

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space m p` | markdown-preview.nvim | Start markdown preview in browser |
| `Space m s` | markdown-preview.nvim | Stop markdown preview |
| `Space m m` | markdown-preview.nvim | Toggle markdown preview |