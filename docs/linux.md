# Linux (the `linux` branch)

`main` is macOS-only and says so — that scope is deliberate and this branch
does not change it. This branch is the same config running on a
Fedora-family Linux desktop (developed on **Bazzite 44**, GNOME/Wayland,
an rpm-ostree image), with the macOS assumptions turned into runtime
probes rather than rewritten.

**Keep it a branch.** Merge updates from `main` into `linux` and keep
Linux-specific changes off `main`.

## What actually differs

| Where | macOS | Linux | Kind |
|---|---|---|---|
| `dot_zprofile`, `dot_zshrc.tmpl` | `/opt/homebrew`, `/usr/local` | + `/home/linuxbrew/.linuxbrew`, `~/.linuxbrew` | one more branch in an existing ladder |
| `dot_zshrc.tmpl` clipboard | `pbcopy` / `pbpaste` | `wl-copy` / `wl-paste`, then `xclip`, then `xsel` | probed backend |
| `dot_local/bin/executable_delta-theme.tmpl` | `defaults read -g AppleInterfaceStyle` | `gsettings get org.gnome.desktop.interface color-scheme` | probed detection |
| `nvim core/appearance.lua` | same `defaults` call | same `gsettings` call | probed detection |
| the terminal | Ghostty + `~/.config/ghostty/` | **Ptyxis** + a generated palette | different app, same idea |
| `Brewfile` | Ghostty, Herdr Desktop, and font casks | zsh and wl-clipboard formulae | Homebrew has no Linux casks |
| the Nerd Font | a cask | `scripts/install-nerd-font.sh` | the cask's replacement |
| `scripts/themes-sync.sh` | bsdtar globs by default | GNU tar needs `--wildcards` | probed |
| `scripts/smoke-test.sh` | `/bin/zsh` hardcoded | `$ZSH`, resolved once | resolved, not branched |
| `dot_zshrc.tmpl` banner | fastfetch's own os-release logo | + Bazzite's ASCII when `/usr/share/ublue-os/bazzite/logo.txt` exists | probed |

The core editor, shell, tmux, and theme configuration still come from
`main`. On Linux, Pi defaults to the `openai` provider used by current Pi
for ChatGPT sign-in. The local skills checkout is optional on this branch.

## The terminal: Ptyxis instead of Ghostty

Ghostty is not packaged for Fedora (only community COPRs), and on an
immutable image adding one means layering a third-party repo plus a reboot.
Ptyxis — GNOME's terminal, Bazzite's default — is already there, and it
turns out to model appearance the same way Ghostty does:

- Ghostty: `theme = light:dotfiles-light,dark:dotfiles-dark`, two generated
  theme files, and it picks a side from the OS.
- Ptyxis: **one** generated palette holding a `[Light]` and a `[Dark]`
  section, and it picks a side from `interface-style`.

So the same two theme names in `settings.toml` still drive everything, and
`theme = "light"` / `"dark"` still pins the whole stack — the palette
renders the *same* theme into both sections when pinned, so the pin holds
even if someone flips GNOME's appearance toggle.

Two managed pieces:

- `dot_local/share/org.gnome.Ptyxis/palettes/dotfiles.palette.tmpl` →
  `~/.local/share/org.gnome.Ptyxis/palettes/dotfiles.palette`
- `run_onchange_after_10-ptyxis.sh.tmpl` — Ptyxis keeps settings in dconf,
  not a file, so the equivalent of Ghostty's config line is three
  `gsettings` writes: the palette (on every profile, not just the default),
  the Nerd Font, and which side to show. It re-runs when `settings.toml`
  changes, and exits 0 having done nothing on a machine without Ptyxis.

The shared Ghostty files are rendered for anyone using Ghostty separately;
this branch does not install or require the app.

## New machine

Same shape as the README's six steps, with the Linux substitutions.

```bash
# 0. Homebrew. Bazzite and the other ublue images ship it already; check
#    with `command -v brew` before running this.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 1. Install chezmoi and the GitHub CLI.
brew install chezmoi gh
# Optional: authenticate if you also plan to push changes.
# gh auth login
# gh auth setup-git

# 2. Initialize a new chezmoi source directly on this branch.
chezmoi init --branch linux https://github.com/brucepucci/dotfiles.git

# 3. Everything the config needs (adds zsh and wl-clipboard, skips Mac casks).
brew bundle --file="$(chezmoi source-path)/Brewfile"

# 4. The Nerd Font -- the cask's replacement, run by hand because it
#    reaches the network.
"$(chezmoi source-path)/scripts/install-nerd-font.sh"

# 5. From a terminal in the GNOME session, preview and apply.
chezmoi diff
chezmoi apply

# 6. Plugins, at the revisions pinned in lazy-lock.json.
nvim --headless "+Lazy! restore" +qa

# 7. Secrets (never in git).
cp ~/.zsh/secrets.example.zsh ~/.zsh/secrets.zsh
chmod 600 ~/.zsh/secrets.zsh
$EDITOR ~/.zsh/secrets.zsh

# 8. Make zsh the login shell. macOS ships zsh as the default and needs no
#    step here; a Fedora desktop defaults to bash. NOTE: `chsh` is NOT the
#    command to reach for -- it lives in util-linux-user, which Bazzite and
#    the other ublue images do not ship (and layering a package to change
#    one passwd field is not worth a reboot). shadow-utils' usermod is
#    installed and does the same thing.
echo "$(brew --prefix)/bin/zsh" | sudo tee -a /etc/shells
sudo usermod -s "$(brew --prefix)/bin/zsh" "$USER"
getent passwd "$USER"        # confirm the last field changed
#    Log out and back in -- a login shell is read at session start.
```

> `usermod` does not validate against `/etc/shells` the way `chsh` does, so
> the `tee` line is not load-bearing for the change itself. Add it anyway:
> other tools (some terminal emulators, `lchsh`, a later `chsh` if the
> package ever lands) do check, and a login shell missing from that file
> reads as "this account is not meant to log in".

Order still matters for the same reasons as on the Mac (step 3 before
step 5; `Lazy! restore` needs `tree-sitter`), plus one new one: run the
font script before `chezmoi apply`. If the first apply already ran without
the font, select **JetBrainsMono Nerd Font 12** in Ptyxis Preferences after
installing it. Desktop settings are not changed when a different destination
is selected or when there is no desktop session bus.

Sign in to Pi locally with `/login` and install its npm packages as described
in [Pi packages](pi.md#packages-npm-extensions). Herdr Desktop is optional:
install it separately and onboard core in the app; chezmoi only supplies the
shared theme, telemetry setting, and word-key patch. Account credentials,
sessions, app runtime state, and the machine-local chezmoi snapshot are not
part of this branch. If you already use a local snapshot, don't reinitialize
or apply over it without reviewing how you want to migrate those settings.

## Notes and gotchas

- **The login shell lives under Homebrew.** `/home/linuxbrew/.linuxbrew/bin/zsh`
  in `/etc/shells` is a working, if unusual, choice; on an rpm-ostree
  system `/etc` is writable, so this survives updates. Layering the distro
  `zsh` with `rpm-ostree install zsh` is the alternative — it needs a
  reboot, and `~/.zprofile` finds Homebrew either way.
- **There is no `chsh` here.** It ships in `util-linux-user`, which is not
  in the base image; `sudo usermod -s <shell> "$USER"` is the replacement
  (step 8 above). Worth knowing before reaching for the command every
  other Linux guide tells you to run.
- **wl-clipboard needs a graphical session.** `clipcopy`/`clippaste` probe
  for a backend at rc load and say so plainly when there is none, rather
  than dying inside a pipe — an SSH session into this box has no display,
  and that is the honest answer there. tmux's OSC 52 copy-mode is still the
  path for getting text onto the *connecting* device's clipboard.
- **`wl-copy` forks.** The Wayland clipboard belongs to a live client, so
  `wl-copy` daemonizes and keeps serving paste requests — and that daemon
  inherits the caller's stdout and stderr. Without redirecting them,
  `printf x | clipcopy` inside a command substitution or a captured
  pipeline blocks until the next copy. `__clip_copy_run` in `~/.zshrc`
  hands the forking backends `/dev/null` and reports failure from the exit
  status instead. `pbcopy` does not fork and keeps its own diagnostics.
- **fastfetch has no bazzite logo.** `--list-logos` carries the Fedora
  family and nothing else from ublue, so `ID_LIKE="fedora"` in
  `/etc/os-release` makes a bare `fastfetch` draw stock Fedora — true of
  the base image, wrong for the machine in front of you. The greeting
  block passes `--logo /usr/share/ublue-os/bazzite/logo.txt` when the file
  is readable. Deliberately the logo *only*: the distro's own
  `/etc/profile.d/bazzite-neofetch.sh` aliases `fastfetch` to its full
  `fastfetch.jsonc` (a different module list, Nerd Font icon keys, and a
  truecolor tint read from the GNOME accent color), and hex in the shell
  is what the color system exists to avoid. That alias never reaches this
  setup anyway — `profile.d` is read by bash login shells, and there is no
  `/etc/zprofile` or `/etc/zshenv` on this box.
- **`/home` is a symlink to `/var/home`** on ostree systems. chezmoi's
  `sourceDir` should name one of them consistently; mixing the two makes
  `chezmoi diff` look like it has drifted when it has not.
- **Run `scripts/smoke-test.sh`** for offline rendering and shell checks.
  The Pi extension harnesses use `brew --prefix pi-coding-agent` to find
  the package (`PI_PACKAGE_DIR` overrides it for other installs).

## Not carried over

- **The macOS VM tier** (`tart`) of the test pyramid in
  `docs/developing.md`. The Linux equivalent would be a container or a
  disposable VM; tier 1 (`scripts/smoke-test.sh`) is what runs today.
- **CI.** `.github/workflows/smoke.yml` still targets `macos-latest`,
  because it belongs to `main`. A `ubuntu-latest` job for this branch is
  the obvious addition and has not been made.
