# tmux: taking the session with you

A coding session — the shells, the nvim splits, a pi run in flight — lives in
processes owned by a terminal window. Close the window, or leave the desk, and
the state is gone. tmux moves those processes into a server that runs
independently of any terminal, so any terminal can plug back into exactly what
was running — including a phone, over SSH, from bed.

If you read nothing else: **start the day under `tmux new -s work`, detach with
`Ctrl-b d`, reattach from anywhere with `tmux attach -t work`.** The rest of
this page teaches that sentence properly.

---

## What this setup ships (and why so little)

`tmux` comes from the Brewfile. The managed `~/.tmux.conf` is deliberately
minimal — three settings, each load-bearing:

| Setting | Why it is there |
|---|---|
| `extended-keys on` + `extended-keys-format csi-u` | pi's documented tmux requirements. Without them tmux strips modifier information, and `Shift+Enter` collapses to plain `Enter` — pi's newline binding dies under tmux. Needs tmux ≥ 3.5. |
| `set-clipboard on` | OSC 52 clipboard: yanks (nvim, tmux copy mode) land on the clipboard of the **connecting** device — over SSH, the phone in your hand. Locally, the normal clipboard path is untouched. |
| `terminal-overrides ',*:RGB'` | Truecolor passthrough. The nvim colorscheme is generated from the theme roles as exact hexes; without RGB advertised on the inner terminal, tmux silently downgrades them to 256-color approximations. |

No prefix remap, no plugin ecosystem, no status-line theming. The division of
labor is deliberate: **Ghostty manages local windows, splits, and tabs; tmux
only makes sessions detachable.** Shells inside tmux are ordinary zsh reading
the same `~/.zshrc` — same history, same prompt, same everything.

## The mental model

Three words carry the whole idea:

- A tmux **server** runs on the Mac and owns your **sessions**. It starts on
  demand when you create the first session, and it keeps running when every
  terminal window is gone.
- A terminal is a **client** — a view onto a session. **Detaching** unplugs
  the view and leaves the session running. **Attaching** plugs a view back in,
  from any device.
- tmux commands go through a **prefix**: press `Ctrl-b`, release it, *then*
  press the command key. Two presses, not a chord. It feels odd for a day and
  then disappears into muscle memory.

## The daily habit

Practice this once at the desk before you ever need it:

1. **Start the day under tmux** — make it as automatic as opening the
   terminal:
   ```bash
   tmux new -s work
   ```
   A status bar appears at the bottom of the window. That is how you know you
   are *inside*. The name (`work`) is arbitrary; use whatever describes the
   day.

2. **Work normally.** `cd` to the project, start pi, open nvim. Nothing about
   the workflow changes.

3. **Detach** with `Ctrl-b` then `d`. You are dropped back into the plain
   shell — no status bar. Close the tab, close Ghostty entirely, whatever:
   the session does not care.

4. **Check that it is alive:**
   ```bash
   tmux ls              # work: 1 windows (created ...)
   ```

5. **Reattach:**
   ```bash
   tmux attach -t work  # short form: tmux a -t work
   ```

6. **Prove it with pi, once.** Start a pi task, and while it is mid-answer,
   detach and reattach. The run never paused — that is the entire point.

## One-time setup: getting in from the phone

**On the Mac:**

1. System Settings → General → Sharing → turn on **Remote Login** (SSH).
2. Note your login: `whoami` (the user) and `scutil --get LocalHostName`
   (the machine's name).
3. Install **Tailscale** on the Mac and the phone and sign both into the same
   account. On your home Wi-Fi it is optional; away from home it is the safe
   path. **Never expose SSH to the internet.**
4. **Keep the Mac awake.** This is the number-one gotcha: a sleeping Mac
   refuses SSH. Sessions freeze and resume fine across sleep, but you cannot
   *connect* to a sleeping machine. Before walking away:
   ```bash
   caffeinate -dims -t 28800 &     # keep the Mac awake for 8 hours
   ```

**On the phone:**

5. Install a client: **Blink Shell** (iOS — mosh-aware, the best over
   cellular) or **Termius** (iOS/Android, free tier). On Android, **Termux**
   works too.
6. Add an SSH host `user@machinename` (or the Tailscale hostname) and connect
   once while sitting at the desk, to test.
7. The prompt you get is your normal one, plus the `user@host` segment it
   adds over SSH. Same shell, same history — by design, every terminal and
   every SSH session reads the same `~/.zshrc`.

## The handoff, end to end

**Leaving the desk:**

1. `Ctrl-b` `d` to detach. (Or simply close Ghostty — same result.)
2. Walk away. pi keeps running; nvim keeps its splits.

**From the phone:**

3. Open the SSH client and connect.
4. `tmux attach -t work`. If the desktop terminal is still attached, take
   over with `tmux attach -d -t work` — the `-d` kicks the other client off.
   Both can stay attached (the view mirrors to every client), but the most
   recent attacher sets the size for everyone (`window-size latest`, the
   default on tmux 3.7) — so when the phone attaches, the whole session
   goes phone-sized and the desktop view shrinks to a corner of its window.
   One device at a time is the comfortable arrangement.
5. Type to pi as usual. One honesty note: `Shift+Enter` (newline without
   submitting) needs the phone terminal to speak extended keys — Blink and
   Termius do; if yours does not, plain `Enter` still submits fine.
6. **Scrolling back:** `Ctrl-b` `[` enters copy/scroll mode — arrows or
   PgUp/PgDn move, `q` exits.
7. Done? `Ctrl-b` `d`, close the app, go to sleep. There is nothing to save
   and nothing to shut down.

**Back at the desk the next morning:**

8. Ghostty → `tmux attach -t work`. Same session, full size, history intact.

## Survival kit

The complete set of keys and commands this setup needs:

| Action | Keys / command |
|---|---|
| Detach | `Ctrl-b` `d` |
| Scroll / copy mode | `Ctrl-b` `[` (exit: `q`) |
| List sessions | `tmux ls` |
| Attach | `tmux a -t work` |
| Take over from another client | `tmux attach -d -t work` |
| New window — useful only on the phone, where you cannot open another Ghostty tab | `Ctrl-b` `c` (next `n`, previous `p`) |
| Retire a session for good | `tmux kill-session -t work` |

## Forgot to start under tmux?

No pi conversation is lost — every one auto-saves under
`~/.pi/agent/sessions/`. From any SSH session:

```bash
cd <project> && pi -c      # resume the most recent conversation there
pi -r                      # or pick one from a list
```

What comes back is the conversation and its context — not live process state.
An in-flight tool run or your open nvim splits do not come along. That is why
the habit is *always* start under tmux, and `pi -c` is the fallback, not the
plan.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| SSH times out; nothing responds | The Mac is asleep. Connect from somewhere it can wake (Tailscale + Wake-on-LAN), or prevent sleep next time with `caffeinate -dims`. |
| One screen shows the session shrunk into a corner | Another client attached after it and set the size for everyone (`window-size latest`, the default). `tmux attach -d -t work` from the device that should be full-size — it kicks the other off. |
| `no server running on /tmp/tmux-.../default` | No sessions exist — they were killed or the machine rebooted. `tmux new -s work` and start fresh. |
| Closed Ghostty mid-pi-run — is it lost? | No. Only `tmux kill-session`, a reboot, or killing the process ends a detached session. Closing a terminal never does. |
| `Shift+Enter` submits instead of newline (from the phone) | That client does not speak extended keys. Blink and Termius do; otherwise keep prompts single-line. |

---

Related: the repo README's "Picking up from another device" section is the
condensed version of this page; [tools.md](tools.md) has tmux's entry in the
tool inventory; [getting-started.md](getting-started.md) covers the daily
review loop this sits underneath.
