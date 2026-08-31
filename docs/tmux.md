# tmux + SSH — the session that follows you

tmux exists here for exactly one job: **detachable sessions**. A coding
session — the pi conversation, the nvim splits, the dev server — normally
lives in processes owned by a terminal window. Close the window, or leave
the desk, and the state is gone. tmux moves those processes into a server
that runs independently of any terminal, so any terminal — including a
phone over SSH — can plug back into exactly what was running.

**Managed file**: `dot_tmux.conf` → `~/.tmux.conf`.

**The division of labor is deliberate:** Ghostty manages local windows,
splits, and tabs; tmux only makes sessions detachable. No prefix remap, no
plugin ecosystem, no status-line theming. Shells inside tmux are just more
zsh reading the same `~/.zshrc` — same history, same prompt.

The full end-to-end walkthrough (phone-client setup, the handoff choreo,
troubleshooting) is also installed inside the editor at
`~/.config/nvim/docs/tmux.md`, reachable from nvim with `<leader>?` —
useful when you're already SSH'd in. This page is the repo reference.

## pi wraps itself

You do not run tmux for pi. Typing `pi` in a project directory always
starts a **new** conversation, wrapped in its own named tmux session (the
wrapper is in `~/.zshrc` — details in [pi.md](pi.md)):

```bash
cd code/chezmoi
pi                   # -> "pi: tmux session \"chezmoi\" (detach Ctrl-b d; rejoin: tmux attach -t chezmoi)"
# ... work; detach with Ctrl-b d, or just close the terminal
tmux a -t chezmoi    # rejoin from ANY terminal: desk, laptop, phone over SSH
```

- **Naming**: the project directory's basename; a collision mints a
  numbered sibling (`chezmoi-2`, `chezmoi-3`, …); `pi -n "auth refactor"`
  names the session `auth-refactor` and pi's own session display name. An
  explicitly named topic that is already live is refused with the rejoin
  command — nothing is silently renamed.
- **Lifecycle**: the session dies when pi exits, so `tmux ls` lists
  exactly the live conversations. No junk drawer.
- **Rejoining is always explicit** — `pi` never attaches to anything, so
  it can never drop you into a stale session by surprise.

For anything that isn't pi — nvim, a dev server, plain shells — wrap by
hand, same survival properties: `tmux new -s work`, work, `Ctrl-b d`,
later `tmux attach -t work`.

## The managed config, setting by setting

Six settings, each load-bearing:

| Setting | Why it's there |
|---|---|
| `extended-keys on` + `extended-keys-format csi-u` | pi's documented tmux requirements. Without them tmux strips modifier info and `Shift+Enter` collapses to plain `Enter` — pi's newline binding dies under tmux. Needs tmux ≥ 3.5. |
| `set-clipboard on` | OSC 52 clipboard: copy-mode yanks (and OSC 52-speaking apps) land on the clipboard of the **connecting** device — over SSH, the phone in your hand. (nvim on macOS keeps using pbcopy, so its yanks land on the Mac; copy-mode is the phone path.) |
| `mouse on` + `history-limit 10000` | The wheel scrolls pane history — copy-mode in, auto-exit at the bottom — from any client, phone included. Without it the wheel over tmux's alternate screen arrives as Up/Down arrows and pi's input box reads them as message history. 10k lines because pi conversations outgrow the 2000 default. |
| `focus-events on` | Focus reporting through the tmux layer; nvim's `FocusGained` drives the light/dark appearance sync and the reload-on-external-write. Both silently dead under tmux without it. |
| `terminal-overrides ',*:RGB'` | Truecolor passthrough — the nvim colorscheme is generated as exact hexes; without RGB advertised on the inner terminal, tmux silently downgrades them to 256-color approximations. |
| `window-status-format` / `-current-format` | The stock bar runs the session name into the window list (`[chezmoi-2] 0:node*` scans as `chezmoi-20`); a leading `\|` on every window entry keeps the fields apart. Text only. |

## Keys and commands (the whole survival kit)

tmux commands go through a **prefix**: press `Ctrl-b`, release, *then* the
command key. Two presses, not a chord.

| Action | Keys / command |
|---|---|
| New pi conversation (auto-wrapped, named) | `pi` (in the project dir) |
| Named topic conversation | `pi -n "auth refactor"` |
| Detach | `Ctrl-b` `d` |
| Rejoin — lands straight inside the running pi | `tmux a -t <name>` |
| List live conversations | `tmux ls` |
| Scroll / copy mode | mouse wheel, or `Ctrl-b` `[` (exit: `q`) |
| Take over from another client | `tmux attach -d -t <name>` |
| New window — useful on the phone, where there's no second Ghostty tab | `Ctrl-b` `c` (next `n`, prev `p`) |
| Retire a session for good | `tmux kill-session -t <name>` |

## SSH: getting in from elsewhere — and why it's set up this way

The whole point of the tmux layer is that the Mac becomes a *server* for
your working sessions: you should be able to walk away from the desk and
pick up the same conversation from the couch, or from a hotel. Everything
SSH-facing in this repo follows from that:

- **One shell everywhere** means the SSH session is not a second-class
  environment — same `~/.zshrc`, same shared history, same prompt. Nothing
  to "set up" on the client beyond an SSH app.
- **The prompt and pi render in indexed colors** precisely so they look
  right on whatever terminal the *client* runs — see
  [theming.md](theming.md#the-ssh-rule-indexed-colors-not-hexes).
- **The pi wrapper probes the viewing terminal for light/dark before
  creating the session**, because pi's own detection can't see through the
  tmux layer — without it, every SSH'd conversation silently rendered the
  dark theme.

**On the Mac (one-time):**

1. System Settings → General → Sharing → turn on **Remote Login** (SSH).
2. Find your login: `whoami` and `scutil --get LocalHostName`.
3. Install [Tailscale](https://tailscale.com) on the Mac and the phone,
   same account. On home Wi-Fi it's optional; away from home it's the safe
   path. **Never expose port 22 to the internet.**
4. **Keep the Mac awake** — the number-one gotcha; a sleeping Mac refuses
   SSH. Before walking away:
   ```bash
   caffeinate -dims -t 28800 &!   # awake for 8h, disowned so closing the terminal can't HUP it
   ```

**On the phone:**

5. Install a client: **Blink Shell** (iOS — mosh-aware, the best over
   cellular) or **Termius** (iOS/Android); **Termux** works on Android too.
6. Add a host `user@machinename.local` (the Bonjour name) or the Tailscale
   hostname; connect once at the desk to test.
7. `tmux a -t <name>` — you're back inside the conversation.

**Two things to know:**

- With two clients attached, the **most recent** one sets the size for
  everyone (`window-size latest`, the tmux 3.7 default). One device at a
  time is the comfortable arrangement; `tmux attach -d` takes over.
- `Shift+Enter` from the phone needs a client that speaks extended keys —
  Blink and Termius do. Otherwise plain `Enter` still submits fine.

**No live session to rejoin?** Every pi conversation auto-saves under
`~/.pi/agent/sessions/` — from the phone, `cd <project> && pi -c` resumes
the latest (or `pi -r` to pick). That restores the conversation and its
context, not live process state — an in-flight tool run or open splits
don't come along. For manual sessions the habit is the fix: start under
tmux *before* the work matters.

**Flaky cellular:** `mosh` survives phone sleep and IP changes where SSH
drops; pair it with tmux (mosh deliberately has no scrollback — tmux
provides it). Not in the Brewfile; install server-side if you want it.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| SSH times out | The Mac is asleep. Wake it (Tailscale + Wake-on-LAN) or `caffeinate -dims` next time. |
| Session shrunk into a corner | A later client set the size for everyone. `tmux attach -d -t <name>` from the device that should be full-size. |
| `no server running on /tmp/tmux-...` | No sessions — rebooted or killed. `pi` starts a new wrapped conversation; `pi -c` reloads the last one. |
| Closed Ghostty mid-pi-run — lost? | No. Only `kill-session`, a reboot, or killing the process ends a detached session. |
| pi fails auth after rotating keys in `~/.zsh/secrets.zsh` | Panes inherit the tmux **server's** environment, snapshotted at server start. `tmux kill-server` (ends live conversations), then start fresh. |
| `Shift+Enter` submits instead of newline (phone) | That client doesn't speak extended keys. Blink/Termius do. |
