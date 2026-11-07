# Herdr — desktop app + core

[Herdr](https://herdr.dev) is one stack here: **herdr-app**, the native
macOS desktop client, backed by **herdr-core** and its `hc` CLI. Core owns
the terminals; the app is a view onto them. The legacy `herdr` terminal
UI is retired, not a second supported interface.

## Install and updates

```bash
brew bundle --file="$(chezmoi source-path)/Brewfile"   # includes cask herdr-app
# Or install just the app:
brew install --cask herdr-app
```

The cask installs the app and `herdr-app` command, **not core**. Open Herdr
and explicitly click **Install it for me** in first-launch onboarding to
install core, then verify `hc --version`. This required interactive step
is the supported setup; no extra setup script is needed. **There is no
`herdr-core` Homebrew formula**. Apply neither installs the backend nor
runs a downloaded installer.

Homebrew provides app installation, not exclusive update ownership. The
cask declares `auto_updates true`; use the vendor app's update UI for
ongoing app and compatible core updates. Bulk `brew upgrade` normally
skips auto-updating casks. See the tagged app implementation:
[setup.rs](https://github.com/herdrdev/herdr-app/blob/v0.1.13/src/setup.rs),
[core_bin.rs](https://github.com/herdrdev/herdr-app/blob/v0.1.13/src/core_bin.rs),
and [update.rs](https://github.com/herdrdev/herdr-app/blob/v0.1.13/src/update.rs).

Core's default login shell reads the same `~/.zprofile` and `~/.zshrc` as
other terminals. No custom shell command or core config is needed here.
Create a terminal in the app, change to a project, and run `pi`.

## Managed boundary

`private_dot_config/herdr-app/settings.json.tmpl` renders
`~/.config/herdr-app/settings.json` with telemetry off and the generated
light/dark theme pair. In system mode:

```json
{"telemetry":false,"theme":{"light":"dotfiles-light","dark":"dotfiles-dark"}}
```

System mode omits `appearance`, so Herdr follows live OS appearance.
Pinned `theme = "light"` or `"dark"` adds the matching `appearance` value.

The app can rewrite this file when preferences such as zoom change.
Apply restores the repo's version; fold GUI preferences you want to keep
back into the source instead of expecting them to survive apply.

Only settings and the exact `themes/dotfiles-{light,dark}.json` files are
allowlisted for management/import, not the whole themes directory. App keys,
other themes, runtime/state (including layout geometry), and core config
remain unmanaged. Apply does not stop services, uninstall software, or erase
runtime directories.

## Appearance

`settings.toml` is the single appearance input, just like Ghostty. The two
generated native Herdr themes use the same resolved background, foreground,
cursor, selection background, and ANSI slots 0–15. Herdr derives its UI from
those terminal palettes; there is no independent Herdr palette or theme knob.
Rendering uses `scripts/theme.py` and the committed mirror, needing neither
network nor an installed app. See [theming.md](theming.md).

Use the default **main** layout to follow repo themes. Independently themed
layouts can override app settings; use main/default or deliberately clear
only that custom layout's root `theme`/`colors` overrides.

A theme-picker choice saves a top-level `theme` in the active layout's state
file, taking precedence over layout/settings themes. To return to repo themes:

1. Quit the app normally and back up that state file.
2. Remove **only** its top-level `theme` property, preserving `nodes`,
   `floats`, `file`, and all other state.
3. Restart the app.

There is no dedicated reset command. Apply leaves state/layout geometry
untouched; never reset/delete whole runtime directories for a theme change.

## pi inside Herdr

A nonempty `HC_TERMINAL_ID` makes the `pi()` wrapper skip tmux, even with
`PI_TMUX_WRAP=force`. An empty marker does not bypass wrapping. The old
`HERDR_ENV` marker has no special meaning. See [pi.md](pi.md).

Pi 1.5 reports agent state natively through the Program Status Protocol
(OSC 7501). Core receives those reports directly; **no legacy integration
extension is needed**. tmux blocks both the protocol handshake and status
reports, so Pi inside tmux may be absent from the app's Agents panel.
Launch directly in a core terminal instead of layering tmux underneath it.
Pi's indexed theme slots follow the viewing Herdr terminal's generated
palette, with the existing xterm-cube/tool-tint/sparse-theme exceptions
explained in [theming.md](theming.md#the-ssh-rule-indexed-colors-not-hexes).

After applying, open a new shell in the app (or source `~/.zshrc`) and
launch Pi outside any existing tmux session. Applying cannot move an
already-running Pi out of tmux. `hc get <terminal-id>` shows the core's
observed process and agent status.

## Persistence and remote access

- **Close the app:** core terminals and their processes keep running.
  Reopening the app reconnects to them.
- **Core updates:** running terminals are preserved across supported core
  updates; updating the backend is not the same as rebooting the Mac.
- **Reboot or loss of a terminal's program:** recovery restores kept shells,
  not running agents; it does not automatically rerun Pi. Use `pi -c` or
  `pi -r` to resume saved conversation context explicitly.
- **Another device:** this desktop app is not an SSH TUI. Keep the
  [tmux workflow](tmux.md) outside the app for SSH-first conversations,
  or use `hc attach <terminal-id>` to attach to a core terminal from a
  shell on the Mac. Access/security setup remains in the private
  [ssh-setup runbook](https://github.com/brucepucci/ssh-setup), not here.

## Migrate from the legacy TUI

Do this deliberately; apply performs only file cleanup, not process
migration. Install the desktop/core stack above and verify bare Pi appears
in its Agents panel before retiring the old workflow. Then open the old
`herdr` UI, inspect **all live sessions**,
and finish or safely stop work you need to preserve. Saved Pi transcripts
can be resumed later, but running processes cannot be transferred to core.
The legacy formula defines no Homebrew service. After finishing those
sessions, manually stop its daemon and uninstall the formula:

```bash
herdr server stop                 # destructive to any remaining live sessions
brew uninstall --formula herdr
```

Neither command is automated by apply. No broad `brew cleanup` or
runtime deletion is part of migration. Keep the old logs/session state
until you have verified the new stack; never remove the whole
`~/.config/herdr` directory as an apply step.

Apply the **checkout containing this migration**. The default chezmoi
source is `~/.local/share/chezmoi`; a separate checkout does not become the
source merely because it is the current directory. For this checkout:

```bash
brew bundle --file=/Users/bp/gh/dotfiles/Brewfile
chezmoi --source=/Users/bp/gh/dotfiles diff
chezmoi --source=/Users/bp/gh/dotfiles apply
```

No global chezmoi source change is needed. Apply removes only these legacy
Herdr targets (alongside unrelated retirements already listed in
`.chezmoiremove`):

- `~/.config/herdr/config.toml`
- `~/.pi/agent/extensions/herdr-agent-state.ts`

It preserves legacy runtime/state and unrelated Pi extensions, and leaves
app keys/state and core settings alone. Restart Pi or run `/reload` to
unload the removed extension; open a fresh app shell to pick up the new
wrapper. Confirm the app's Agents panel still receives Pi's native status.
