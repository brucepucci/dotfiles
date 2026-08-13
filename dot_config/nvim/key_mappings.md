# Key Mappings

**Leader Key**: `Space`

This documents what the config actually binds. Where two mappings collide, the
winner is noted — see [Known conflicts](#known-conflicts) at the end.

## Core Navigation & Editing

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `jk` (insert mode) | Core Neovim | Exit insert mode to normal mode |
| `Space n h` | Core Neovim | Clear search highlights |
| `x` | Core Neovim | Delete character without copying to register |
| `Space +` | Core Neovim | Increment number under cursor |
| `Space -` | Core Neovim | Decrement number under cursor |
| `g r` + motion | vim-ReplaceWithRegister | Replace motion target with register contents |
| `c s`, `d s`, `y s` | vim-surround | Change / delete / add surrounding quotes, brackets, tags |

## Window Management

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space s t` | Core Neovim | Split window vertically |
| `Space s T` | Core Neovim | Split window horizontally |
| `Space s e` | Core Neovim | Make split windows equal width & height |
| `Space s w` | Core Neovim | Close current split window |
| `Space s m` | vim-maximizer | Toggle split window maximization |
| `⌃ + h` | vim-tmux-navigator | Move to window/tmux pane left |
| `⌃ + j` | vim-tmux-navigator | Move to window/tmux pane below |
| `⌃ + k` | vim-tmux-navigator | Move to window/tmux pane above |
| `⌃ + l` | vim-tmux-navigator | Move to window/tmux pane right |

`Space s t` splits **vertically** and `Space s T` splits **horizontally**, which
is the opposite of what the letter case suggests to most people. Noted rather
than changed, since it is muscle memory by now.

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
| `Space f s` | telescope.nvim | Live grep search in files (needs `ripgrep`) |
| `Space f c` | telescope.nvim | Find string under cursor in current directory |
| `Space f b` | telescope.nvim | List open buffers |
| `Space f h` | telescope.nvim | List available help tags |

## Inside the File Explorer

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `l` | nvim-tree (custom) | Open file / expand directory |
| `h` | nvim-tree (custom) | Collapse directory |
| `g ?` | nvim-tree | Show all default mappings for the tree |

All of nvim-tree's default mappings (`a` create, `d` delete, `r` rename, `x`
cut, `c` copy, `p` paste, …) are active alongside these. Use `g ?` in the tree
rather than duplicating that list here.

## Buffer Management

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space f b` | telescope.nvim | List and switch between open buffers |
| `Space b d` | Core Neovim | Delete current buffer |

## Telescope Navigation

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `⌃ + k` (insert) | telescope.nvim | Move to previous result |
| `⌃ + j` (insert) | telescope.nvim | Move to next result |
| `⌃ + q` (insert) | telescope.nvim | Send selected items to quickfix list |
| `⌃ + d` (insert & normal) | telescope.nvim | Delete buffer (buffer picker only) |

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

## LSP

Buffer-local; these exist only once a language server attaches to the buffer.

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space g d` | lspsaga.nvim | Peek definition in a floating, editable window |
| `Space g D` | lspsaga.nvim | Go to definition |
| `Space g t` | lspsaga.nvim | Toggle the Lspsaga floating terminal |
| `Space r n` | lspsaga.nvim | Smart rename symbol |
| `Space d` | lspsaga.nvim | Show diagnostics for the current line |
| `Space /` | lspsaga.nvim | Show hover documentation for symbol under cursor |

### Inside an Lspsaga floating window

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `⌃ + f` | lspsaga.nvim | Scroll down in LSP preview window |
| `⌃ + b` | lspsaga.nvim | Scroll up in LSP preview window |
| `Return` | lspsaga.nvim | Open the file shown in the definition preview |

## Comments

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `g c c` (normal mode) | Comment.nvim | Toggle line comment |
| `g c` (visual mode) | Comment.nvim | Toggle comment for selection |
| `g b c` (normal mode) | Comment.nvim | Toggle block comment |
| `g b` (visual mode) | Comment.nvim | Toggle block comment for selection |

## Python REPL (Iron.nvim)

Loaded on the first Python buffer, so these do not exist in other filetypes.

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space `` | Core Neovim | Toggle REPL window visibility (show/hide) |
| `⌃ + Return` (normal) | iron.nvim | Send current line to the IPython REPL |
| `⌃ + Return` (visual) | iron.nvim | Send selected text to the IPython REPL |
| `Space r c` + motion | iron.nvim | Send the motion's text to the REPL |
| `Space r m` | iron.nvim | Send a named mark to the REPL |
| `Space r m c` + motion | iron.nvim | Create a mark from a motion |
| `Space r m v` (visual) | iron.nvim | Create a mark from the selection |
| `Space r m d` | iron.nvim | Remove a mark |
| `Space r Return` | iron.nvim | Send a bare carriage return to the REPL |
| `Space r Space` | iron.nvim | Interrupt (send SIGINT to) the REPL |
| `Space r q` | iron.nvim | Exit the REPL |
| `Space c l` | iron.nvim | Clear the REPL screen |

**`⌃ + Return` needs terminal support.** Most terminals send an identical byte
sequence for `Return` and `Ctrl+Return`, so Neovim cannot tell them apart and
the mapping silently does nothing. It works in terminals that implement the
kitty keyboard protocol (kitty, WezTerm, Ghostty, foot, and Alacritty ≥ 0.13
with the option enabled). If your terminal does not, use `Space r c` with a
motion instead — `Space r c j` sends the current line and the one below,
`Space r c a p` sends the whole paragraph.

## Terminal Mode

Active inside the REPL window.

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `⌃ + h` | Core Neovim | Leave terminal mode and move to the window left |
| `⌃ + k` | Core Neovim | Leave terminal mode and move to the window above |
| `⌃ + l` | Core Neovim | Leave terminal mode and move to the window right |

There is deliberately no `⌃ + j` here — the REPL sits at the bottom, so there is
nothing below it. Use `⌃ + \` `⌃ + n` to reach normal mode without moving.

## Markdown Workflow

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `Space m p` | markdown-preview.nvim | Start markdown preview in browser |
| `Space m s` | markdown-preview.nvim | Stop markdown preview |
| `Space m m` | markdown-preview.nvim | Toggle markdown preview |

In-buffer rendering (render-markdown.nvim) has no mappings — it applies
automatically to every `.md` buffer.

## Plugin Management

| Key Combination | Package/Source | Description |
|----------------|----------------|-------------|
| `:Lazy` | lazy.nvim | Plugin dashboard: install, update, clean, profile |
| `:Lazy update` | lazy.nvim | Update plugins and rewrite `lazy-lock.json` |
| `:Lazy restore` | lazy.nvim | Reset every plugin to the locked commit |
| `:Mason` | mason.nvim | Install and manage language servers |

## Known conflicts

These are cases where two mappings claim the same key. The winner was confirmed
by inspecting the resolved mappings at runtime, not by reading the source.

1. **`⌃ + h` does not open the file tree.** The last line of
   `lua/bruce/core/keymaps.lua` maps `<C-h>` to `:NvimTreeToggle`, but
   vim-tmux-navigator loads afterwards and claims `<C-h>` for pane navigation,
   so it wins. That line is dead — use `Space .` for the tree. Window
   navigation still behaves correctly, because vim-tmux-navigator falls back to
   ordinary window moves when there is no tmux pane in that direction.

2. **`⌃ + h/j/k/l` are owned by vim-tmux-navigator, not the `<C-w>` maps** in
   `keymaps.lua`, for the same reason. The visible behaviour is the same.

3. **`⌃ + j` / `⌃ + k` are context-dependent.** Window navigation in normal
   mode, completion item selection while the nvim-cmp menu is open, and result
   navigation inside a Telescope prompt. These do not actually collide, since
   each applies in a different mode or context, but it is worth knowing which
   one you are in.

4. **`⌃ + f` / `⌃ + b`** scroll the docs popup in nvim-cmp, scroll the preview
   in an Lspsaga window, and otherwise keep their default page-down/page-up
   meaning.
