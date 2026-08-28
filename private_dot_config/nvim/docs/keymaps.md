# Keymaps

Leader is `Space`. Press it and wait — which-key lists what is available.

Anything not listed here is stock Neovim.

## Editing

| Key | Mode | Action |
|---|---|---|
| `jk` | insert | Exit to normal mode |
| `<leader>nh` | n | Clear search highlight |
| `x` | n | Delete char **without** yanking |
| `<leader>+` / `<leader>-` | n | Increment / decrement number |
| `gcc` / `gc{motion}` | n / x | Toggle comment (**built in** since 0.10 — no plugin) |
| `ysiw"` / `cs"'` / `ds"` | n | Surround add / change / delete (vim-surround) |
| `viwP` | n | Replace word with yanked text, **register preserved** |

> `viwP` is the replacement for the old `gr` (vim-ReplaceWithRegister), which was
> removed because it collided with Neovim's built-in `gr*` LSP prefix. Capital
> `P` in visual mode pastes without clobbering the register.

## Windows, splits, tabs

| Key | Action |
|---|---|
| `<leader>st` / `<leader>sT` | Split vertical / horizontal |
| `<leader>se` | Equalize splits |
| `<leader>sw` | Close split |
| `<leader>sm` | Maximize window (toggle — press again to restore) |
| `<C-j>` / `<C-k>` / `<C-l>` | Focus window below / above / right |
| `<C-w>h` | Focus window **left** — built-in |
| `<leader>tt` / `<leader>tw` | New tab / close tab |
| `<leader>tl` / `<leader>th` | Next / previous tab |
| `<leader>bd` | Delete buffer |

> **`<C-h>` is the file explorer, not "focus left."** The previous config mapped
> it both ways and the explorer won, so that is what is in muscle memory. Use the
> built-in `<C-w>h` to focus the window on the left.
>
> Terminal mode has `<C-k>`, `<C-h>` and `<C-l>` but deliberately **no `<C-j>`** —
> the REPL sits at the bottom, so there is nothing below it to move into.

## Finding things (snacks.picker)

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fs` | Live grep |
| `<leader>fc` | Grep word under cursor |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>.` or `<C-h>` | Toggle file explorer |

Inside a picker: `<C-j>` / `<C-k>` move the selection, `<C-q>` sends results to
the quickfix list, and `<C-d>` deletes a buffer in the buffers picker.

## Reviewing changes

The core loop when an agent has rewritten files:
`<leader>vv` → `]h` → `<leader>hp` → `<leader>hs` or `<leader>hr` → `<leader>gg`.

### Hunks — inline, accept/reject one at a time (gitsigns)

| Key | Action |
|---|---|
| `]h` / `[h` | Next / previous hunk |
| `<leader>hp` / `<leader>hP` | Preview hunk inline / in a float |
| `<leader>hs` / `<leader>hr` | **Stage** / **reset** hunk (works on a visual range too) |
| `<leader>hu` | Undo stage hunk |
| `<leader>hS` / `<leader>hR` | Stage / reset the whole buffer |
| `<leader>hb` / `<leader>hB` | Blame line / toggle inline blame |
| `<leader>hd` / `<leader>hD` | Diff against index / against `HEAD~` |
| `ih` | Hunk text object (e.g. `dih`, `vih`) |

Whatever you leave staged **is** your reviewed changeset.

### Changesets — side by side, does the whole thing hang together (diffview)

| Key | Action |
|---|---|
| `<leader>vv` | Review working tree (the agent's whole changeset) |
| `<leader>vs` | Review only what is staged |
| `<leader>vc` | Close diffview |
| `<leader>vh` / `<leader>vH` | History of this file / of the repo |
| `<leader>vm` | Branch vs `origin/main`, the way a PR shows it |

Inside diffview, `g?` lists its own keys.

### Git TUI

| Key | Action |
|---|---|
| `<leader>gg` | Lazygit |
| `<leader>gl` | Lazygit log |

## LSP

These are **Neovim built-ins** (0.11+), active whenever a language server attaches.

| Key | Action |
|---|---|
| `K` | Hover docs |
| `grn` | Rename symbol |
| `gra` | Code action |
| `grr` | Find references |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `gO` | Document symbols |
| `]d` / `[d` | Next / previous diagnostic |
| `<C-S>` | Signature help (insert mode) |

Added on top:

| Key | Action |
|---|---|
| `<leader>d` | Show line diagnostics in a float |
| `<leader>/` | Hover docs (alias for `K`) |

Servers: **ruff** (lint + format) and **pyright** (types) for Python, **lua_ls**,
**marksman** for markdown. Ruff's hover is switched off so only Pyright answers
`K` — otherwise two popups compete.

## Completion (blink.cmp)

| Key | Action |
|---|---|
| `<C-j>` / `<C-k>` | Next / previous item |
| `<C-b>` / `<C-f>` | Scroll docs up / down |
| `<C-Space>` | Trigger completion |
| `<C-e>` | Dismiss |
| `<CR>` | Confirm |

Nothing is preselected, so `<CR>` never inserts something you did not choose.

## Python REPL (iron.nvim)

| Key | Action |
|---|---|
| ``<leader>` `` | Toggle the REPL window |
| `<C-CR>` | Send line (normal) or selection (visual) |
| `<leader>rc{motion}` | Send motion |
| `<leader>r<CR>` | Send a bare carriage return |
| `<leader>r<Space>` | Interrupt |
| `<leader>rq` | Exit REPL |
| `<leader>cl` | Clear REPL |
| `<leader>rm` | Set mark |
| `<leader>rmc` / `<leader>rmv` / `<leader>rmd` | Mark motion / visual / remove |

> `<leader>rm` is a prefix of `<leader>rmc`/`rmv`/`rmd`, so it pauses for
> `timeoutlen` before firing. That is expected, not a bug — which-key shows the
> options during the pause.

## Markdown

| Key | Action |
|---|---|
| `<leader>mp` / `<leader>ms` / `<leader>mm` | Preview start / stop / toggle |

Rendering in the buffer is automatic for `.md` files.
