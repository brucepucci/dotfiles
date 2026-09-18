# pi — the coding agent

[`pi`](https://github.com/earendil-works/pi) is the terminal coding agent
this whole setup orbits: an agent you converse with in the terminal, which
reads files, runs commands, and edits code. It runs Z.ai's GLM models on
their Coding Plan. The working arrangement is pi in one Ghostty split,
nvim in the other — pi writes, nvim reviews (see [nvim.md](nvim.md)).

Three pieces, kept deliberately separate:

| Piece | Where it lives | Managed? |
|---|---|---|
| The binary | Homebrew: `pi-coding-agent` (in the Brewfile; the formula wraps the npm package in its own keg and pulls `node`) | installed, not configured, by this repo |
| Settings + themes | `dot_pi/agent/` → `~/.pi/agent/settings.json`, `~/.pi/agent/themes/dotfiles-{light,dark}.json` | **yes — chezmoi templates** |
| The chezmoi-runbook skill | `dot_pi/agent/skills/chezmoi-runbook/SKILL.md.tmpl` → `~/.pi/agent/skills/chezmoi-runbook/SKILL.md` (`/skill:chezmoi-runbook`) | **yes — generated from AGENTS.md at apply time** |
| The provider-usage extension | `dot_pi/agent/extensions/provider-usage.ts` → `~/.pi/agent/extensions/provider-usage.ts` | **yes — plain static file** |
| The title-screen extension | `dot_pi/agent/extensions/title-screen.ts` → `~/.pi/agent/extensions/title-screen.ts` | **yes — plain static file** |
| The permission-system package | `"packages"` in `dot_pi/agent/settings.json.tmpl` + `dot_pi/agent/extensions/pi-permission-system/config.json` → policy config | **yes — entry in the template; config a plain static file** |
| The API key | `ZAI_API_KEY` in `~/.zsh/secrets.zsh` (or `~/.pi/agent/auth.json` via `/login`) | **no — a secret, never in the repo** |

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
  "defaultProvider": "zai",
  "defaultModel": "glm-5.3-flash",
  "enabledModels": [ ... zai and openai-codex models ... ],
  "theme": "dotfiles-light/dotfiles-dark",
  "packages": ["npm:@gotgenes/pi-permission-system"]
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

`packages` in `settings.json` carries npm-installed extensions. Today that
is one:

- **`@gotgenes/pi-permission-system`** — permission gates over tool, bash,
  path, MCP, and skill access (`allow` / `ask` / `deny`; `path` rules cut
  across every tool and bash at once, so a deny can't be overridden by a
  per-tool allow). Unpinned, so `pi update --extensions` moves it — pin
  with `npm:@gotgenes/pi-permission-system@<version>` to freeze it.
  Package-only `update` variants fall through the shell wrapper like any
  management subcommand (see the tmux-wrapper section above); only the
  keg-touching ones are refused.

Three distinct pieces, only two of them managed:

| Piece | Where | Managed? |
|---|---|---|
| The settings entry | `"packages"` in `dot_pi/agent/settings.json.tmpl` | **yes** |
| The policy config | `~/.pi/agent/extensions/pi-permission-system/config.json`, source `dot_pi/agent/extensions/private_pi-permission-system/config.json` | **yes — plain static file** (currently `yoloMode: true`: `ask` results auto-approve) |
| The package payload | `~/.pi/agent/npm/…`, installed by `pi install npm:@gotgenes/pi-permission-system` | **no — npm's tree, ignored** |

On a **fresh machine**, `chezmoi apply` writes the entry but not the
payload — pi auto-installs missing *project* packages at startup, never
user-scope ones. Run `pi install npm:@gotgenes/pi-permission-system`
once after the first apply (idempotent — it reconciles the existing
install). `pi list` shows what's registered; the review log lands in
`~/.pi/agent/extensions/pi-permission-system/logs/` (unmanaged,
ignored).

## The chezmoi-runbook skill (managed)

`dot_pi/agent/skills/chezmoi-runbook/SKILL.md.tmpl` generates
`~/.pi/agent/skills/chezmoi-runbook/SKILL.md` — a global skill location,
so `/skill:chezmoi-runbook` is available in every pi session on the
machine. The verify/plugins steps are extracted **verbatim from AGENTS.md**
at apply time: edit AGENTS.md, `chezmoi apply`, and the skill follows —
never edit the skill (or its template's extracted regions) by hand. Apply fails
loudly if the sections disappear from AGENTS.md; the smoke test checks
the render and the frontmatter.

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
  glm-5.3 · high
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
| `/login` | Store the Z.ai key in `~/.pi/agent/auth.json` — takes precedence over `ZAI_API_KEY` when present |
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
