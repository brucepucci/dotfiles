# herdr — agent multiplexer

[herdr](https://herdr.dev) organizes terminal work into workspaces, tabs,
and panes, recognizes coding agents running in those panes, and exposes
the live session through a `herdr` CLI. Rust client plus a `herdr server`
daemon that everything talks to over a unix socket — the same
detachable-session idea as [tmux](tmux.md), but aware of what's running
inside the panes.

**Managed files**:

- `private_dot_config/herdr/config.toml.tmpl` → `~/.config/herdr/config.toml`
- the `herdr()` wrapper in `~/.zshrc` (see
  [zsh.md](zsh.md) — same file as the `pi()` wrapper)
- the [Brewfile](../Brewfile) entry

herdr's own runtime state (`herdr-server.log`, `herdr-client.log`,
`session.json`, `.plugins.lock`) lives beside the config and is left
unmanaged.

## Install and updates

```bash
brew bundle --file="$(chezmoi source-path)/Brewfile"   # installs it with everything else
brew upgrade herdr                                     # the only upgrade path
```

**The binary is brew-owned; herdr must never update itself.** herdr ships
a self-updater (`herdr update`, update channels, background version
checks) that would stomp a brew keg and desync `brew upgrade`
bookkeeping — the same hazard as pi's. Two layers refuse it: the `herdr()`
wrapper in `~/.zshrc` turns any `herdr update` into a refusal naming
`brew upgrade herdr` (herdr has no package-only update form, unlike pi's
`update --extensions`, so every update invocation is a self-update), and
the managed config turns the background checks off. The smoke test asserts
both. herdr also refuses on its own for Homebrew installs — belt and
braces.

## The managed config

Rendered from `settings.toml` + the vendored theme mirror by
`scripts/theme.py`, exactly like every other surface:

- **Theme**: the base is herdr's built-in `terminal` theme; a generated
  palette rides on top, one token per resolved role — surfaces
  (`panel_bg` ← bg, `sidebar_bg` ← bg_deep, `surface0` ← statusline,
  `surface1` ← surface, overlays ← the greys), text (`text` ← fg,
  `subtext0` ← fg_soft), accents (`accent`/`blue` ← blue, `mauve` ←
  purple, `teal` ← aqua, `peach` ← orange, plus same-named red/green/
  yellow), and `selection_bg` ← the theme's own terminal selection color.
  Under `theme = "system"` the config sets `auto_switch = true` and
  carries `[theme.custom.light]` + `[theme.custom.dark]`; a pinned mode
  renders one `[theme.custom]` palette and no auto switching.
- **Updates**: `version_check = false`, `manifest_check = false`,
  `channel = "stable"` — brew owns the version.
- **Onboarding**: off — the config exists from the first apply.

Everything is generated; hand edits to `~/.config/herdr/config.toml` are
wiped by the next apply. herdr hot-reloads the file:
`herdr server reload-config` (or `prefix+shift+r` inside the TUI).

## Server model

On demand (the decision for now): the first TUI or CLI call boots the
server; it exits when the last session does. Nothing runs at login. If
sessions ever become load-bearing across reboots — the tmux.md use case —
flip to `brew services start herdr` (keep_alive at login) and say so here.

## Agent integrations

herdr detects coding agents in panes; per-agent state hooks install with
`herdr integration install …`. **pi integration.** `herdr integration
install pi` drops `herdr-agent-state.ts` into `~/.pi/agent/extensions/`
so pi panes report agent state (working / waiting for input) to herdr —
it is also what enables `[session] resume_agents_on_restore`.
Deliberately **not managed by this repo**: the file is herdr's own
payload, version-locked to the herdr protocol — the same class as
`~/.pi/agent/npm`, the unmanaged payload of pi's `pi install` — and a
vendored copy would silently go stale on every `brew upgrade herdr`.
Re-running the install is idempotent and refreshes the file; do it if a
herdr upgrade ever changes the protocol. Documented like `brew bundle`,
never automated: `chezmoi apply` runs nothing behavioral in this repo.
