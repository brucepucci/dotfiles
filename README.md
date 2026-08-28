# dotfiles

Neovim config, managed with [chezmoi](https://chezmoi.io).

Neovim 0.12 · lazy.nvim · native LSP (ruff + pyright) · snacks.nvim · built for
reviewing code an AI agent wrote.

## New machine

```bash
# 1. Credentials FIRST. This repo is private, so chezmoi's clone needs them.
brew install chezmoi gh
gh auth login          # choose HTTPS
gh auth setup-git      # installs the git credential helper

# 2. Config
chezmoi init --apply brucepucci

# 3. Dependencies (language servers, ripgrep, lazygit, ipython, ...)
brew bundle --file="$(chezmoi source-path)/Brewfile"

# 4. Plugins, pinned to the exact revisions in lazy-lock.json
nvim --headless "+Lazy! restore" +qa
```

> **Step 1 is not optional.** `chezmoi init` clones over HTTPS and this repo is
> private, so without a credential helper it fails with
> `Authentication failed`. There is no SSH key registered on this account, so
> `--ssh` is not a fallback either.

> **Step 3 before opening Neovim.** Servers come from Homebrew, not Mason. If
> you launch `nvim` first you get a warning naming the missing servers — it is
> not silent, but it is avoidable.

If Homebrew is not installed yet, start with
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`.

**Requires Neovim 0.12+.** The config refuses to load below that and tells you
so, rather than half-working: `vim.lsp.config`, `vim.hl`, and nvim-treesitter's
`main` branch all need it.

## Manual setup — not managed by chezmoi

This repo is scoped to Neovim only. These are host-level and set up by hand.

**git-delta** as the pager. Improves `git diff` in the terminal and inside
lazygit; Neovim renders its own diffs and does not need it.

```bash
git config --global core.pager              delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate          true
git config --global delta.side-by-side      true
git config --global delta.line-numbers      true
git config --global delta.syntax-theme      'gruvbox-dark'
git config --global merge.conflictstyle     zdiff3
git config --global diff.colorMoved         default
```

**lazygit** — `~/.config/lazygit/config.yml`:

```yaml
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never
```

> If this section grows past ~10 commands, that is the signal to widen chezmoi's
> scope beyond Neovim — not a reason to widen it now.

## Editing the config

**Edit in the source directory, not in `~/.config/nvim`.** The target is a build
artifact; hand-editing it means the next `chezmoi apply` overwrites your work.

```bash
chezmoi cd                  # -> ~/.local/share/chezmoi
$EDITOR private_dot_config/nvim/lua/bruce/plugins/foo.lua
chezmoi diff                # review
chezmoi apply               # install
```

Adding a plugin means dropping a file into
`private_dot_config/nvim/lua/bruce/plugins/` — they are auto-imported, so no
`init.lua` edit is needed.

## Updating plugins

`lazy-lock.json` is committed on purpose: it is what makes a second machine
reproduce this one, and what makes a bad update bisectable.

```
:Lazy update
# test that things still work
chezmoi re-add ~/.config/nvim/lazy-lock.json
chezmoi cd && git commit -am "plugin update"
```

Skipping the `re-add` is not destructive — the lockfile just drifts, and
`chezmoi diff` will show it.

## Health check

Worth running quarterly. This is what would have caught the config rotting
before: the previous setup had a dead LSP for months and never said so.

```vim
:checkhealth
:Lazy check
```

## Rollback

The pre-migration config is kept at `~/.config/nvim-old` and runs side by side
without touching anything:

```bash
NVIM_APPNAME=nvim-old nvim
```

Full revert:

```bash
mv ~/.config/nvim ~/.config/nvim.new
mv ~/.config/nvim.pre-chezmoi ~/.config/nvim
mv ~/.local/share/nvim.pre-chezmoi ~/.local/share/nvim
mv ~/.local/state/nvim.pre-chezmoi ~/.local/state/nvim
```

Bad plugin update: `:Lazy restore`. Bad config change:
`chezmoi cd && git revert <sha> && chezmoi apply`.

The pre-migration history lives in the archived
[brucepucci/nvim](https://github.com/brucepucci/nvim) repo at tag
`pre-chezmoi-2026-08-27`.

## Docs

- [keymaps.md](private_dot_config/nvim/docs/keymaps.md) — cheatsheet, grouped by task
- [tools.md](private_dot_config/nvim/docs/tools.md) — what each tool is and why it is installed

Both are installed to `~/.config/nvim/docs/`. In Neovim, `<leader>?` opens the
cheatsheet and `<leader>fk` fuzzy-searches every live mapping. Press `<Space>`
and pause for which-key.
