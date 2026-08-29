# Tools

What's installed, why it's here, and how to use it. Grouped by job.

Key bindings are in [keymaps.md](keymaps.md), and
[getting-started.md](getting-started.md) walks the review workflow end to end.
This file is the "what is this thing and why do I have it" reference.

The shape of the setup: **17 Neovim plugins** (down from 34), **language
servers and CLI tools from Homebrew** rather than a second package manager
inside the editor, and **several things that used to be plugins now handled by
Neovim itself**.

---

## Reviewing changes

The reason this config exists. Most code here is written by an agent in an
adjacent terminal split; Neovim's job is to review it.

### gitsigns.nvim
Shows added/changed/removed marks in the sign column and lets you act on one
hunk at a time — preview it, **stage** it (accept), or **reset** it (throw it
away). Buffer-local: it attaches to whichever file you're looking at.

This is the accept/reject tool. Staging is the ledger — when you're done,
`git diff --cached` is exactly the set of changes you approved.

`<leader>gl` next hunk · `<leader>gp` preview · `<leader>gs` stage ·
`<leader>gr` reject

### diffview.nvim
Opens a dedicated tab: file list on the left, side-by-side old/new on the
right. Answers "what did it change, overall?" across every touched file — the
question gitsigns can't, because gitsigns only sees one buffer.

Stages whole **files** from its panel (`-`), not hunks. That's the right
granularity for "this whole file is fine" or "revert all of this".

We run [dlyongemallo's fork](https://github.com/dlyongemallo/diffview.nvim) —
upstream last shipped in Aug 2024, before Neovim 0.11 and 0.12.

`<leader>gd` open · `<Tab>` next file · `<leader>gq` close

### lazygit *(CLI, via snacks)*
Full-screen git TUI for everything else: committing, branching, rebasing,
resolving conflicts, browsing history. Opens in a float over Neovim and returns
you where you were. Press `?` inside it for its own keys.

`<leader>gg`

### git-delta *(CLI)*
Syntax-highlighted, side-by-side `git diff` output **in the terminal**. Nothing
to do with Neovim — diffview and gitsigns render their own diffs. This improves
`git diff`/`git show` in the shell and inside lazygit.

Configured by hand in `~/.gitconfig`; see the repo README.

---

## Getting around

### snacks.nvim
folke's utility collection. Replaced four separate plugins here (telescope,
telescope-fzf-native, nvim-tree, nvim-web-devicons). The parts in use:

- **picker** — fuzzy finder for files, grep, buffers, help, keymaps. Streams
  results, so the first row appears in ~20ms whether the repo has 4,000 files
  or 66,000.
- **explorer** — the file tree on `<leader>.`
- **lazygit** — the float above
- **notifier** — replaces `vim.notify`, so warnings appear as toasts instead of
  scrolling past in `:messages`
- **bigfile** — disables treesitter and syntax on very large files so they open
  instantly
- **input** — replaces Vim's `:` prompt for things like LSP rename
- **quickfile** — renders a file before plugins finish loading

`<leader>ff` files · `<leader>fs` grep · `<leader>fk` search all keymaps

### ripgrep, fd *(CLI)*
What the picker actually shells out to. `rg` does the grep, `fd` finds files.
Both respect `.gitignore`. Grep has no fallback — without `rg`, `<leader>fs`
stops working.

### fzf *(CLI)*
Shell fuzzy-finder. Not used by Neovim — the picker has its own matcher. Here
for terminal use.

---

## Editing

### vim-surround
`ysiw"` wraps a word in quotes, `cs"'` changes quotes to apostrophes, `ds"`
removes them. Unmaintained since 2024, but *finished* rather than rotten —
600 lines of Vimscript against APIs frozen since Vim 7.

### autoclose.nvim
Inserts the closing bracket/quote when you type the opening one.

### nvim-treesitter
Installs and updates language parsers. Neovim ships parsers for a handful of
languages but **not Python**, so this fills the gap and keeps parsers paired
with their highlight queries.

Note it no longer *does* the highlighting — Neovim 0.12 does that natively.
This just manages the parsers.

### mini.icons
Filetype icons for the picker, explorer, and statusline. Needs a Nerd Font in
your terminal or you get placeholder boxes.

---

## Language support

### nvim-lspconfig
Not a framework any more — Neovim 0.11+ has `vim.lsp.config`/`vim.lsp.enable`
built in. This is now just a package of ready-made server definitions (where
the binary is, which filetypes it handles), because core ships none.

### ruff *(CLI)* — Python linting and formatting
Astral's Rust-based linter, run as a language server. Catches unused imports,
undefined names, style issues. Replaced pylsp and its five sub-plugins.

Its hover is deliberately disabled so Pyright is the only thing that answers
`K` — otherwise two popups compete.

### Pyright *(CLI)* — Python types
Type checking and hover. Catches "you assigned a str to an int" and gives real
type information on hover. Runs alongside ruff: ruff owns lint, Pyright owns
types.

### lua-language-server, marksman *(CLI)*
Lua (for editing this config) and markdown.

### blink.cmp
Completion. Replaced seven plugins (nvim-cmp plus six companions). Sources are
LSP, file paths, snippets, and words from open buffers. The matcher is a Rust
binary — measured at 0.08ms for 100 candidates, 1.2ms for 10,000.

Nothing is preselected, so `<CR>` never inserts something you didn't choose.

### friendly-snippets
A snippet library. `<Tab>` jumps between placeholders.

### uv *(CLI)*
Astral's Python package and environment manager. Not used by Neovim; here
because it's how you manage the projects you edit.

---

## Python REPL

### iron.nvim
Sends code from a buffer to a live REPL in a split — the terminal equivalent of
a notebook. Select a block, `<C-CR>`, see the result, keep the session state.

`` <leader>` `` toggles the window; `<C-CR>` sends the line or selection.

> It sends via **bracketed paste**, which matters: without it, a blank line
> inside a function ends the block early and the function silently returns the
> wrong answer.

### ipython *(CLI)*
The REPL itself, run with `--no-autoindent`. If it isn't installed, iron falls
back to plain `python3` and warns once.

---

## Markdown

### render-markdown.nvim
Renders markdown **in the buffer** — real headings, bullets, checkboxes,
formatted tables, concealed link syntax. Turns note-taking in Neovim into
something readable.

### markdown-preview.nvim
Live preview in a browser, for when you want the real thing (math, diagrams,
proper tables). Ships a standalone binary; no Node needed.

`<leader>mp` start · `<leader>mm` toggle

---

## Appearance

### gruvbox-material
The colorscheme. Hard contrast, material palette.

### lualine.nvim
Statusline — mode, branch, diagnostics, position.

### which-key.nvim
Press `<Space>` and pause: it lists what's available under that prefix. This is
the **anti-rot mechanism** — the keymap set here is idiosyncratic, and a
hand-written table would drift out of date. which-key reads the live config, so
it can't be wrong.

---

## Infrastructure

### lazy.nvim
Plugin manager. Lazy-loads on events, commands, filetypes, and keys, so most of
the 17 plugins aren't loaded at startup. Writes `lazy-lock.json`, which pins
exact revisions — that file is committed, and it's what makes a second machine
reproduce this one and a bad update bisectable.

`:Lazy` to inspect · `:Lazy update` then re-add the lockfile to chezmoi

### chezmoi *(CLI)*
Manages this config as dotfiles. The source of truth is
`~/.local/share/chezmoi`; `~/.config/nvim` is a build artifact. Edit the source,
then `chezmoi apply`.

### tree-sitter CLI, node *(CLI)*
`tree-sitter` builds the parsers nvim-treesitter installs (needs ≥ 0.26.1).
`node` is fallback insurance for markdown-preview, which normally uses its own
binary.

### gh *(CLI)*
GitHub CLI. Load-bearing for setup: the dotfiles repo is private, so
`gh auth login` and `gh auth setup-git` are what let chezmoi clone it on a new
machine.

---

## Used to be plugins, now built into Neovim

Worth knowing, because the answer to "how do I comment a line" is no longer
"install a plugin".

| What | Was | Now |
|---|---|---|
| Commenting | Comment.nvim | `gcc` / `gc{motion}` — built in since 0.10 |
| LSP keymaps | lspsaga | `K`, `grn`, `gra`, `grr`, `gri`, `gO` — built in since 0.11 |
| LSP setup | lspconfig framework | `vim.lsp.config` / `vim.lsp.enable` |
| Syntax highlighting | nvim-treesitter modules | `vim.treesitter.start()` |
| Replace with register | vim-ReplaceWithRegister (`gr`) | `viwP` |
| Maximize window | vim-maximizer | 40 lines in `core/maximize.lua` |
| Server installation | Mason | Homebrew, via the Brewfile |
| Fuzzy find, file tree, icons | telescope + fzf-native + nvim-tree + devicons | snacks.nvim + mini.icons |

---

## The invisible parts

Things with no keybinding that make the workflow work.

**Automatic reload.** When the agent rewrites a file you have open, Neovim
notices and reloads it — no `:e`. If you had unsaved changes to that same file,
you get a prompt rather than losing them. (`core/autocmds.lua`)

**A permanent sign column.** Always visible, so gitsigns marks and diagnostics
appearing don't shift the text sideways.

**System clipboard.** `y` and `p` use it directly, no `"+` prefix.

**Loud failures.** If a language server is missing, you get a warning naming
it. This config deliberately avoids the `pcall(require, ...)` pattern that
turns errors into silence — the previous config had a dead LSP for months
because of exactly that.
