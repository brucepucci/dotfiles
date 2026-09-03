# Keymaps

New here? Start with [getting-started.md](getting-started.md) — it walks the
agent-review workflow end to end. This file is the reference.

Leader is `Space`. Grouped by what you're trying to do, not by which plugin
provides it.

**which-key is the live source of truth** — press `<Space>` and wait, and it
shows what's available. This file exists for the things which-key can't tell
you: the workflows, the keys that live inside other tools' windows, and the
built-ins that belong to no plugin.

`<leader>fk` fuzzy-searches every mapping in the session and jumps to where it
was defined. That one can never go stale.

## The scheme

`<leader>` + one letter for the **domain**, one for the **verb**. Capital
widens the scope. `<C-hjkl>` is always movement, never an action.

| Prefix | Domain |
|---|---|
| `<leader>f` | find (pickers) |
| `<leader>g` | git — all of it |
| `<leader>s` | split / window |
| `<leader>t` | tab |
| `<leader>b` | buffer |
| `<leader>r` | REPL |
| `<leader>m` | markdown |

---

## Reviewing code an agent wrote

This is what the config is built for. Two tools at two granularities:
**diffview** surveys the whole changeset, **gitsigns** accepts or rejects
individual hunks. Staging is your accept/reject ledger — whatever ends up
staged is what you keep.

**1 — survey what changed**

| Key | Action |
|---|---|
| `<leader>gd` | Open the changeset (working tree vs index) |
| `<Tab>` / `<S-Tab>` | Next / previous file, inside diffview |
| `-` | Stage or unstage an entire file, from the file panel |
| `<leader>gm` | Review the whole branch, the way a PR shows it |
| `<leader>gq` | Close |

**2 — decide, hunk by hunk** (in the normal buffer, after closing diffview)

| Key | Action |
|---|---|
| `<leader>gl` | Next hunk |
| `<leader>gh` | Previous hunk |
| `<leader>gp` | Preview the hunk inline |
| `<leader>gs` | **Stage** it — accept |
| `<leader>gr` | **Reset** it — reject, discard from disk |
| `<leader>gu` | Undo the last stage |
| `ih` | Hunk as a text object — `dih`, `vih` |

`<leader>gs` and `<leader>gr` also work on a visual selection, for part of a hunk.

**3 — commit**

| Key | Action |
|---|---|
| `<leader>gg` | lazygit |

> Hunk keys are buffer-local to real files. They do nothing in diffview's file
> panel — that's why the loop closes diffview before staging.

**Other git**

| Key | Action |
|---|---|
| `<leader>gD` | Review only what's staged |
| `<leader>gS` / `<leader>gR` | Stage / reset the whole buffer |
| `<leader>gb` | Blame this line |
| `<leader>gB` | Toggle inline blame |
| `<leader>gP` | Preview hunk in a floating window |
| `<leader>gf` / `<leader>gF` | History of this file / of the repo |

Files an agent rewrites reload on their own — no `:e` needed. If you had
unsaved changes to the same file, you get a prompt instead of losing them.

---

## Finding things

| Key | Action |
|---|---|
| `<leader>ff` | Files |
| `<leader>fs` | Grep (live) |
| `<leader>fc` | Grep the word under the cursor (works on a visual selection too) |
| `<leader>fb` | Open buffers |
| `<leader>fh` | Help tags |
| `<leader>fk` | **Every keymap**, searchable, jumps to its definition |
| `<leader>fr` | Reopen the last picker where you left it |
| `<leader>.` | File explorer |
| `<leader>?` | Docs picker (this file is one of the choices) |

Inside a picker: `<C-j>` / `<C-k>` move, `<C-q>` sends everything to the
quickfix list, `<Tab>` multi-selects, `?` shows the rest. In the buffers
picker, `<C-d>` deletes a buffer.

In the explorer: `l` opens, `h` closes, `a` adds, `d` deletes, `r` renames,
`y`/`p` copy and paste.

---

## Windows, splits, tabs

| Key | Action |
|---|---|
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Focus window left / below / above / right |
| `<leader>st` / `<leader>sT` | Split vertical / horizontal |
| `<leader>se` | Equalize |
| `<leader>sw` | Close split |
| `<leader>sm` | Maximize this window (press again to restore) |
| `<leader>tt` / `<leader>tw` | New tab / close tab |
| `<leader>tl` / `<leader>th` | Next / previous tab |
| `<leader>bd` | Delete buffer |

`:q` from the last session-holding window in a tab closes the disposable
UI beside it (explorer, pickers, prompts) and exits Neovim — no need to
quit each one. A terminal split (the REPL, an agent terminal), another
*visible* editor, or anything in another tab keeps the app open; saved
hidden buffers do not. `:q!` keeps its bang; unsaved buffers block with
Neovim's own one-line E37.

In terminal mode, `<C-k>` / `<C-h>` / `<C-l>` escape back to your code. There's
no `<C-j>` — the REPL is the bottom split, so there's nothing below it.

---

## Editing

| Key | Action |
|---|---|
| `jk` | Leave insert mode |
| `<leader>nh` | Clear search highlight |
| `x` | Delete a character **without** clobbering your register |
| `viwP` | Replace a word with what you yanked, register preserved |
| `gcc` / `gc{motion}` | Toggle comment — **built in**, no plugin |
| `ysiw"` / `cs"'` / `ds"` | Surround: add / change / delete |
| `<leader>+` / `<leader>-` | Increment / decrement the number under the cursor |

> `viwP` replaced the old `gr` mapping, which collided with Neovim's built-in
> `gr` LSP prefix. Capital `P` in visual mode pastes without taking the
> replaced text into the register.

Prose files — `.md` and `.txt` — soft-wrap; code stays unwrapped. It's
display-only (`textwidth` untouched), and `:setlocal wrap!` toggles the
current window if you want the opposite for one buffer.

---

## LSP

All built into Neovim 0.11+ — they work whenever a language server is attached.

| Key | Action |
|---|---|
| `K` | Hover docs |
| `grn` | Rename symbol |
| `gra` | Code action |
| `grr` | Find references |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `gO` | Document symbols |
| `<C-]>` | Go to definition |
| `]d` / `[d` | Next / previous diagnostic |
| `<C-S>` | Signature help (insert and snippet mode) |

Added on top:

| Key | Action |
|---|---|
| `<leader>d` | Line diagnostics in a float |
| `<leader>/` | Hover — same as `K` |

**Servers:** ruff (lint + format) and Pyright (types) for Python, lua_ls for
Lua, marksman for markdown. Ruff's hover is switched off so only Pyright
answers `K`. If a server isn't installed you get a warning naming it — silence
means they're all running.

**Formatting** has no keybinding on purpose (auto-format would rewrite what an
agent just produced and pollute the diff you're reviewing). Use `gqip` for a
paragraph, `gggqG` for the file, or `:lua vim.lsp.buf.format()`.

---

## Completion

| Key | Action |
|---|---|
| `<C-j>` / `<C-k>` | Next / previous item |
| `<C-b>` / `<C-f>` | Scroll the docs popup |
| `<C-Space>` | Trigger completion |
| `<C-e>` | Dismiss |
| `<CR>` | Confirm |
| `<Tab>` / `<S-Tab>` | Jump between snippet placeholders |

Nothing is preselected, so `<CR>` never inserts something you didn't pick.

---

## Python REPL

Keys are live as soon as you open a Python file.

| Key | Action |
|---|---|
| `` <leader>` `` | Show / hide the REPL |
| `<C-CR>` | Send the current line, or the visual selection |
| `<leader>rc{motion}` | Send a motion — `<leader>rcG` sends to end of file |
| `<leader>ri` | Interrupt |
| `<leader>rl` | Clear |
| `<leader>rq` | Quit the REPL |
| `<leader>r<CR>` | Send a bare newline |
| `<leader>rmc` / `<leader>rmv` | Mark a region by motion / visually |
| `<leader>rs` | Send the marked region |
| `<leader>rmd` | Remove the mark |

Only Python is configured — `` <leader>` `` in another filetype reports that
there's no REPL for it.

---

## Markdown

| Key | Action |
|---|---|
| `<leader>mp` / `<leader>ms` / `<leader>mm` | Browser preview: start / stop / toggle |

In-buffer rendering is automatic for `.md`.

---

## Gotchas

- `<C-l>` focuses the window to the right, which costs you Vim's built-in
  `<C-l>` (clear highlight + redraw). That's what `<leader>nh` is for.
- Inside the file explorer, `<leader>/` greps instead of showing hover.
- Inside diffview, `<leader>b` toggles its file panel, so `<leader>bd` pauses
  briefly waiting to see which you meant.
- `<leader>rmc` / `<leader>rmv` / `<leader>rmd` share a prefix, so they pause
  for a moment. which-key shows the options during the pause.

## When this file is wrong

Trust which-key and `<leader>fk` over this document — they read the live
config. If you find a difference, this file is the thing that's out of date.

See also: [getting-started.md](getting-started.md) · [tools.md](tools.md)
