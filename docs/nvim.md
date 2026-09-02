# Neovim

Neovim is the heart of this setup. It is configured for one primary job:
**reviewing code that an AI agent wrote**. Most of the typing happens in the
pi coding agent in an adjacent terminal split; the editor's job is reading a
diff and deciding what to keep. Everything here is built around that loop —
but it remains a completely ordinary, pleasant editor for writing code by
hand too.

**Requires Neovim 0.12+.** Below that the config refuses to load and says so,
rather than half-working: `vim.lsp.config`, `vim.hl`, and nvim-treesitter's
`main` branch all need it. Homebrew's `neovim` is current, so this only
bites if you install Neovim some other way.

**Managed files** (source in `private_dot_config/nvim/`):

```
init.lua                 entry point: version floor, mapleader, core requires
lazy-lock.json           committed — pins every plugin's exact revision
lua/bruce/
├── lazy.lua             lazy.nvim bootstrap + auto-import of bruce.plugins
├── core/
│   ├── options.lua      settings (relativenumber, 4-space indent, clipboard…)
│   ├── keymaps.lua      the load-bearing custom keys (see below)
│   ├── autocmds.lua     external-write reloads, appearance sync, treesitter,
│   │                     last-window exit handling
│   ├── appearance.lua   light/dark mode: detect, set 'background', apply scheme
│   ├── maximize.lua     40-line window maximize (replaced vim-maximizer)
│   └── theming.lua.tmpl GENERATED at apply time — the palette data (see
│                         docs/theming.md); the only rendered file
├── colors/scheme.lua    the colorscheme, built from theming.lua's roles
└── plugins/*.lua        one spec file per concern, auto-imported
```

Adding a plugin = drop a file in `lua/bruce/plugins/`. No `init.lua` edit.
Plugin-owned keybindings live in the spec that owns them (so lazy-loading
triggers stay accurate); the core, always-on bindings live in
`core/keymaps.lua`.

---

## Keybindings

Leader is `Space`. The scheme: `<leader>` + one letter for the **domain**,
one for the **verb**. Capital widens the scope. `<C-hjkl>` is always window
movement, never an action. These are long-standing muscle memory — the map
is deliberate, not accidental.

**which-key is the live source of truth**: press `<Space>` and pause to see
what's available under any prefix, or `<leader>fk` to fuzzy-search every
mapping in the session (it jumps to where the mapping was defined, so it
can never go stale). The same cheatsheet is installed inside the editor at
`~/.config/nvim/docs/keymaps.md` (`<leader>?` opens the docs picker) — the
installed cheatsheet is the authoritative copy; these tables mirror it for
repo-side reading, and when they disagree, this file is the one to fix.

### Git / reviewing agent-written code

Two tools, two granularities. **diffview** surveys the whole changeset;
**gitsigns** accepts/rejects individual hunks. The key idea: *staging is
your accept/reject ledger* — whatever ends up staged is what you keep, and
`git diff --cached` is exactly the set you approved.

| Key | Action |
|---|---|
| `<leader>gd` | Open the changeset (working tree vs index) — diffview |
| `<leader>gD` | Review only what's **staged** |
| `<leader>gm` | Review the whole branch vs `origin/main`, the way a PR shows it |
| `<leader>gf` / `<leader>gF` | History of this file / of the whole repo |
| `<leader>gq` | Close diffview |
| `<Tab>` / `<S-Tab>` | Next / previous file (inside diffview) |
| `-` | Stage or unstage an entire file (from diffview's file panel) |
| `<leader>gh` / `<leader>gl` | Previous / next hunk (gitsigns, normal buffer) |
| `<leader>gp` / `<leader>gP` | Preview hunk inline / in a floating window |
| `<leader>gs` | **Stage** hunk — accept (also works on a visual selection) |
| `<leader>gr` | **Reset** hunk — reject, discards from disk (visual too) |
| `<leader>gS` / `<leader>gR` | Stage / reset the whole buffer |
| `<leader>gu` | Undo the last stage |
| `<leader>gb` / `<leader>gB` | Blame this line (full) / toggle inline blame |
| `ih` | Hunk as a text object — `dih` deletes it, `vih` selects it |
| `<leader>gg` | lazygit, full-screen float |

Hunk keys are buffer-local to real files — they do nothing in diffview's
file panel, which is why the review loop closes diffview before staging.

### Finding things (snacks.picker)

| Key | Action |
|---|---|
| `<leader>ff` | Find files (fd under the hood) |
| `<leader>fs` | Live grep across the project (ripgrep; no fallback) |
| `<leader>fc` | Grep the word under the cursor (visual selection too) |
| `<leader>fb` | Open buffers |
| `<leader>fh` | Help tags |
| `<leader>fk` | Search **every keymap**, jump to its definition |
| `<leader>fr` | Reopen the last picker where you left it |
| `<leader>.` | File explorer (`<leader>.` is a leader chord, like every action) |
| `<leader>?` | Docs picker (the installed cheatsheets) |

Inside a picker: `<C-j>`/`<C-k>` move, `<C-q>` sends results to the
quickfix list, `<Tab>` multi-selects, `?` shows more. In the buffers
picker, `<C-d>` deletes a buffer. In the explorer: `l` open, `h` close,
`a` add, `d` delete, `r` rename, `y`/`p` copy/paste.

### Windows, splits, tabs, buffers

| Key | Action |
|---|---|
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Focus window left / below / above / right |
| `<leader>st` / `<leader>sT` | Split vertical / horizontal |
| `<leader>se` | Equalize splits |
| `<leader>sw` | Close split |
| `<leader>sm` | Maximize this window (toggle; 40-line core module) |
| `<leader>tt` / `<leader>tw` | New tab / close tab |
| `<leader>tl` / `<leader>th` | Next / previous tab |
| `<leader>bd` | Delete buffer |

**Leaving Neovim** — `:q` from the last ordinary editing window exits the
whole application, closing any auxiliary UI beside it (explorer, pickers,
prompts); you never have to quit each helper window first. The rule counts
**windows, not buffers**: saved hidden buffers are closed along with
everything else, while another *visible* editing window — in a split or in
another tab — keeps the app open, so `:q` there closes just that window.
Unsaved hidden buffers still block the exit with the usual E37 warning.
(QuitPre handler in `core/autocmds.lua`; "auxiliary" is any window whose
buffer isn't a normal file, so it needs no knowledge of which plugin owns
which window.)

### Editing

| Key | Action |
|---|---|
| `jk` | Leave insert mode |
| `<leader>nh` | Clear search highlighting (replaces the `<C-l>` that window-nav took) |
| `x` | Delete a character without clobbering the register |
| `viwP` | Replace a word with the yank, register preserved (capital `P` keeps it) |
| `gcc` / `gc{motion}` | Toggle comment — **built in** since Neovim 0.10, no plugin |
| `ysiw"` / `cs"'` / `ds"` | Surround: add / change / delete (vim-surround) |
| `<leader>+` / `<leader>-` | Increment / decrement number under cursor |

`viwP` replaced the old `gr` mapping, which collided with Neovim's
built-in `gr` LSP prefix.

### LSP (built-in since 0.11 — no plugin needed for the keys)

| Key | Action |
|---|---|
| `K` | Hover docs |
| `<leader>/` | Hover docs, same as `K` |
| `grn` | Rename symbol |
| `gra` | Code action |
| `grr` | Find references |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `gO` | Document symbols |
| `<C-]>` | Go to definition |
| `]d` / `[d` | Next / previous diagnostic |
| `<leader>d` | Line diagnostics in a float |
| `<C-S>` | Signature help (insert and snippet mode) |

**Servers** (from Homebrew, never Mason): `ruff` (Python lint + format),
`pyright` (Python types), `lua_ls` (Lua — for editing this very config),
`marksman` (markdown). Ruff's hover is switched off so only pyright answers
`K`. A missing server produces a warning naming it — silence means they're
all running. **Formatting has no keybinding on purpose**: auto-format would
rewrite what an agent just produced and pollute the diff you're reviewing.
Use `gqip` for a paragraph or `:lua vim.lsp.buf.format()` when wanted.

### Completion (blink.cmp)

| Key | Action |
|---|---|
| `<C-j>` / `<C-k>` | Next / previous item |
| `<C-b>` / `<C-f>` | Scroll the docs popup |
| `<C-Space>` | Trigger completion |
| `<C-e>` | Dismiss |
| `<CR>` | Confirm |
| `<Tab>` / `<S-Tab>` | Jump between snippet placeholders |

Nothing is preselected, so `<CR>` never inserts something you didn't pick.

### Python REPL (iron.nvim → IPython)

| Key | Action |
|---|---|
| `` <leader>` `` | Show / hide the REPL (bottom split) |
| `<C-CR>` | Send the current line, or the visual selection |
| `<leader>rc{motion}` | Send a motion — `<leader>rcG` sends to end of file |
| `<leader>ri` / `<leader>rl` / `<leader>rq` | Interrupt / clear / quit |
| `<leader>r<CR>` | Send a bare newline |
| `<leader>rmc` / `<leader>rmv` | Mark a region by motion / visually |
| `<leader>rs` | Send the marked region |
| `<leader>rmd` | Remove the mark |

Only Python is configured. Code is sent via **bracketed paste**, which
matters: without it a blank line inside a function ends the block early.

### Markdown

| Key | Action |
|---|---|
| `<leader>mp` / `<leader>ms` / `<leader>mm` | Browser preview: start / stop / toggle |

In-buffer rendering (real headings, bullets, tables, concealed links) is
automatic for `.md` via render-markdown.nvim.

### Terminal mode

`<C-k>` / `<C-h>` / `<C-l>` escape back to your code windows. There is
deliberately no `<C-j>` — the REPL is the bottom split, so there's nothing
below it.

---

## The plugin set (17, pinned in lazy-lock.json)

| Plugin | Job |
|---|---|
| lazy.nvim | plugin manager; lazy-loads on events/commands/filetypes/keys |
| snacks.nvim | picker, explorer, lazygit float, notifier, bigfile, input, quickfile |
| gitsigns.nvim | hunk-level accept/reject — the review tool |
| diffview.nvim | changeset survey (dlyongemallo's maintained fork) |
| nvim-lspconfig | server *definitions* only; the framework is built into 0.12 |
| blink.cmp | completion (replaced nvim-cmp + six companions) |
| friendly-snippets | snippet library |
| nvim-treesitter | parser management; highlighting itself is native in 0.12 |
| iron.nvim | send code to a live IPython REPL |
| render-markdown.nvim | in-buffer markdown rendering |
| markdown-preview.nvim | browser preview |
| lualine.nvim | statusline, themed from the active palette's roles |
| mini.icons | filetype icons (also mocks nvim-web-devicons) |
| which-key.nvim | prefix discovery — the anti-rot mechanism |
| vim-surround | `ys`/`cs`/`ds` (designated successor: mini.surround) |
| autoclose.nvim | auto-close brackets/quotes |
| lazydev.nvim | real Neovim API types for lua_ls when editing this config |

## The invisible parts

- **Automatic reload** — when the agent rewrites a file you have open,
  Neovim notices and reloads it (`autoread` + `:checktime` autocmds). If you
  had unsaved edits in that same file you get the standard W12 prompt
  instead of losing them. A reload announces itself with a warning toast.
- **One-`:q` exit** — quitting the last ordinary editing window with
  auxiliary UI still open exits the app instead of stranding the explorer
  or a picker on its own. Saved hidden buffers ride along; unsaved ones
  still refuse with E37 (see *Windows, splits, tabs, buffers* above).
- **Permanent sign column** — gitsigns marks and diagnostics appearing
  never shift the text sideways.
- **System clipboard** — `y` and `p` use it directly, no `"+` prefix.
- **Loud failures** — this config deliberately avoids the
  `pcall(require, ...)` guard pattern that turns fixable startup errors
  into silent feature loss (the previous config had a dead LSP for months
  because of it). Missing servers warn by name.
- **Remote-plugin providers off** — no python3/ruby/perl/node provider
  hunting; saves ~65ms on the first Python buffer.
- **Startup order** — `mapleader` before lazy.nvim (specs read it at
  evaluation time), and the appearance sync before plugins so the first
  frame renders the right palette.

## In-editor docs

Installed to `~/.config/nvim/docs/` and reachable with `<leader>?` —
sourced in the repo under
[private_dot_config/nvim/docs/](../private_dot_config/nvim/docs/):

- [getting-started.md](../private_dot_config/nvim/docs/getting-started.md) —
  the agent-review workflow, walked end to end
- [keymaps.md](../private_dot_config/nvim/docs/keymaps.md) — the full
  cheatsheet (the tables above, in editor form)
- [tools.md](../private_dot_config/nvim/docs/tools.md) — every plugin and
  CLI tool, what it is and why it's here
- [tmux.md](../private_dot_config/nvim/docs/tmux.md) — the detach/reattach
  walkthrough
