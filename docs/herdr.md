# herdr — agent multiplexer (evaluation)

[herdr](https://herdr.dev) organizes terminal work into workspaces, tabs,
and panes, recognizes coding agents running in those panes, and exposes
the live session through a `herdr` CLI. Rust client plus a `herdr server`
daemon that everything talks to over a unix socket — the same
detachable-session idea as [tmux](tmux.md), but aware of what's running
inside the panes.

**Managed file**: the [Brewfile](../Brewfile) entry only, for now. The
config is not yet chezmoi-managed — it is still in its test-drive phase
(see [Open questions](#open-questions)).

## Install and updates

```bash
brew bundle --file="$(chezmoi source-path)/Brewfile"   # installs it with everything else
```

**`brew upgrade`, never `herdr update`.** The binary ships its own
updater (update channels, background version checks, `herdr update`),
which — like pi's `pi update` — would stomp a brew-owned keg and break
`brew upgrade` bookkeeping. Brew owns the file; the repo's one package
manager owns the version. Same rule as pi — whose `pi` wrapper goes
further and refuses targetless `pi update` runs with the real upgrade
path (see [pi.md](pi.md), "The tmux wrapper"); herdr does not yet do
that, so the discipline is on you.

## The server model

`herdr status` shows both halves: the CLI version and whether a server
is running (socket at `~/.config/herdr/herdr.sock`).

- **On demand** (current setup): starting the TUI boots the server if
  needed; it exits when the last session goes away. Nothing runs at
  login.
- **As a service**: `brew services start herdr` runs `herdr server` at
  login with `keep_alive` — the herdr equivalent of the tmux server's
  always-on role. Only worth it once sessions are load-bearing (see
  tmux.md for why that matters over SSH).

Headless control without the TUI: `herdr workspace create --label …`,
`herdr status server`, `herdr server stop`.

## Config

XDG: `~/.config/herdr/config.toml`. `herdr --default-config` prints the
fully-commented default; `herdr server reload-config` hot-reloads it.
On first run herdr writes onboarding state there itself — the reason
there is no managed `config.toml` yet.

Shell completions need no wiring: brew drops `_herdr` into
`/opt/homebrew/share/zsh/site-functions`, which Homebrew's zsh already
has on `fpath`.

herdr also ships an agent skill (`herdr --skill`) for agents running
*inside* herdr panes (gated on `HERDR_ENV=1`): inspecting panes, reading
output, starting agents. If herdr sticks, that becomes a candidate for
`dot_pi/agent/skills/` alongside the chezmoi runbook.

**pi integration.** `herdr integration install pi` drops
`herdr-agent-state.ts` into `~/.pi/agent/extensions/` so pi panes report
agent state (working / waiting for input) to herdr — it is also what
enables `[session] resume_agents_on_restore`. Deliberately **not managed
by this repo**: the file is herdr's own payload, version-locked to the
herdr protocol — the same class as `~/.pi/agent/npm`, the unmanaged
payload of pi's `pi install` — and a vendored copy would silently go
stale on every `brew upgrade herdr`. Re-running the install is
idempotent and refreshes the file; do it if a herdr upgrade ever changes
the protocol. If herdr passes evaluation, the README's new-machine list
gains this one command — documented like `brew bundle`, never automated:
`chezmoi apply` runs nothing behavioral in this repo.

## Open questions

Things to settle before folding the config into chezmoi:

1. **Theming.** herdr themes are its own built-in names
   (`kanagawa`, `catppuccin`, …) plus per-token hex overrides, with an
   `auto_switch` light/dark pair. The dark side maps cleanly
   (`Kanagawa Wave` → `kanagawa`); Flexoki Light has no herdr built-in,
   so a managed template would need either a name-mapping table in
   `settings.toml` or hex overrides derived from the role tables — same
   pattern as pi's theme templates. Undecided.
2. **Service or not.** On-demand server vs `brew services start herdr`.
3. **Update checks.** Whether to set `[update] version_check = false` in
   a managed config so the brew-vs-self-update seam stays quiet.
