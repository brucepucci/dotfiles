# Developing this repo

The maintainer's guide: how to change things, how to verify, and the
rules that keep the whole thing coherent. Written to be re-readable after
a long absence — err on the side of re-explaining. If you're looking for
*what* is managed rather than *how to maintain it*, start at the
[README](../README.md) and the per-tool docs.

`AGENTS.md` at the repo root is the condensed version of this file's
rules, written for coding agents (pi, Claude Code, anything that reads the
cross-agent convention). The two should not drift apart; update both.

## The golden rules

1. **The source of truth is this repo.** Everything under `$HOME` —
   `~/.config/nvim`, `~/.zshrc`, all of it — is a build artifact. Edit the
   source, then `chezmoi apply`. Never hand-edit a target; apply will
   overwrite your work.
2. **macOS only.** One install target: a Mac with Homebrew and zsh. The
   one remote story is being SSH'd *into* the Mac. No cross-platform
   branches, no Linux CI, no distro caveats — if a change only makes sense
   on another OS, it doesn't belong here.
3. **Loud failures.** No `pcall(require, ...)` guards around plugin
   requires — that pattern turned a fixable startup error into months of
   silent, dead LSP once already. `pcall` is fine where failure is
   genuinely expected (`vim.treesitter.start` on a filetype with no
   parser).
4. **One package manager for binaries: Homebrew.** Language servers come
   from the Brewfile, never Mason. Everything installable is visible in
   one reviewable file.
5. **Prefer built-ins.** Neovim 0.12 already provides commenting,
   LSP keymaps, and the LSP framework. Don't add plugins for those. The
   "used to be plugins" table in the in-editor tools doc
   (`private_dot_config/nvim/docs/tools.md`) is the reminder.
6. **Colors: no hardcoded hex or theme name in a managed file, ever.**
   Render from the resolver or read the generated module. See
   [theming.md](theming.md) — the smoke test enforces this.
7. **Secrets never go in this repo.** They live in `~/.zsh/secrets.zsh`.
8. **The lockfile is committed.** `lazy-lock.json` is the reproducibility
   guarantee and makes a bad plugin update bisectable.
9. **Keymaps are load-bearing muscle memory.** Don't "tidy" them. Notable
   intentional quirks: the file explorer is `<leader>.` (a leader chord,
   like every other action); `<C-h/j/k/l>` are uniformly window movement,
   never actions; terminal mode has no `<C-j>` because the REPL is the
   bottom split.

## The daily loop

```bash
chezmoi cd                 # -> ~/.local/share/chezmoi (this repo)
$EDITOR <source file>      # e.g. private_dot_config/nvim/lua/bruce/plugins/foo.lua
chezmoi diff               # review what apply would change
chezmoi apply              # install
scripts/smoke-test.sh      # ~1s; after EVERY change
```

`chezmoi doctor` diagnoses chezmoi itself when something's odd;
`chezmoi managed` lists what's tracked.

## chezmoi source naming (the part that bites)

- `dot_foo` → `~/.foo`. Any dotfile **nested inside a managed directory**
  must use the prefix — chezmoi silently skips source entries starting
  with a literal `.` (this is why
  `private_dot_config/zsh-ghostty/dot_zshenv` is spelled that way).
- `private_foo` → mode-0700 `~/.foo`. `private_dot_config` exists because
  `~/.config` is 0700; chezmoi preserves that.
- `executable_foo` → the target gets the executable bit
  (`dot_local/bin/executable_delta-theme.tmpl` → `~/.local/bin/delta-theme`).
- `foo.tmpl` → rendered through the template engine at apply time;
  everything else is copied verbatim.
- **`.chezmoiignore` is NOT gitignore**: patterns match the *target* path,
  anchored at the destination root, doublestar style. `README.md` there
  means `~/README.md`, and `docs/` means `~/docs` — that's why the repo's
  own docs folder never lands in `$HOME`. Files never added via
  `chezmoi add` don't need entries; the ignore list exists so an
  accidental `chezmoi add ~` can't sweep in secrets, history, and pi
  transcripts (all listed there).
- `.chezmoidata`/`.chezmoiignore` aside, no settings travel through
  chezmoi's data machinery: templates call
  `scripts/theme.py` via the `output` function instead, which is
  why `settings.toml` can sit at the repo root, editable, and never be
  installed.

## Verifying changes: the test pyramid

**Tier 1 — `scripts/smoke-test.sh` (~1s, no VM, runs in CI on every push
and PR).** Applies the repo into a pristine throwaway HOME and exercises
the result the way real sessions do. It covers:

- from-scratch apply; fresh login-shell behavior (prompt, shared HISTFILE,
  brew PATH, aliases, EDITOR fallback when nvim is absent)
- the clipboard helpers (`clipcopy`/`clippaste`) — byte-exact round-trip
  through fake pbcopy/pbpaste shims, with the usage-error, directory,
  multi-argument, missing-file, and `--help` branches all exercised
- the legacy ZDOTDIR guard repairing a pre-unification Ghostty window
- the SSH prompt segment; history shared across shells
- secrets staying out; Ghostty config containing no shell settings
- the prompt's git-marker spacing and blank-line rules
- light/dark mode wiring (Ghostty theme line, nvim mode module, the
  delta-theme wrapper exercised with fake `defaults`/`delta` shims)
- the color system end to end (names resolve from the committed mirror,
  no orphan hexes, roles verbatim, pi rides the indexed slots)
- the tmux config's shape (extended keys, clipboard, truecolor — file
  shape only, no tmux binary needed)
- the pi→tmux wrapper with fake tmux+pi shims (creates named sessions,
  never attaches, probe fallbacks, all the fall-through guards)
- `tmux_wrap` on/off rendering (second apply against a flipped settings
  file via `DOTFILES_SETTINGS_FILE`)
- the shell integrations' shape (fzf/autosuggestions/syntax-highlighting
  source after compinit; ghost text is indexed color 8;
  zsh-syntax-highlighting sourced LAST)
- sparse custom themes emitting role hexes; pinned-theme mode rendering
  `PI_THEME_PINNED`
- the runbook skill: generated from AGENTS.md at apply time (drift-proof
  by construction; apply itself fails if the sections vanish), with a
  closed frontmatter block obeying pi's validation rules and the
  load-bearing command lines intact in both files
- the provider-usage pi extension: installed into the scratch HOME, with
  its unit harness (`scripts/test-provider-usage.mjs`, jiti-loaded like
  pi loads it) covering the row format through pi's own status
  sanitizer, quota-window parsing, and the fetch/lifecycle behavior
- the title-screen pi extension: same treatment
  (`scripts/test-title-screen.mjs`) — art geometry (small fixed indent,
  width independent, the section-header role), caption contents, and
  startup gating against a fake pi — plus the orphan-hex scan now
  covers both pi extensions (no hardcoded colors)
- the nvim exit rule, headlessly: `:q` from the last session-holding
  window closes disposable UI so one quit exits — while terminal splits
  (live jobs asserted alive), other tabs, `:q!`, unsaved buffers, and
  quits issued from aux UI keep stock Neovim behavior. Fake `nofile`
  splits stand in for the explorer, so nothing couples to Snacks'
  layout; the harness provably fails on a failed assert (the marker is
  the assertion chunk's last statement) and on unexpected stderr —
  skipped where nvim is absent, like the EDITOR fallback

`--nvim` additionally restores plugins in the throwaway HOME (~2 min) for
plugin-level checks. CI runs tier 1 on `macos-latest` with no Ghostty
installed — the theme mirror is committed in the repo, so a green run
there is the standing proof that apply needs no Ghostty. (The resolver's
palette input is the mirror and nothing else — tier 1 guards that
behaviorally by resolving with themes/ absent — but the runner still has
network, so "reads no network at apply time" is a property of the code,
not something CI enforces.)

**Tier 2 — a real macOS VM, for big changes** (new-machine runs, GUI apps,
`brew bundle` itself):

```bash
brew install tart
tart clone ghcr.io/cirruslabs/macos-sequoia:latest dotfiles-test
tart run dotfiles-test             # Cirrus images ship ssh admin/admin
ssh admin@$(tart ip dotfiles-test) # run the README's new-machine steps inside
tart delete dotfiles-test
```

**Tier 3 — in-editor checks**, for nvim changes:

```bash
nvim --headless "+checkhealth" "+w! /tmp/h.txt" +qa && grep -E 'ERROR|WARNING' /tmp/h.txt
# and, for LSP changes, confirm clients actually attach (the silent
# failure this config was rebuilt to prevent):
nvim --headless some.py '+lua vim.wait(6000, function() return #vim.lsp.get_clients({bufnr=0}) >= 2 end); for _,c in ipairs(vim.lsp.get_clients({bufnr=0})) do print(c.name) end' +qa
```

Expected noise under `:checkhealth`: snacks runs every module's health
check even when disabled, so magick/ghostscript/tectonic complaints and
"no kitty graphics protocol" are about image rendering we don't do.

## Common tasks

### Add an nvim plugin
Drop a file in `private_dot_config/nvim/lua/bruce/plugins/` returning a
lazy.nvim spec — they're auto-imported; no `init.lua` edit. Put the
plugin's own keymaps in its spec (keeps lazy-load triggers accurate).
Then:

```
:Lazy sync
chezmoi re-add ~/.config/nvim/lazy-lock.json   # pick up the lockfile
```

Commit the lockfile. (First plugin run on a machine: `nvim --headless
"+Lazy! restore" +qa`.)

### Update plugins
`:Lazy update`, test, `chezmoi re-add ~/.config/nvim/lazy-lock.json`,
commit. Skipping the re-add isn't destructive — the lockfile drifts and
`chezmoi diff` shows it. Bad update? `:Lazy restore` puts everything back
to the pinned revisions.

### Add an LSP server
1. Add the formula to `Brewfile` (with a comment saying what it's for).
2. Add the server name to the `vim.lsp.enable({...})` list in
   `lua/bruce/plugins/lsp.lua`, plus an entry in the `exes` table there
   (that's the missing-binary warning).
3. If it needs settings, add a `vim.lsp.config("<name>", {...})` block
   above.
4. Run the tier-3 attach check — silence means running.

### Add any other dependency
Add it to `Brewfile` under the right section with a comment. The Brewfile
is documentation as much as machinery — someone (you, later) should be
able to read why each line exists.

### Change how things look
Edit `settings.toml` at the repo root (theme names are the file names of
the committed mirror in `themes/` — browse
[iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)'
README gallery; `scripts/themes-sync.sh` refreshes the mirror), then
`chezmoi diff && chezmoi apply`. Never edit a generated
file — theming.md lists which files are artifacts.

### Add a secret
Add a variable to `~/.zsh/secrets.zsh` (unmanaged; template:
`private_dot_zsh/secrets.example.zsh`, so update the example with a
placeholder). Nothing else — `~/.zshrc` already sources the file. Rotate
the real file on every machine. Note the tmux gotcha: panes inherit the
tmux *server's* environment, so after rotating keys run
`tmux kill-server` (ends live conversations) and start fresh.

### pi self-bumps
pi rewrites `~/.pi/agent/settings.json` (`lastChangelogVersion`, and
whatever you saved via `/model` + Ctrl+S). The file is template-sourced,
so `chezmoi re-add` **skips** it — fold changes in by hand:

```bash
chezmoi cd
$EDITOR dot_pi/agent/settings.json.tmpl   # port defaultModel etc.
chezmoi diff && chezmoi apply
```

### Edit shell config
Edit `dot_zshrc.tmpl` / `dot_zprofile` / `ps1.zsh`, apply, and run the
smoke test (it asserts the structural invariants: integrations after
compinit, syntax-highlighting last, indexed colors). New interactive-shell
windows pick it up; existing ones need a restart.

### Edit the runbook / the pi skill
The verification runbook lives in AGENTS.md ("Verifying a change",
"After changing plugins"). Edit it there; `chezmoi apply` regenerates
`~/.pi/agent/skills/runbook/SKILL.md` from those sections — never edit
the skill, and don't rename the AGENTS.md headings (apply fails loudly,
by design). The smoke test checks the render and the frontmatter.

### Keep the docs honest
- Repo docs (`docs/`) — this folder; ignored by chezmoi; edit freely.
- In-editor docs (`private_dot_config/nvim/docs/`) — installed to
  `~/.config/nvim/docs/`, reachable via `<leader>?`. Edit the **source**
  copy and follow the normal loop: `chezmoi diff && chezmoi apply`. Do
  **not** `chezmoi re-add` these: re-add copies the *target* over the
  source, so run against an un-applied source edit it silently reverts
  the edit. `re-add` is only for files a tool rewrites in the target
  (`lazy-lock.json`); source-edited files get `apply`.
- The nvim docs' own rule: which-key and `<leader>fk` read the live
  config and are the source of truth over any written table. Same spirit
  applies here — when docs and code disagree, fix the docs (or the code),
  deliberately.

## The color system, contributor edition

The one-look-everywhere property is enforced, not hoped for. For details
see [theming.md](theming.md). Contributor-facing summary:

- `settings.toml` is the only appearance input; `scripts/theme.py`
  resolves names against the committed mirror in `themes/` at apply time
  (rooted in iTerm2-Color-Schemes, refreshed by
  `scripts/themes-sync.sh`) — no network, no Ghostty install needed.
  New themes work by syncing the mirror and typing their name.
- New surfaces follow the SSH rule: render in terminal-indexed colors
  (0–15) so the *viewing* terminal resolves them; the xterm cube (16–255)
  only for shades every terminal renders identically; live hexes only
  where the cube has no honest match (and the smoke test must learn about
  them).
- The smoke test's color-system step is the drift guard. If you add a
  rendered surface, extend it.

## Designated successors

If one of these breaks, the intended replacement is already decided:

| Current | Successor | Note |
|---|---|---|
| `tpope/vim-surround` | `mini.surround` | different keys: `gsa`/`gsd`/`gsr` |
| `markdown-preview.nvim` | `toppair/peek.nvim` | Deno-based |
| `blink.cmp` | built-in `vim.o.autocomplete` | 0.12+; loses docs window & snippet ranking |
| lazy.nvim | `vim.pack` | built-in, own lockfile; blocked on lazy-loading support |
| `dlyongemallo/diffview.nvim` | `sindrets/diffview.nvim` | the fork exists only because upstream went quiet in 2024 |

## Health check & rollback

The cadence summary (what to do quarterly / after updates / as needed)
lives in the README's "Maintenance" section; this is the long-form
version.

Quarterly: `:checkhealth`, `:Lazy check` in nvim. This is what would have
caught the old config's dead LSP.

- Bad plugin update → `:Lazy restore`
- Bad config change → `git revert <sha>` in this repo, then `chezmoi apply`
- The pre-migration config still runs side by side:
  `NVIM_APPNAME=nvim-old nvim` (full-revert paths are in the README's
  Rollback section)

## The repo's own workflow

Changes go through branches and PRs — this repo is its own best customer:

```bash
chezmoi cd
git checkout -b <topic>
# ... change, apply, smoke-test ...
git add -p && git commit
git push -u origin <topic>
gh pr create --fill
```

pi does the heavy lifting inside a wrapped session (see [pi.md](pi.md));
the review loop it built this repo for applies to the repo itself: stage
the hunks you're keeping, read the diff, then merge. CI must be green —
it's the same tier-1 smoke test you ran locally.
