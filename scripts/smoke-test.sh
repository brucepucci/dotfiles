#!/usr/bin/env bash
# smoke-test.sh — from-scratch test of this dotfiles repo. No VM required.
#
# Applies the repo into a pristine throwaway HOME (exactly what a new
# machine receives), then exercises the result the way real sessions hit it:
#
#   1. chezmoi apply renders the full tree, from nothing
#   2. a fresh login shell (any new terminal window) gets the prompt,
#      shared HISTFILE, brew PATH, aliases, completion — and the right
#      EDITOR fallback when nvim is absent
#   3. a pre-unification Ghostty window (ZDOTDIR pointing at the legacy
#      directory) is repaired by the redirect guard
#   4. an SSH session gets the user@host prompt segment
#   5. history written in one shell is visible in a brand-new shell
#   6. ghostty's config contains no shell settings, and secrets are not
#      applied
#
# What this deliberately does NOT cover: brew bundle installs, GUI behavior
# of Ghostty/Terminal/iTerm2. For those, see the "Testing changes" section
# of the README (Linux VM via scripts/test-linux-vm.sh, macOS VM via tart).
#
# Usage:  scripts/smoke-test.sh [--nvim]
#   --nvim   also bootstrap Neovim plugins from scratch in the temp HOME
#            (~2 min, needs network). Without it the run takes seconds.
#
# Works on macOS and Linux (assertions adapt: e.g. EDITOR must fall back to
# vim when nvim is not resolvable — that guard branch is a test too).

set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-smoke.XXXXXX")"
NEWHOME="$WORK/home"
mkdir -p "$NEWHOME"
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n== %s\n' "$1"; }
ok()   { printf '  ok  %s\n' "$1"; }
die()  { printf '  FAIL %s\n' "$1" >&2; exit 1; }

# Run zsh the way a terminal emulator spawns it: scrubbed environment, the
# stock PATH a fresh login shell starts from. macOS /etc/zprofile
# (path_helper) and our ~/.zprofile rebuild the real PATH from there.
fresh_zsh() {
  env -i HOME="$NEWHOME" TERM=xterm-256color \
      PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
      /bin/zsh -l -i -c "$1" 2>/dev/null
}

WITH_NVIM=0
[[ "${1:-}" == "--nvim" ]] && WITH_NVIM=1

step "chezmoi apply into a pristine HOME"
chezmoi --source "$SOURCE" --destination "$NEWHOME" apply
[[ -z "$(chezmoi --source "$SOURCE" --destination "$NEWHOME" diff)" ]] \
  || die "chezmoi diff is not empty after apply"
for f in .zshrc .zprofile .config/zsh/ps1.zsh \
         .config/zsh-ghostty/.zshenv .config/ghostty/config \
         .config/nvim/init.lua .zsh/secrets.example.zsh; do
  [[ -f "$NEWHOME/$f" ]] || die "missing $f"
done
[[ ! -e "$NEWHOME/.zsh/secrets.zsh" ]] || die "~/.zsh/secrets.zsh was applied"
ok "full tree rendered, diff empty, no secrets applied"

step "ghostty config stays appearance-only"
if grep -E '^[[:space:]]*(command|env)[[:space:]]*=' "$NEWHOME/.config/ghostty/config" >/dev/null; then
  die "ghostty config sets a shell command/env line"
fi
ok "no command=/env= lines"

step "fresh login shell (new terminal window)"
out="$(fresh_zsh '
  echo "hist=$HISTFILE"
  echo "plen=${#PROMPT}"
  echo "zdot=${ZDOTDIR:-}"
  echo "editor=$EDITOR"
  echo "hasnvim=$(command -v nvim >/dev/null && echo yes || echo no)"
  echo "share=$( [[ -o sharehistory ]] && echo yes || echo no )"
  echo "alias=$(alias ll >/dev/null 2>&1 && echo yes || echo no)"
' || true)"
[[ "$out" == *"hist=$NEWHOME/.zsh_history"* ]] || die "HISTFILE not the shared one: $out"
[[ "$out" == *"zdot="$'\n'* ]] || [[ "$out" == *"zdot=
"* ]] || die "ZDOTDIR should be unset: $out"
plen="$(sed -n 's/^plen=//p' <<<"$out")"
(( plen > 50 )) || die "PROMPT looks like a default prompt (len $plen)"
editor="$(sed -n 's/^editor=//p' <<<"$out")"
hasnvim="$(sed -n 's/^hasnvim=//p' <<<"$out")"
if [[ "$hasnvim" == yes ]]; then
  [[ "$editor" == nvim ]] || die "EDITOR should be nvim when nvim resolves"
else
  [[ "$editor" == vim ]] || die "EDITOR should fall back to vim without nvim"
fi
[[ "$out" == *"share=yes"* ]] || die "SHARE_HISTORY not on"
[[ "$out" == *"alias=yes"* ]] || die "aliases missing"
[[ -f "$NEWHOME/.zcompdump" ]] || die "compinit did not run"
ok "prompt, shared history, options, aliases, completion, EDITOR=$editor (nvim=$hasnvim)"

step "legacy ZDOTDIR guard (pre-unification Ghostty window)"
# A Ghostty still running from before the unification exports ZDOTDIR at
# the legacy directory for every window it opens; the guard must repair it.
out="$(env -i HOME="$NEWHOME" TERM=xterm-256color \
      PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
      ZDOTDIR="$NEWHOME/.config/zsh-ghostty" \
      /bin/zsh -l -i -c '
        echo "zdot=${ZDOTDIR:-}"
        echo "hist=$HISTFILE"
        echo "plen=${#PROMPT}"
      ' 2>/dev/null || true)"
[[ "$out" == *"zdot="$'\n'* || "$out" == *"zdot=
"* ]] || die "guard did not unset ZDOTDIR: $out"
[[ "$out" == *"hist=$NEWHOME/.zsh_history"* ]] || die "guarded shell has wrong HISTFILE: $out"
plen="$(sed -n 's/^plen=//p' <<<"$out")"
(( plen > 50 )) || die "guarded shell fell back to default prompt"
ok "stale ZDOTDIR is redirected to the real config"

step "SSH session prompt"
out="$(env -i HOME="$NEWHOME" TERM=xterm-256color \
      PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
      SSH_CONNECTION="203.0.113.9 51234 192.168.4.32 22" \
      /bin/zsh -l -i -c 'print -P "$PROMPT" | grep -q "@" && echo seg=yes' \
      2>/dev/null || true)"
[[ "$out" == *"seg=yes"* ]] || die "SSH prompt lacks user@host segment"
ok "user@host segment present over SSH"

step "history shared across separate shells"
TOKEN="smoke-$(date +%s)-$RANDOM"
fresh_zsh "print -S '$TOKEN'" >/dev/null 2>&1 || true
[[ -f "$NEWHOME/.zsh_history" ]] || die "first shell did not write HISTFILE"
# Drive the second shell from stdin, not -c: SHARE_HISTORY imports the file
# at each command-line read, which a -c one-shot never reaches -- a real
# terminal session does, so that is what we emulate here.
out="$(printf 'fc -l | grep -q %s && echo found=yes\nexit\n' "$TOKEN" \
      | env -i HOME="$NEWHOME" TERM=xterm-256color \
          PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
          /bin/zsh -l -i 2>/dev/null || true)"
[[ "$out" == *found=yes* ]] || die "history not shared between shells"
ok "written in one shell, visible in the next"

if [[ "$WITH_NVIM" == 1 ]]; then
  step "neovim bootstrap from scratch (--nvim)"
  HOME="$NEWHOME" nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 \
    || die "Lazy restore failed"
  [[ -d "$NEWHOME/.local/share/nvim/lazy" ]] \
    || die "plugins were not installed into the temp HOME"
  ok "plugins restored from lazy-lock.json into pristine HOME"
fi

printf '\nALL PASS\n'
