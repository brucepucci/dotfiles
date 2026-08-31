---
name: runbook
description: Verification runbook for the chezmoi dotfiles repo at ~/.local/share/chezmoi (github.com/brucepucci/dotfiles). Run after ANY change to that repo's files, and again before pushing or opening a PR. Covers the tier-1 smoke test, chezmoi diff/apply, headless checkhealth, the LSP attach check, and the plugin lockfile re-add + commit steps.
---

# dotfiles repo runbook

This mirrors AGENTS.md in the repo root ("Verifying a change", "After
changing plugins") — that file is the source of truth, and the smoke test
fails if the command lines here drift from it. Edit both together.

Work from the source repo, never from the installed targets under `$HOME`:

```bash
chezmoi cd        # -> ~/.local/share/chezmoi
```

## 1. verify — after every change

```bash
scripts/smoke-test.sh
chezmoi diff && chezmoi apply
nvim --headless "+checkhealth" "+w! /tmp/h.txt" +qa && grep -E 'ERROR|WARNING' /tmp/h.txt
```

For shell or LSP changes, confirm clients actually attach — this config
exists partly because they silently did not. Run from a directory holding
a python file (or point at one):

```bash
nvim --headless some.py '+lua vim.wait(6000, function() return #vim.lsp.get_clients({bufnr=0}) >= 2 end); for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do print(c.name) end' +qa
```

Expected: two client names printed (ruff, pyright). Known checkhealth
noise, pre-existing and fine: snacks reports missing magick/ghostscript/
tectonic and "no kitty graphics protocol" for image modules this config
does not use. Anything else in the grep output belongs to the change.

## 2. plugins — after any plugin change

```
:Lazy sync
```

`:Lazy sync` runs inside nvim. Then pick up the lockfile and commit it:

```bash
chezmoi re-add ~/.config/nvim/lazy-lock.json
```

The lockfile must be committed — it is the reproducibility guarantee and
makes a bad update bisectable via
`git log -p -- private_dot_config/nvim/lazy-lock.json`.

## 3. themes

Appearance is edited only via `settings.toml` at the repo root; the
resolver runs at apply time and nothing is cached — see `docs/theming.md`.
Note `chezmoi re-add` skips template-sourced files: pi's own settings
bumps (`defaultModel` etc., saved via `/model` + Ctrl+S) fold into
`dot_pi/agent/settings.json.tmpl` by hand — see `docs/developing.md`,
"pi self-bumps".

## Before opening a PR

Branch, commit, push, `gh pr create`. CI runs the same tier-1 smoke test
as step 1 and must be green. The maintainer-side details (test pyramid,
rollback, successors) are in `docs/developing.md`.
