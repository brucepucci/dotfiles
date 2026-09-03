# pi — the coding agent

[`pi`](https://github.com/earendil-works/pi) is the terminal coding agent
this whole setup orbits: an agent you converse with in the terminal, which
reads files, runs commands, and edits code. It runs Z.ai's GLM models on
their Coding Plan. The working arrangement is pi in one Ghostty split,
nvim in the other — pi writes, nvim reviews (see [nvim.md](nvim.md)).

Three pieces, kept deliberately separate:

| Piece | Where it lives | Managed? |
|---|---|---|
| The binary | npm: `@earendil-works/pi-coding-agent` (via the Brewfile, which also pulls its hard dependency `node`) | installed, not configured, by this repo |
| Settings + themes | `dot_pi/agent/` → `~/.pi/agent/settings.json`, `~/.pi/agent/themes/dotfiles-{light,dark}.json` | **yes — chezmoi templates** |
| The runbook skill | `dot_pi/agent/skills/runbook/SKILL.md.tmpl` → `~/.pi/agent/skills/runbook/SKILL.md` (`/skill:runbook`) | **yes — generated from AGENTS.md at apply time** |
| The provider-usage extension | `dot_pi/agent/extensions/provider-usage.ts` → `~/.pi/agent/extensions/provider-usage.ts` | **yes — plain static file** |
| The API key | `ZAI_API_KEY` in `~/.zsh/secrets.zsh` (or `~/.pi/agent/auth.json` via `/login`) | **no — a secret, never in the repo** |

## The tmux wrapper (`pi()` in `~/.zshrc`)

Typing `pi` in a project directory always starts a **new** conversation,
wrapped in its own named tmux session — so every conversation survives
closing the terminal and can be rejoined from any device. The session dies
when pi exits, so `tmux ls` is exactly the live conversations. Full
walkthrough in [tmux.md](tmux.md); the wrapper's own rules:

- **Never attaches.** Rejoining is explicitly `tmux attach -t <name>` —
  `pi` can't drop you into a stale session.
- **Naming**: sanitized project basename (`chezmoi`), numbered siblings on
  collision (`chezmoi-2`), or `pi -n "auth refactor"` → session
  `auth-refactor`, which pi also keeps as its conversation display name.
  An explicit topic that's already live is refused with the rejoin command.
- **Falls through to bare pi** (no session spawned) when: already inside
  tmux, tmux isn't installed, not on a tty (unless `PI_TMUX_WRAP=force`),
  the cwd is `$HOME` (a home directory is not a project name), or the
  invocation is one-shot — any of `-h/--help -v/--version -p/--print
  --mode --list-models`, or a management subcommand (`install`, `update`,
  `config`, `auth`, …). One-shot runs must never spawn a tmux server: the
  session would flash the alternate screen and swallow the output.
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
  "defaultModel": "glm-5.3",
  "enabledModels": [ ... anthropic and zai models ... ],
  "theme": "dotfiles-light/dotfiles-dark"
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

## The runbook skill (managed)

`dot_pi/agent/skills/runbook/SKILL.md.tmpl` generates
`~/.pi/agent/skills/runbook/SKILL.md` — a global skill location, so
`/skill:runbook` is available in every pi session on the machine. The
verify/plugins steps are extracted **verbatim from AGENTS.md** at apply
time: edit AGENTS.md, `chezmoi apply`, and the skill follows — never edit
the skill (or its template's extracted regions) by hand. Apply fails
loudly if the sections disappear from AGENTS.md; the smoke test checks
the render and the frontmatter.

## The provider-usage extension (managed)

`dot_pi/agent/extensions/provider-usage.ts` is a global extension (pi
auto-discovers `~/.pi/agent/extensions/`) that adds one footer row below
pi's built-in stats, for whichever provider owns the active model:

```
z.ai pro · 5h 3% (resets 14:32) · week 28% (resets Sat 09:07) · 37 tok/s
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

Quota polls every 60s (active provider only) and on model switches;
failed polls keep the last known-good quota, which ages out after ten
minutes. Fetches are aborted on session teardown and failures never
block pi. Colors reuse pi's theme (dim
labels; warning >70%, error >90% — the same thresholds as the context %).

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
