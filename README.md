# dotfiles

Neovim config, managed with [chezmoi](https://chezmoi.io).

Neovim 0.12 · lazy.nvim · native LSP (ruff + pyright) · snacks.nvim · built for
reviewing code an AI agent wrote.

## New machine

```bash
brew install chezmoi
chezmoi init --apply brucepucci
brew bundle --file="$(chezmoi source-path)/Brewfile"
nvim --headless "+Lazy! restore" +qa
```

`Lazy! restore` installs the exact plugin revisions in `lazy-lock.json` rather
than whatever HEAD happens to be that day.

If Homebrew is not installed yet, start with
`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply brucepucci`.

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

## Keymaps

See [keymaps.md](private_dot_config/nvim/docs/keymaps.md), or just press
`<Space>` in Neovim and read what which-key offers.
