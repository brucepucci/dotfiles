# Getting started

This config exists for one job: **reviewing code that an AI agent wrote.**

Most of the typing happens elsewhere now — the pi coding agent in one terminal
split, Neovim in the other. So the editor's job has shifted from *writing* to
*reading a diff and deciding what to keep*. Everything below is built around
that.

If you read nothing else, read [The loop](#the-loop).

---

## Setup

Ghostty, split in two:

| Key | Does |
|---|---|
| `⌘D` | Split right |
| `⌘⇧D` | Split down |
| `⌘[` / `⌘]` | Move between splits |

pi on one side, `nvim` on the other. That's the whole arrangement — no tmux
needed for this loop. Wrap the day's work in a tmux session when it should
survive leaving the desk: [tmux.md](tmux.md).

**You do not need to reload files.** When the agent rewrites something you have
open, Neovim notices and reloads it. If you happened to have unsaved edits in
that same file, you get a prompt instead of losing them.

---

## The mental model

Two tools, and the difference between them is the thing to internalise.

**diffview** answers *"what did it change, overall?"* — every touched file in
one view, side by side, old against new.

**gitsigns** answers *"do I want this particular change?"* — one hunk at a
time, in the normal buffer, where you can also just fix it by hand.

And the key idea underneath both:

> **Staging is your accept/reject ledger.**
> Stage a hunk → you've approved it. Reset a hunk → it's gone from disk.
> When you're done, `git diff --cached` is precisely the set you approved,
> and that's what you commit.

That's why hunk-level staging matters. An agent gets nine things right and one
thing wrong, and you want to keep the nine.

---

## The loop

**1. See what it did**

```
<leader>gd          open the changeset
<Tab>               next file
-                   stage a whole file, if it's obviously all fine
<leader>gq          close
```

Read it all before deciding anything. `-` on a file in the left panel accepts
the entire file at once — worth using, since plenty of an agent's edits are
wholesale fine or wholesale wrong.

**2. Decide, hunk by hunk**

Back in the normal buffer:

```
<leader>gl          next hunk
<leader>gh          previous hunk
<leader>gp          preview this hunk
<leader>gs          stage it     — accept
<leader>gr          reset it     — reject, discard from disk
```

`<leader>gs` and `<leader>gr` also work on a **visual selection**, so you can
accept half a hunk. Select the lines you want, `<leader>gs`, then `<leader>gr`
the rest.

Changed your mind: `<leader>gu` undoes the last stage.

**3. Check it didn't break anything**

```
]d                  next diagnostic
[d                  previous diagnostic
<leader>d           show the full message
```

ruff and Pyright run continuously, so type errors and undefined names the agent
introduced show up in the gutter without you asking. Worth a pass before
committing.

**4. Commit**

```
<leader>gg          lazygit
```

Everything you staged is sitting there ready. Commit it, and anything you
rejected is already gone.

---

## One thing that will confuse you

**Hunk keys don't work inside diffview's file panel.** They're buffer-local to
real files, and the panel isn't one. Press `<leader>gl` there and nothing
happens.

That's deliberate — the loop above closes diffview before staging. If you'd
rather stay inside it, press `<Tab>` to open a file and then `<C-w>l` to step
into the right-hand pane, which *is* your real working file. The hunk keys work
from there.

---

## Everything git, in one place

`<leader>g` is the whole domain — one letter to remember. Lowercase acts on
this hunk or file; capital widens the scope.

| Key | | Key | |
|---|---|---|---|
| `<leader>gl` / `gh` | next / prev hunk | `<leader>gd` | review changeset |
| `<leader>gs` / `gS` | stage hunk / buffer | `<leader>gD` | review staged only |
| `<leader>gr` / `gR` | reset hunk / buffer | `<leader>gm` | branch vs `origin/main` |
| `<leader>gu` | undo stage | `<leader>gf` / `gF` | file / repo history |
| `<leader>gp` / `gP` | preview inline / float | `<leader>gq` | close diffview |
| `<leader>gb` / `gB` | blame line / toggle | `<leader>gg` | lazygit |

`<leader>gm` is the one to use when an agent has been working on a branch for a
while — it shows the whole thing the way a pull request would.

---

## The rest of it

Enough to be productive; the details are in [keymaps.md](keymaps.md).

**Moving around**

| Key | |
|---|---|
| `<leader>ff` | find files |
| `<leader>fs` | grep across the project |
| `<leader>fb` | open buffers |
| `<leader>.` | file explorer |
| `<C-h/j/k/l>` | move between windows |

**Understanding code** — these are Neovim built-ins, live whenever a language
server is attached:

| Key | |
|---|---|
| `K` | what is this |
| `grr` | find references |
| `grn` | rename everywhere |
| `gra` | code action |
| `<C-]>` | go to definition |

Useful when reviewing: `grr` on a function the agent changed tells you
everything that calls it.

**Python REPL** — send code to a live IPython session:

| Key | |
|---|---|
| `` <leader>` `` | show / hide the REPL |
| `<C-CR>` | send this line, or the selection |
| `<leader>rc{motion}` | send a motion |

**Markdown** — renders in the buffer automatically; `<leader>mp` opens a
browser preview.

**Editing** — worth knowing these are built in now, not plugins: `gcc` comments
a line, `gc` comments a selection, and `viwP` replaces a word with what you
yanked without clobbering your register.

---

## When you forget something

| | |
|---|---|
| Press `<Space>` and wait | which-key lists everything under that prefix |
| `<leader>fk` | search every mapping and jump to its definition |
| `<leader>?` | the cheatsheet |
| `g?` inside diffview | diffview's own keys |
| `?` inside lazygit or a picker | that tool's own keys |

which-key and `<leader>fk` read the live config, so they can't be out of date.
Trust them over any document, including this one.

---

## If something goes wrong

**Rejected a hunk you wanted.** `<leader>gu` undoes a stage. A reset is a real
discard, though — recover it from the agent's context or `git reflog` if it was
ever committed.

**Neovim looks broken after an update.** `:Lazy restore` puts every plugin back
to the pinned revision in `lazy-lock.json`.

**Something is genuinely wrong with the config.** `:checkhealth`. The previous
version of this setup had a dead LSP for months without complaining, so this
one is built to fail loudly — if a language server is missing, it says so by
name.

**You want the old config back.** `NVIM_APPNAME=nvim-old nvim` runs the
pre-migration setup side by side, changing nothing.

---

## Next

- [keymaps.md](keymaps.md) — the full cheatsheet, grouped by task
- [tools.md](tools.md) — every plugin and CLI tool, what it is and why it's here
