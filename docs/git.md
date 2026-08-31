# Git tooling — git, delta, lazygit, gh

Four pieces, one job each. Neovim's git layer (gitsigns, diffview — the
review workflow) is documented in [nvim.md](nvim.md); this page is the
shell side.

**Managed files:**

| Source | Installs to | Job |
|---|---|---|
| `dot_gitconfig.tmpl` | `~/.gitconfig` | identity, delta pager, conflict style |
| `private_dot_config/git/ignore` | `~/.config/git/ignore` | global ignores |
| `private_dot_config/lazygit/config.yml` | `~/.config/lazygit/config.yml` | delta as lazygit's renderer |
| `dot_local/bin/executable_delta-theme.tmpl` | `~/.local/bin/delta-theme` | appearance-aware delta wrapper |

## git (`~/.gitconfig`)

Deliberately small:

- **Identity** — name/email, `init.defaultBranch = main`.
- **`core.pager = delta-theme`** — every `git diff`/`git show` in the shell
  goes through the wrapper below.
- **`merge.conflictstyle = zdiff3`** — conflicts show the common ancestor
  *and* both sides' original text, which makes agent-generated conflict
  soup dramatically easier to read than the default.
- **`push.autoSetupRemote = true`** — `git push` on a fresh branch just
  works; no `--set-upstream` dance.
- **`diff.colorMoved`** — moved blocks get their own coloring instead of
  looking like delete+add pairs.

## delta + the `delta-theme` wrapper

[delta](https://github.com/dandav/delta) renders side-by-side, navigable
diffs with line numbers. The interesting part is the wrapper:
`~/.local/bin/delta-theme` execs `delta` with the light/dark flag chosen
per invocation —

- `theme = "light"` or `"dark"` in `settings.toml` pins the mode;
- `theme = "system"` probes `defaults read -g AppleInterfaceStyle` (prints
  `Dark` and exits 0 in dark mode; the key doesn't exist in light mode),
  so a diff matches the OS appearance at the moment you run it — same
  signal Ghostty and nvim follow (see [theming.md](theming.md)).

And `syntax-theme = none`: bat syntax coloring is disabled, so diffs
render in the **terminal's own 16-color palette** — the active Ghostty
theme's colors, by construction, on any machine this config is applied to.
Deltas stay cohesive with whatever theme is running instead of carrying a
second, unrelated syntax scheme.

The `[delta]` block's `syntax-theme = none` also covers a bare `delta`
typed by hand (no wrapper) — that one stays dark, delta's default look.

## lazygit

`<leader>gg` from nvim opens it in a float (snacks); `lazygit` in the
shell runs it fullscreen. It handles everything the hunk workflow doesn't:
committing the staged ledger, branching, rebasing, conflict resolution,
history browsing. The managed config does two things:

- **diffs render through delta** (`delta-theme --paging=never`), so what
  you see in lazygit matches what `git diff` shows in the shell — one diff
  vocabulary everywhere;
- footer off, Nerd Fonts v3 declared.

All lazygit keybindings are its defaults — press `?` inside it for the
full list. The few worth muscle memory:

| Key (inside lazygit) | Action |
|---|---|
| `space` | Stage / unstage file or hunk |
| `c` | Commit |
| `P` | Push (`p` pull) |
| `b` | Branches panel |
| `]` / `[` | Next / previous panel tab |
| `?` | Full keybinding list |
| `q` | Quit |

## gh (GitHub CLI)

Load-bearing for setup rather than daily work: this dotfiles repo is
**private**, so `chezmoi init` needs credentials — `gh auth login`
(choose HTTPS) plus `gh auth setup-git` installs the git credential
helper that makes the clone work. No SSH key is registered on the account,
so `--ssh` is not a fallback. Beyond setup, `gh` is what opens PRs for
this repo's own workflow (see [developing.md](developing.md)).

## The workflow these pieces serve

The review loop lives in nvim (survey with diffview, accept/reject hunks
with gitsigns — staging is the ledger), and it ends in lazygit: everything
you approved is sitting staged, ready to commit. The shell pieces make the
same information readable outside the editor — a quick `git diff` in the
terminal matches what the editor showed, same colors, same style.
