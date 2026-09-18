# herdr — agent multiplexer

[herdr](https://herdr.dev) organizes terminal work into workspaces, tabs,
and panes, recognizes coding agents running in those panes, and exposes
the live session through a `herdr` CLI. Rust client plus a `herdr server`
daemon that everything talks to over a unix socket — the same
detachable-session idea as [tmux](tmux.md), but aware of what's running
inside the panes.

**Managed files**:

- `private_dot_config/herdr/config.toml` → `~/.config/herdr/config.toml`
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

## First session

```bash
cd code/dotfiles
herdr                # opens the TUI: spaces (workspaces) on the left
                     # (the first launch boots the server in the background)
```

- **New space**: `Ctrl-b` then `Shift+n`. The shell that opens is ordinary
  zsh — same `~/.zshrc` as everywhere else.
- **Keys**: `Ctrl-b` then `?` lists everything; the ones that matter early
  are split (`Ctrl-b` `v` / `Ctrl-b` `-`), pane focus (`Ctrl-b` then
  `h`/`j`/`k`/`l` — or prefix-free with `Ctrl-Alt` + `h/j/k/l`, mirroring
  nvim's `<C-hjkl>` window movement), jump back to the previous pane
  (`Ctrl-b` then `space`, the ctrl+6 reflex), maximize (`Ctrl-b` `z` or
  `Ctrl-Alt` `z`, like `<leader>sm`), and close pane (`Ctrl-b` `x`).
- **pi inside herdr**: type `pi` in a pane. The wrapper skips tmux here
  (herdr is the detachable-session layer), so herdr's **agents** sidebar
  lists the conversation with live working/idle state — that only works
  for pi running directly in a herdr pane.
- **Optional, recommended: the pi integration** —
  `herdr integration install pi` drops a state-reporter into
  `~/.pi/agent/extensions/` so herdr sees working vs waiting-for-input,
  and pi conversations can resume after a server restart. Re-run it
  after herdr upgrades if a release changes the protocol; it is
  idempotent. Not managed by this repo (see below).
- **Detach**: `Ctrl-b` then `q` — everything keeps running on the
  server; close the terminal window if you like. **Reattach**: `herdr`
  from anywhere (including over SSH).

Detaching is not stopping: panes, shells, and agents live in the herdr
server, not in your terminal window. The TUI is just a view.

## Persistence: what survives what

Three different events, three different outcomes — don't conflate them:

| Event | Processes (shells, agents, dev servers) | Layout | pi conversations |
|---|---|---|---|
| Detach / close the terminal | **keep running** | back on reattach | live, exactly as left |
| Server restart / reboot | **gone** | restored (shape, cwd, focus) | resumed only with the pi integration installed (`resume_agents_on_restore`, on by default) — the conversation resumes, in-flight process state does not |
| `brew services start herdr` | starts/**restarts the daemon** at login — it does **not** preserve processes through a reboot | as above | as above |

So the service is about convenience (the daemon is always up, no
first-launch boot), not durability: an in-flight task does not survive a
reboot any more than it would under tmux. The on-demand default — the
first TUI or CLI call boots the server, it exits when the last session
does — is the current choice; flip to `brew services start herdr` if
the daemon-at-login convenience ever matters.

## The managed config

A small static file (`private_dot_config/herdr/config.toml`), and
singularly *not* derived from `settings.toml` — because of the SSH rule:

- **Theme**: herdr's built-in `terminal` theme paints the UI from the
  rendering terminal's own ANSI palette and default fg/bg (herdr queries
  OSC 10/11 and the OSC 4 palette at runtime — the same live-probe idea
  as pi's theme detection). Over SSH the TUI therefore follows the
  *viewing* terminal, exactly like the prompt and pi, instead of pinning
  the Mac's palette onto the client. The file carries no hex at all and
  nothing in it varies with the appearance setting — the smoke test
  enforces both (a strict no-hex check, and a byte-identical render
  across pinned and system modes).
- **Updates**: `version_check = false`, `manifest_check = false`,
  `channel = "stable"` — brew owns the version.
- **Onboarding**: off — the config exists from the first apply.

Hand edits to `~/.config/herdr/config.toml` are wiped by the next apply.
herdr hot-reloads the file: `herdr server reload-config` (or
`prefix+shift+r` inside the TUI).

## pi inside herdr

Type `pi` in a herdr pane and it runs **bare** — the `pi()` wrapper
skips tmux when `HERDR_ENV=1` (see [pi.md](pi.md)). That is what makes
herdr's sidebar work: herdr detects agents by the pane's foreground
process and its own docs are explicit that tmux sessions launched inside
a herdr pane hide the agent behind the tmux client; the tmux server's
environment snapshot also strips `HERDR_*`, which would silence the
pi state-reporting integration. herdr's server keeps panes alive across
detach and TUI exit, so nothing is lost by dropping the tmux layer here —
herdr is the detachable-session layer, the same job tmux does elsewhere.
Launch agents from Ghostty tabs (tmux-wrapped) **or** from herdr panes
(bare, sidebar-visible) — not both layered.

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
