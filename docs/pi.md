# pi — the coding agent

[`pi`](https://github.com/earendil-works/pi) is the terminal coding agent
this whole setup orbits: an agent you converse with in the terminal, which
reads files, runs commands, and edits code. By default it runs GPT-6 Sol
with high reasoning through ChatGPT/Codex; the scoped model list contains
the GPT-6 Astra, Luna, and Sol models. The working arrangement is pi in one
Ghostty split, nvim in the other — pi writes, nvim reviews (see [nvim.md](nvim.md)).

The pieces, kept deliberately separate:

| Piece | Where it lives | Managed? |
|---|---|---|
| The binary | Homebrew: `pi-coding-agent` (in the Brewfile; the formula wraps the npm package in its own keg and pulls `node`) | installed, not configured, by this repo |
| Settings + themes | `dot_pi/agent/` → `~/.pi/agent/settings.json`, `~/.pi/agent/themes/dotfiles-{light,dark}.json` | **yes — chezmoi templates** |
| Global skills | `~/gh/skills/enabled-skills.json` → selected symlinks in `~/.agents/skills/` | **selection/content owned by the skills repo; links managed here** |
| The chezmoi-runbook skill | `.agents/skills/chezmoi-runbook/SKILL.md` (`/skill:chezmoi-runbook`) | **repo-local only — never installed to HOME** |
| The provider-usage extension | `dot_pi/agent/extensions/provider-usage.ts` → `~/.pi/agent/extensions/provider-usage.ts` | **yes — plain static file** |
| The title-screen extension | `dot_pi/agent/extensions/title-screen.ts` → `~/.pi/agent/extensions/title-screen.ts` | **yes — plain static file** |
| The permission-system package | `"packages"` in `dot_pi/agent/settings.json.tmpl` + `dot_pi/agent/extensions/pi-permission-system/config.json` → policy config | **yes — entry in the template; config a plain static file** |
| The subagents package | `"packages"` in `dot_pi/agent/settings.json.tmpl` | **yes — entry only; npm payload unmanaged** |
| Provider credentials | ChatGPT/Codex (default) via `/login`; Z.ai as an alternative via `ZAI_API_KEY` in `~/.zsh/secrets.zsh` or `/login` | **no — credentials are secrets, never in the repo** |

## The tmux wrapper (`pi()` in `~/.zshrc`)

Typing `pi` in a project directory normally starts a **new** conversation,
wrapped in its own named tmux session — so every conversation survives
closing the terminal and can be rejoined from any device. The session dies
when pi exits, so `tmux ls` is exactly the live conversations. Full
walkthrough in [tmux.md](tmux.md); the wrapper's own rules:

> **The herdr exception:** inside a [herdr](herdr.md) pane the wrapper
> stands down and pi runs bare — herdr is the detachable-session layer
> there, and its agent sidebar only sees pi running directly in a pane.
> Everything below describes the tmux path.

- **Never attaches.** Rejoining is explicitly `tmux attach -t <name>` —
  `pi` can't drop you into a stale session.
- **Naming**: sanitized project basename (`chezmoi`), numbered siblings on
  collision (`chezmoi-2`), or `pi -n "auth refactor"` → session
  `auth-refactor`, which pi also keeps as its conversation display name.
  An explicit topic that's already live is refused with the rejoin command.
- **Falls through to bare pi** (no session spawned) when: already inside
  tmux, **inside [herdr](herdr.md)** (`HERDR_ENV=1` — herdr is the
  persistence layer in its own panes, and its agent detection must see
  pi, not a tmux client), tmux isn't installed, not on a tty (unless
  `PI_TMUX_WRAP=force`),
  the cwd is `$HOME` (a home directory is not a project name), or the
  invocation is one-shot — any of `-h/--help -v/--version -p/--print
  --mode --list-models`, or a management subcommand (`install`, `config`,
  `auth`, package-only `update`, …). One-shot runs must never spawn a
  tmux server: the session would flash the alternate screen and swallow
  the output.
- **Triages `pi update`** — the one subcommand the wrapper inspects: the
  Brewfile installs pi from Homebrew, so the wrapper requires an
  **explicit** package or model-catalog target (`--extensions`,
  `--models`, `--extension <source>`, an `npm:`/`git:` spec — the only
  things that stay inside `~/.pi/agent`) and refuses everything else
  with the real upgrade path (`brew upgrade pi-coding-agent`): bare
  `update`, the `self`/`pi` aliases, `--self`/`--force`/`--all`,
  targetless runs in any spelling — trust flags `-a`/`-na`/
  `--approve`/`--no-approve` or an empty positional — and every
  unlisted flag, short or long (default-deny). Targeted forms fall
  through like every other management subcommand.
- **Typeahead is preserved**: keystrokes that arrive while the theme probe
  holds the terminal are stashed and re-injected into the session.

Knobs: `tmux_wrap = "off"` in `settings.toml` disables wrapping for the
whole machine (rendered as a `PI_TMUX_WRAP=never` default in `~/.zshrc`);
the env var still wins per shell (`never`, or `force` for one run).

## The theme probe (why the wrapper asks the terminal)

pi normally detects light/dark itself — but once the wrapper puts it under
tmux, its OSC 11 / scheme-report queries stop at the tmux layer, and over
SSH its fallback is silently "dark". So **before creating the session**,
the wrapper asks the *viewing* terminal directly (CSI ?996n scheme report,
falling back to an OSC 11 background query classified with pi's own
gamma-corrected luminance math, byte-for-byte the same contract). It then
launches pi with `--use-theme dotfiles-<side>`.

- A **pinned** mode in `settings.toml` (`theme = "light"/"dark"`) skips
  the probe entirely — `settings.json` already carries the single theme,
  and `--use-theme` would override the pin. This renders as
  `PI_THEME_PINNED` in `~/.zshrc`.
- A **user-supplied** `pi --use-theme <name>` is passed through untouched
  (the session still wraps; only the injection is suppressed).

The generated theme files ride terminal-indexed colors so pi follows the
viewing terminal even over SSH — the reasoning is in
[theming.md](theming.md).

## settings.json (managed)

```json
{
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-6-sol",
  "defaultThinkingLevel": "high",
  "enabledModels": [
    "openai-codex/gpt-6-astra",
    "openai-codex/gpt-6-luna",
    "openai-codex/gpt-6-sol"
  ],
  "theme": "dotfiles-light/dotfiles-dark",
  "packages": ["npm:@gotgenes/pi-permission-system", "npm:@tintinweb/pi-subagents"]
}
```

- `theme` renders the generated pair (`dotfiles-light/dotfiles-dark`) when
  the mode is `system`, or the single matching theme when pinned. The
  names are stable across theme swaps — changing `light_theme` in
  `settings.toml` re-*generates* the same two filenames.
- `lastChangelogVersion` is pi's own bookkeeping — it bumps itself on
  updates, so `chezmoi diff` shows that one field drifting after an
  upgrade. Harmless, like a lockfile drift. Because the file is
  template-sourced, `chezmoi re-add` skips it: after changing defaults via
  `/model`, fold them into `dot_pi/agent/settings.json.tmpl` by hand (see
  [developing.md](developing.md#pi-self-bumps)).

## Packages (npm extensions)

`packages` in `settings.json` carries npm-installed extensions:

- **`@gotgenes/pi-permission-system`** — permission gates over tool, bash,
  path, MCP, and skill access (`allow` / `ask` / `deny`; `path` rules cut
  across every tool and bash at once, so a deny can't be overridden by a
  per-tool allow). Unpinned, so `pi update --extensions` moves it — pin
  with `npm:@gotgenes/pi-permission-system@<version>` to freeze it.
  Package-only `update` variants fall through the shell wrapper like any
  management subcommand (see the tmux-wrapper section above); only the
  keg-touching ones are refused.

- **`@tintinweb/pi-subagents`** — Claude Code-style child Pi sessions via
  the `Agent` tool, with foreground/background runs and built-in
  general-purpose, Explore, and Plan agents. Uses the package's defaults;
  no custom agent configuration is managed here. Unpinned, like the
  permission system; update with `pi update --extensions`. After restarting
  Pi, `/agents` opens agent management and settings.

For the permission system, three distinct pieces, only two of them managed:

| Piece | Where | Managed? |
|---|---|---|
| The settings entry | `"packages"` in `dot_pi/agent/settings.json.tmpl` | **yes** |
| The policy config | `~/.pi/agent/extensions/pi-permission-system/config.json`, source `dot_pi/agent/extensions/private_pi-permission-system/config.json` | **yes — plain static file** (currently `yoloMode: true`: `ask` results auto-approve) |
| The package payload | `~/.pi/agent/npm/…`, installed by `pi install npm:@gotgenes/pi-permission-system` | **no — npm's tree, ignored** |

On a **fresh machine**, `chezmoi apply` writes the entry but not the
payload — pi auto-installs missing *project* packages at startup, never
user-scope ones. Install both packages once after the first apply
(idempotent — each command reconciles the existing install):

```bash
pi install npm:@gotgenes/pi-permission-system
pi install npm:@tintinweb/pi-subagents
```

`pi list` shows what's registered; the permission-system review log lands in
`~/.pi/agent/extensions/pi-permission-system/logs/` (unmanaged,
ignored).

Update npm packages manually with `pi update --extensions` (run from `$HOME`
to avoid updating project packages), then restart Pi to load changed code.
This setup no longer checks for package updates or provides
`/update-pi-packages`. Repo-managed extensions still update via `chezmoi apply`,
and Pi itself via `brew upgrade pi-coding-agent`.

## Global skills

One checkout, one selection, one discovery directory:

```text
~/gh/skills/                          source of truth: content + selection
  enabled-skills.json
  skills/engineering/code-review/

chezmoi apply
  ↓
~/.agents/skills/code-review → ~/gh/skills/skills/engineering/code-review
  ↓
Pi auto-discovery (also visible to other agents using this directory)
```

Pi discovers `~/.agents/skills/`, **not `~/.skills/`**. There is no explicit
`skills` list in Pi settings, no copied payload, and no cache in this setup.
The local [brucepucci/skills](https://github.com/brucepucci/skills) fork owns
content and selection; dotfiles only reconciles its symlinks.
[mattpocock/skills](https://github.com/mattpocock/skills) is the fork's upstream,
merged deliberately rather than fetched during apply. `find-skills` is no longer
selected or installed.

### Customized code review

`code-review` carries our focused/comprehensive PR workflow in the same fork.

- `/skill:code-review Review PR #123` publishes a focused GitHub Comment review
  with inline findings and a prominent Approve / Request changes recommendation.
- `/skill:code-review Comprehensive review PR #123` adds correctness, security,
  and material performance checks. `Pre-merge review` selects the same mode.
- `/skill:code-review Review the current branch` reports locally, with no
  GitHub writes. Explicit `draft only` also keeps PR findings in chat.

Both modes use the model and reasoning level selected before invocation. Reviews
cover the full committed branch diff, not just the last commit. The base is an
explicit override, the associated PR target, an unambiguously identified original
branch, or `main` as fallback. Git cannot reliably record original branch names;
the skill must announce its choice and evidence. Repeat reviews account for
previous feedback, discussion, and subsequent changes without duplicating open
findings. For PR reviews, the PR description is the default spec, without a
permission prompt; an explicitly requested alternative can override it. Local
reviews retain issue/path/file spec discovery. An empty or unfilled-template PR
description prompts for the missing spec. The skill rechecks the description
before publication because requirements can change without a new commit.
Creating a PR with a spec in its description is a separate, deferred workflow.
Publication never submits formal Approve or Request changes events or modifies
source files.

The fork's `skills/engineering/code-review/TESTING.md` lists behavioral acceptance
scenarios. Smoke tests verify installation wiring, not model compliance or live
GitHub publication.

### Selection and updates

Before the first apply, clone the fork to `~/gh/skills` (see the root README's
new-machine steps). Its root `enabled-skills.json` is a JSON array of skill
**directory** paths relative to the checkout, initially the original 27 skills:

```json
[
  "skills/engineering/implement",
  "skills/engineering/code-review",
  "skills/productivity/grilling"
]
```

Every apply runs `run_before_90-skill-links.sh.tmpl`, which calls
`scripts/pi-skills.py` with the destination HOME. It validates all input, then
creates/updates selected symlinks and removes deselected checkout-owned links.
Each entry must resolve inside the checkout and contain an in-checkout SKILL.md.
Links use directory basenames; hidden names and duplicate names (case-insensitive)
are rejected, as are duplicate directories, traversal and glob patterns. Missing
checkout/manifest/files and malformed JSON fail clearly. `[]` removes all links
targeting this checkout, including dangling ones, without deleting content.

Unrelated directories, files, symlinks and runtime locks remain untouched. If an
unrelated entry occupies a selected name, apply fails before changing links or
managed files; inspect and move/remove that entry explicitly rather than letting
apply overwrite it. `~/.agents` and its `skills` directory must be real directories,
not symlinks. Skill frontmatter remains Pi's responsibility: invalid YAML or
missing descriptions produce Pi diagnostics and the skill is not loaded.

| Change | Pick it up with |
|---|---|
| Edit a selected skill or its supporting files | `/reload` in Pi |
| Add/remove a path in the manifest | `chezmoi apply`, then `/reload` |
| Rename/delete a selected skill directory | Update its manifest entry, apply, then `/reload` |
| Update content from the fork | Synchronize the checkout yourself, then `/reload`; apply too if the selection changed |

Local edits, including uncommitted changes, are live through the links. Apply is
offline and never pulls, clones, copies, or deletes skill content. A missing
directory still listed in the manifest is an error, not an implicit deselection.
Removed entries stop loading when their checkout links are removed; files stay in
the checkout. This selection also affects other agents using `~/.agents/skills/`.
Unrelated user/project skills are preserved; avoid duplicate names in other
discovery locations. `chezmoi diff` and `--dry-run` show the hook without executing
it, so individual link changes appear only in apply's output.

Maintain and publish changes in the fork. Follow
[Maintain and update the skills fork](developing.md#maintain-and-update-the-skills-fork)
for upstream merges. `npx skills update` and `pi update --extensions` do not
update this checkout or its selection.

### Migration from cache paths or old CLI installs

Apply replaces the old settings file's explicit `skills` list, removing both
hashed cache paths and direct checkout paths. It reuses existing checkout-owned
symlinks and removes unselected ones, so unselected in-progress skills no longer
leak into discovery. Restart Pi or run `/reload`; selected skills should resolve
through `~/.agents/skills/` without collisions. Old `~/.cache/dotfiles/pi-skills/`
content is no longer referenced by this setup; apply leaves it untouched.

Old CLI-installed **copies** are not checkout symlinks, so apply preserves them
and fails on a selected-name conflict. The installer and automatic `find-skills`
installation are retired. For these copies, configure and validate the manifest
first, then inspect `~/.agents/.skill-lock.json`. Remove only registrations with
`sourceType: "github"` and `source: "brucepucci/skills"`, plus `find-skills` only if
registered to `vercel-labs/skills`, using their explicit names:

```bash
npx --yes skills@latest remove --global --skill <verified-names> --yes
```

This is a **manual one-time operation**, not an apply hook. The CLI updates its
own lock and removes shared canonical payloads and agent copies globally; other
agents using those copies are affected. Preserve unrelated registrations and
unregistered user skills. Run `chezmoi apply` after cleanup to create the selected
links, then restart Pi or run `/reload`. Do not re-run the old
installer from a stale dotfiles checkout or it can recreate the copies.

Run `/skill:setup-matt-pocock-skills` once per project when adopting the
engineering workflow. It proposes issue-tracker, triage-label and domain-doc
configuration; it does not install/update skills or fix compatibility. Upstream
instructions can mention a `Skill` tool and research subagents that stock Pi
does not provide; loading locally does not translate those instructions.
The selected
`code-review` skill explicitly discloses sequential review passes when subagents
are unavailable.

This repo's reviewed setup lives in `docs/agents/`, linked from AGENTS.md:
GitHub Issues for the current repo, default triage labels, and single-context
domain docs created lazily. Other projects run setup separately; this is not a
global issue destination. Apply does not run setup or create GitHub labels.

Tier-1 tests provide a disposable local checkout, reject npx invocations, and
check link ownership, migration, manifest changes, failure handling, and Pi's real
collision-free discovery offline.

## The chezmoi-runbook skill (project-local)

`.agents/skills/chezmoi-runbook/SKILL.md` is a thin entry point to AGENTS.md
and [developing.md](developing.md), not a copy of their commands. AGENTS.md
remains the source of truth for verification and plugin changes, and applies
whether or not the skill is invoked. Edit the runbook there; no generation
or `chezmoi apply` is needed to update the local skill's instructions.

Start pi in this repo and grant project trust to use `/skill:chezmoi-runbook`.
Pi also discovers `.agents/skills/` from repo subdirectories up to the repo
root. It is unavailable in unrelated projects, and declining project trust
skips it. Run `/reload` after edits in an existing trusted repo session.

The literal `.agents/` directory stays in the source repo; chezmoi skips it
automatically and never installs it to HOME. The smoke test checks frontmatter,
links to the live runbook, the installation boundary, and (when pi is installed)
actual project discovery and trust gating.

## Retired components (upgrade cleanup)

These global components are no longer installed; the runbook is now local:

| Removed component | Installed path removed by `chezmoi apply` |
|---|---|
| Experimental chezmoi grilling and grill-me copies (replaced by checkout symlinks) | `~/.pi/agent/skills/{grilling,grill-me}/` |
| Former global chezmoi-runbook skill (now project-local) | `~/.pi/agent/skills/chezmoi-runbook/` |
| Vendored code review skill (`/skill:code-review-skill`, guides, templates, analyzer) | `~/.pi/agent/skills/code-review-skill/` |
| Package-update prompt extension (`/update-pi-packages`, startup package checks) | `~/.pi/agent/extensions/package-update-prompt.ts` |

`.chezmoiremove` removes these exact targets on existing installs; fresh
installs receive none of these global copies. Other user skills and extensions
are left alone, as is the repo-local runbook. Restart Pi or run `/reload`
after applying to refresh discovery and unload the removed extension.
The provider-usage and title-screen extensions and permission-system package
remain globally configured; the runbook is only available in this repo.

## The provider-usage extension (managed)

`dot_pi/agent/extensions/provider-usage.ts` is a global extension (pi
auto-discovers `~/.pi/agent/extensions/`) that adds one footer row below
pi's built-in stats, for whichever provider owns the active model:

```
z.ai pro · 5h 3% (resets 14:32) · week 28% (resets Sat 09:07) · 37 tok/s
gpt plus · 5h 16% (resets 14:32) · week 3% (resets Sat 09:07) · 55 tok/s
```

- **tok/s** is output tokens per second — session average (generated
tokens ÷ generation time, anchored at the first streamed token so
time-to-first-token stays out of the average — the usual convention),
accumulated from pi's message events. Appears after the first response.
- **z.ai quota** comes from `api.z.ai/api/monitor/usage/quota/limit` (the
endpoint the z.ai console itself calls), keyed by `auth.json`'s zai entry
or `ZAI_API_KEY`. Shows the 5-hour and weekly windows with reset times.
- **claude quota** comes from Anthropic's OAuth usage endpoint and only
exists when pi is `/login`-ed into Claude Pro/Max with OAuth (an API-key
auth has no plan limits and is skipped). Note pi's own docs: harness
usage draws from extra usage billed per token, not plan limits — the
claude numbers reflect overall plan headroom (Claude Code, claude.ai),
not what pi consumes.
- **gpt quota** comes from `chatgpt.com/backend-api/wham/usage` (what the
Codex CLI reads) and only exists when pi is `/login`-ed into ChatGPT
Plus/Pro — pi's ChatGPT-plan provider id is `openai-codex`. The plain
API-key `openai` provider is metered billing, has no plan limits, and
stays hidden.

Quota polls every 60s (active provider only) and on model switches;
failed polls keep the last known-good quota, which ages out after ten
minutes. Fetches are aborted on session teardown and failures never
block pi. Colors reuse pi's theme (dim
labels; warning >70%, error >90% — the same thresholds as the context %).

## The title-screen extension (managed)

`dot_pi/agent/extensions/title-screen.ts` replaces pi's built-in startup
header with a splash. session_start fires on every launch AND on
`/new`, `/resume`, `/fork` and `/reload` — pi resets extension-managed
UI (the header with it) before each rebind — so the splash re-installs
on every reason; skipping any would strand the stock header for the
rest of the process. Terminals narrower than the glyph get a compact
one-liner instead of a wrapped block:

```
  ████████████
  ████████████
  ████    ████
  ████    ████
  ████████    ████
  ████████    ████
  ████        ████
  ████        ████
  gpt-6-sol · high
```

- The glyph is the pi logo mark itself (pi.dev's logo: a squared "P"
  with a square counter plus the "i" block, on its 4×4 grid, each cell
  rendered 4 chars × 2 rows so the mark comes out square), and
  everything sits at a two-space indent — enough air that the block
  glyphs don't sit on the terminal border (the render is still
  width-independent).
- ONE color for the whole block: the `text` role — the plain output-text
  color, so the mark reads as the content it captions, not chrome. The
  dotfiles themes map the role to the terminal's default foreground —
  exactly the color pi renders assistant output in, on a light or dark
  background alike. Roles only, the
  same indexed slots the generated themes carry — the splash follows the
  active dotfiles-{light,dark} theme and, through it, the viewing
  terminal's palette, even over SSH. Styling happens at render time
  against pi's live theme object, so an OS appearance flip re-tints it
  mid-session.
- The caption is snapshotted at install time — the model id and, for
  reasoning models only, the thinking level then in effect (pi's footer
  keeps tracking the live values; it spells a reasoning model's off as
  `thinking off`, the caption as plain `off`). With no model — no
  resolvable auth or catalogue — the caption drops out entirely. The
  splash is not expandable, so ctrl+o has nothing to reveal;
  `/builtin-header` brings the keybinding hints back and
  `/title-screen` re-installs the splash.
- Guarded by `scripts/test-title-screen.mjs` (jiti-loaded like pi loads
  it) and the smoke test's orphan-hex scan — the extension must never
  carry a hardcoded hex.

## Keys and commands worth remembering

Inside a conversation (pi's own bindings, not custom):

| Key / command | Action |
|---|---|
| `Shift+Enter` | Newline without submitting (needs the extended-keys tmux settings; phone clients must speak them) |
| `Alt-⌦` (alt+delete) | Kill next word — matched in zsh for parity |
| `/model` | Change model; **Ctrl+S** in that picker saves it as the default (that's what drifts settings.json) |
| `/login` | Choose ChatGPT/Codex for the default provider, or Z.ai as an alternative; Z.ai credentials in `auth.json` take precedence over `ZAI_API_KEY` |
| `/export` | Read-only HTML dump of the conversation |

From the shell:

| Command | Action |
|---|---|
| `pi` | New conversation, auto-wrapped in a named tmux session |
| `pi -n "topic"` | New conversation with an explicit session/topic name |
| `pi -c` | Resume the most recent conversation (new wrapped session) |
| `pi -r` | Resume: pick a conversation from a list |
| `pi -p "..."` | One-shot print mode — never wraps, never spawns tmux |
| `tmux ls` / `tmux a -t <name>` | List / rejoin live conversations |

## Sessions and privacy

Conversations auto-save under `~/.pi/agent/sessions/` — unmanaged
(transcripts), listed in `.chezmoiignore` so an accidental `chezmoi add
~/.pi` can't sweep them into the repo. Same for `auth.json` (a copy of
the API key — a secret) and `models-store.json` (a catalog cache pi
refetches itself).
