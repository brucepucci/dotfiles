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
4. **Homebrew where available.** Language servers come from the Brewfile,
   never Mason. Herdr desktop uses the `herdr-app` cask; core has no formula
   and requires the app's explicit first-launch **Install it for me** step.
   Ongoing app/core updates use the vendor UI (the cask auto-updates).
   Apply never runs a backend installer. See [herdr.md](herdr.md).
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
10. **Terminal environment, not fleet provisioning.** This repo owns shared
    outbound SSH aliases and offline config tests. The private
    [ssh-setup runbook](https://github.com/brucepucci/ssh-setup) owns infrastructure
    onboarding, network/security expectations, recovery, and live verification
    records. Do not duplicate those procedures here or make apply enable servers,
    grant access, distribute credentials, or change firewall/router/tailnet policy.
    See [ssh.md](ssh.md) for the integration boundary; apply must not depend on
    the private repo.

## The daily loop

```bash
chezmoi cd                 # -> ~/.local/share/chezmoi (this repo)
$EDITOR <source file>      # e.g. private_dot_config/nvim/lua/bruce/plugins/foo.lua
chezmoi diff               # review what apply would change
chezmoi apply              # install
scripts/smoke-test.sh      # ~1s; after EVERY change
```

`chezmoi doctor` diagnoses chezmoi itself when something's odd;
`chezmoi managed` lists what's tracked. `chezmoi cd` uses the configured
source (normally `~/.local/share/chezmoi`), not necessarily your current
checkout. For a separate checkout such as `/Users/bp/gh/dotfiles`, use
`chezmoi --source=/Users/bp/gh/dotfiles diff` and the matching `apply`;
run its local scripts from that checkout. No global source change is needed.

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
- the shared Mac SSH address book: installed file permissions, aliases,
  destination users, canonical host-key names, and daily/emergency identity
  separation (offline `ssh -G` checks, no credentials or network required);
  recursive and explicit imports reject custom-named private keys and nested
  backups while still managing only `hosts.conf` (disposable test key)
- secrets staying out; Ghostty config containing no shell settings but
  carrying the ssh-terminfo features line (see [ghostty.md](ghostty.md))
- the prompt's git-marker spacing and blank-line rules
- light/dark mode wiring (Ghostty theme line, nvim mode module, the
  delta-theme wrapper exercised with fake `defaults`/`delta` shims)
- the color system end to end (names resolve from the committed mirror,
  no orphan hexes, roles verbatim, pi rides the indexed slots)
- the tmux config's shape (extended keys, clipboard, truecolor — file
  shape only, no tmux binary needed)
- the pi→tmux wrapper with fake tmux+pi shims (creates named sessions,
  never attaches, probe fallbacks, all the fall-through guards — including
  bare pi inside Herdr desktop/core terminals (nonempty `HC_TERMINAL_ID`),
  even under `PI_TMUX_WRAP=force`; an empty marker still wraps, bypass
  preserves pi arguments, and legacy `HERDR_ENV` no longer bypasses)
- Herdr desktop migration: the Brewfile selects cask `herdr-app`, not the
  legacy formula; no `herdr()` wrapper remains; fresh and upgrade applies
  render telemetry off and app appearance/theme selection, remove the exact
  legacy config/Pi reporter, and preserve app keys, runtime/layout state,
  unrelated themes, and core configuration. Imports allowlist only settings
  and the two generated themes, never the whole themes directory.
- Herdr theme rendering: system mode plus both pins; exact background,
  foreground, cursor, selection background, and ANSI 0–15 parity with
  Ghostty; custom/sparse themes and theme-swap regeneration.
  Offline tests do not prove interactive core onboarding or live OSC 7501
  reporting; verify those manually in the app
- `tmux_wrap` on/off rendering (second apply against a flipped settings
  file via `DOTFILES_SETTINGS_FILE`)
- the shell integrations' shape (fzf/autosuggestions/syntax-highlighting
  source after compinit; ghost text is indexed color 8;
  zsh-syntax-highlighting sourced LAST)
- sparse custom themes emitting role hexes; pinned-theme mode rendering
  `PI_THEME_PINNED`
- the project-local chezmoi-runbook skill: valid frontmatter, working links
  to AGENTS.md's verification/plugin sections and this maintainer guide,
  no duplicated command blocks, and no installation under HOME; when pi is
  installed, its resource loader proves discovery from the repo and its
  subdirectories, exclusion in unrelated projects, and project-trust gating
- local skill selection: a disposable checkout proves auto-discovery symlinks,
  additions/removals/renames, dangling-link cleanup, live edits, empty selection,
  cache-settings migration, dry-run safety, and failure-before-mutation for invalid
  inputs or unrelated-name collisions; unrelated skills and locks survive, public
  Git/npx calls are rejected, and no payloads are copied;
  Pi's real resource loader checks collision-free selected/unselected global
  discovery alongside the local runbook
- retirement of the experimental global grilling copies, former global
  runbook skill, code review skill, and
  package-update prompt extension: apply removes installed copies on upgrades
  without touching unrelated user skills or extensions or the local runbook
- the provider-usage pi extension: installed into the scratch HOME, with
  its unit harness (`scripts/test-provider-usage.mjs`, jiti-loaded like
  pi loads it) covering the row format through pi's own status
  sanitizer, quota-window parsing, and the fetch/lifecycle behavior
- the title-screen pi extension: same treatment
  (`scripts/test-title-screen.mjs`) — art geometry (small fixed indent,
  compact narrow fallback, width independence, the section-header role),
  caption variants pi can actually produce, re-install on every
  session_start reason (pi resets extension UI on each rebind), and the
  tui-only command guards — plus the orphan-hex scan now covers both pi
  extensions (no hardcoded colors)
- the nvim exit rule, headlessly: `:q` from the last session-holding
  window closes disposable UI so one quit exits — while terminal splits
  (live jobs asserted alive), other tabs, `:q!`, unsaved buffers, and
  quits issued from aux UI keep stock Neovim behavior. Fake `nofile`
  splits stand in for the explorer, so nothing couples to Snacks'
  layout; the harness provably fails on a failed assert (the marker is
  the assertion chunk's last statement) and on unexpected stderr —
  skipped where nvim is absent, like the EDITOR fallback

`--nvim` additionally restores plugins in the throwaway HOME (~2 min) and
requires the Homebrew `rumdl` binary (0.3.4+ for link completion/navigation).
Its real-LSP regression tests (`scripts/test-markdown-lsp.lua`) accept file and
heading completion edits/snippets, resolve accepted paths on disk relative to
the source document, and navigate existing `../` heading links in both
directions (definition and references). Inline-link navigation is exercised
across the link span, with nested display text, Unicode offsets, and
angle-bracket/relative destinations. Full reference-label completion accepts
real edits for typed/empty labels with and without a closing bracket, observes
unsaved definitions, excludes code contexts and fenced/code-shaped definition
decoys, and rejects invalid multiline edit ranges. These requests go through
the real client (including the rumdl-only compatibility integration), not a
helper's private parsing API. Lowercase and title-cased heading completions are compared with the actual slug function in the pinned preview
bundle, not the language server's own navigation as an anchor oracle. This
checks ordinary unique headings, not punctuation/duplicate-heading parity or
an interactive browser session. Legacy-root fixtures open a non-Git
`.marksman.toml` workspace from an unrelated directory and verify that a
nested Git repository does not hide inbound references from its outer workspace.
Plugin restore is explicitly network-enabled and bypasses the skill tests'
Git shim only in its Neovim subprocesses; the normal tier stays offline for
skills. No developer plugins or server settings are copied into the test HOME.
CI runs tier 1 without `--nvim` on `macos-latest` with no Ghostty
installed — the theme mirror is committed in the repo, so a green run
there is the standing proof that apply needs no Ghostty. (The resolver's
palette input is the mirror and nothing else — tier 1 guards that
behaviorally by resolving with themes/ absent — but the runner still has
network, so "the theme resolver reads no network" is a property of the code,
not something CI enforces. Skill configuration reads only a disposable local
checkout; public Git and npx invocations fail the test.)

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
"no kitty graphics protocol" are about image rendering we don't do. The
`vim.ui.input` / `vim.ui.select` errors in a headless run are also expected:
Snacks installs those hooks on `UIEnter`, which headless startup does not fire.
Both hooks match Snacks after that event. Disabled-module warnings alone are
not failures of the enabled editor features.

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

### Herdr desktop/core changes

Use [herdr.md](herdr.md) for installation and legacy TUI migration. Manage
`~/.config/herdr-app/settings.json` (telemetry off + appearance/theme pair)
and exactly `themes/dotfiles-{light,dark}.json`. Both native themes use the
same resolved terminal palettes as Ghostty, with Herdr deriving the UI.
`settings.toml` remains the single appearance input. Keep app keys, other
themes, core config, and runtime/layout state unmanaged; never allowlist the
whole themes directory. GUI preference writes are replaced by apply; fold
preferences worth keeping into the template deliberately. Layout-local
theme/color overrides can take precedence: use the default main layout to
follow repo themes, preserving geometry and runtime state. Core's default
login shell is sufficient. Pi 1.5 reports OSC 7501 natively; tmux
blocks its handshake and reports, so nonempty `HC_TERMINAL_ID` bypasses
wrapping even under `PI_TMUX_WRAP=force`. No legacy state extension is needed.

Migration stops the old daemon only after the user has checked and finished
live sessions, then explicitly uninstalls the old formula. Apply only removes
`~/.config/herdr/config.toml` and the legacy Pi reporter; it never stops
services, uninstalls software, or deletes runtime directories. App closing
leaves core terminals alive; reboot recovery restores kept shells, not agents.

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

### Change the global skill selection

The skills checkout at `~/gh/skills` owns both content and selection. Edit its
root `enabled-skills.json`, a JSON array of relative skill-directory paths. It
starts with the original 27 skills, explicitly listed, and may be reduced to `[]`.
Run `chezmoi apply`, then `/reload` in Pi. Add/rename/delete paths deliberately;
a deleted directory still listed is an error, not automatic deselection.

`run_before_90-skill-links.sh.tmpl` runs `scripts/pi-skills.py` on every apply,
using the destination HOME (not the process HOME). It validates the entire manifest
and destination before reconciling symlinks in `~/.agents/skills/`. Pi discovers
that shared directory automatically; its settings have no `skills` list. Each
link uses the selected directory's basename and points into the checkout. Missing
checkout/manifest/files, escaping or glob paths, duplicate directories, hidden or
duplicate discovery names (case-insensitive), and unrelated-name collisions fail
before changing any links or managed files. Discovery parents must be real
directories, not symlinks. Pi remains responsible for skill frontmatter validation.

Ownership is the symlink target: only links pointing inside `~/gh/skills` are
updated or removed, including dangling links after source deletion. Real skill
directories, foreign symlinks, and CLI locks stay untouched. `[]` removes all
checkout-owned links, not source content. Other agents using this shared directory
see the same selection. `chezmoi diff`/`--dry-run` shows the hook, not individual
link changes, and does not run it; a successful apply reports changed link names.

Editing selected content or supporting files, even without committing, requires
only `/reload`; apply is needed only when selection changes. Apply never clones,
pulls, downloads, copies, or deletes skill content. Git synchronization stays
manual, and no payload, copied selection, cache, hash, or runtime lock lives in
dotfiles. See [pi.md](pi.md#global-skills) for migration and stock Pi limitations.

The smoke test supplies tiny local checkout fixtures for each destination HOME,
rejects public Git/npx calls, and checks selection changes, preservation and failures through apply
plus Pi's real resource loader. It must never fetch from the skills repo or depend
on the developer's checkout.

### Maintain and update the skills fork

Pi reads `~/gh/skills` directly, so local edits are live on `/reload`. Publishing
makes them available to your other machines; it is not required for this Mac to
use them. Follow the fork's agent/contribution guidance and verify before pushing.
Neither apply nor Pi synchronizes the checkout. `mattpocock/skills` is only the
fork's upstream, not an installation source.

To incorporate upstream updates, use a clean checkout and reviewed integration
branch, not a force-sync that discards fork-only commits:

```bash
# In a clean checkout of brucepucci/skills, not this dotfiles repo:
git remote -v
# Verify origin is brucepucci/skills. If upstream is absent, add it once:
git remote add upstream https://github.com/mattpocock/skills.git
# If upstream already exists, verify its URL instead of adding it again.
git fetch origin
git switch main
git pull --ff-only origin main
git fetch upstream
git switch -c sync-upstream-YYYY-MM-DD  # choose a unique branch name
git merge upstream/main
```

Resolve conflicts while preserving intentional customizations, especially the
code-review workflow. Review the entire incoming diff, not only conflicts:
automatic merges can still change behavior. Check skill names/paths, instructions,
and source links; update fork docs and run its checks and applicable acceptance
scenarios. Commit resolutions as needed, then push the integration branch to
**your fork** and merge it into the fork's default branch after review. Do not
use `gh repo sync --force` or reset the fork to upstream. Preserve and reconcile
`enabled-skills.json` when skills are renamed or removed. To use published changes
on another Mac, synchronize its `~/gh/skills` checkout manually, then `/reload` in
Pi; run `chezmoi apply` first if the selection changed. The Skills CLI and
`pi update --extensions` do not manage this checkout.

### Project skill setup

`docs/agents/` is this repository's reviewed setup for the engineering skills:
GitHub Issues inferred from the current repository's remote, the five default
triage labels, and a single-context root `GLOSSARY.md` plus `docs/adr/` layout.
AGENTS.md links to these local conventions. They are not global defaults or
installed into HOME; other projects run `/skill:setup-matt-pocock-skills`
independently. Apply links selected global skills but never creates
issues or labels or runs project setup. The glossary and ADRs are created
lazily; root glossary files are explicitly ignored by chezmoi, like docs/.

### Edit the runbook / the project-local skill
The verification commands live in AGENTS.md ("Verifying a change",
"After changing plugins"); task-specific guidance lives here. Edit those
sources directly. `.agents/skills/chezmoi-runbook/SKILL.md` is a committed,
project-local entry point linking to them, not a generated or installed file.
Do not duplicate commands in the skill. If headings or paths change, update
its links too; the smoke test validates their targets and the frontmatter.

Start pi in this repo and grant project trust to discover
`/skill:chezmoi-runbook` (also available when starting in a repo subdirectory).
Use `/reload` after editing it in an existing trusted session. It is not
available in unrelated projects. AGENTS.md's verification requirements still
apply when the skill is not loaded or project trust is declined.

The literal `.agents/` directory is automatically skipped by chezmoi;
`chezmoi apply` only removes the former global runbook from
`~/.pi/agent/skills/chezmoi-runbook/` via `.chezmoiremove`. No generation step
or installation is needed for the local skill.

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
- Herdr desktop themes map the same resolved background, foreground,
  cursor, selection background, and ANSI 0–15 as Ghostty; Herdr derives its
  UI from them. System mode omits `appearance` for live OS following;
  pinned modes set it explicitly. No independent palette/theme input.
- New SSH-facing surfaces follow the SSH rule: render in terminal-indexed colors
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
