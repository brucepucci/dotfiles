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
#   7. the prompt's git-state markers keep their spacing in every state
#      (clean / staged / both) -- each marker carries its own leading space
#   8. exactly one blank line lands between command output and the next
#      prompt -- and none before the first prompt, on empty prompts, or
#      after `clear`
#   9. the light/dark mode wiring: ghostty's theme line (pair when
#      theme = "system", single when pinned), nvim's mode module, and the
#      delta-theme wrapper (exercised with fake `defaults`/`delta` shims,
#      so no GUI toggling is required)
#  10. the color system: the chosen theme names resolve from Ghostty's
#      own catalog (via the same script the templates call), no rendered
#      output carries a hex the themes don't define, and nvim's
#      generated data module carries the chosen roles verbatim
#  11. the tmux config renders with pi's requirements intact: extended
#      keys (Shift+Enter survives the tmux layer), OSC 52 clipboard,
#      truecolor passthrough, mouse-wheel copy-mode scrollback, status-bar
#      window separator — file-shape only; no tmux binary needed
#  12. the pi wrapper: `pi` always CREATES a session (never attaches —
#      rejoining is manual `tmux attach`), names it after the project dir
#      (-2/-3 on collision) or the sanitized -n topic, and falls through
#      to plain pi inside tmux / without the binary / from $HOME / for
#      one-shot -p runs — exercised with fake tmux+pi shims
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
         .config/nvim/init.lua .zsh/secrets.example.zsh \
         .tmux.conf; do
  [[ -f "$NEWHOME/$f" ]] || die "missing $f"
done
# tmux.conf carries pi's documented requirements (docs/tmux.md bundled with
# the agent) plus the passthrough settings the color system needs under
# tmux. Checked by shape so CI needs no tmux binary.
grep -q '^set -g extended-keys on$' "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: extended-keys off -- pi Shift+Enter breaks under tmux"
grep -q '^set -g extended-keys-format csi-u$' "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: extended-keys-format must be csi-u (tmux >= 3.5)"
grep -q '^set -g set-clipboard on$' "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: OSC 52 clipboard off -- yanks never reach remote clients"
grep -qF "set -ga terminal-overrides ',*:RGB'" "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: no truecolor passthrough -- nvim colors downgrade under tmux"
grep -q '^set -g focus-events on$' "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: focus-events off -- nvim appearance sync and checktime never fire under tmux"
grep -q '^set -g mouse on$' "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: mouse off -- the wheel arrives as arrow keys; no scrollback under tmux"
grep -q '^set -g history-limit 10000$' "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: history-limit not 10000 -- the 2000 default truncates pi sessions"
grep -qF "set -g window-status-format ' | #I:#W#{?window_flags,#{window_flags}, }'" \
  "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: window list blends into the session name -- chezmoi-2 + 0 scans as chezmoi-20"
grep -qF "set -g window-status-current-format ' | #I:#W#{?window_flags,#{window_flags}, }'" \
  "$NEWHOME/.tmux.conf" \
  || die "~/.tmux.conf: current-window entry lacks the separator -- session name blends into the window index"
[[ ! -e "$NEWHOME/.zsh/secrets.zsh" ]] || die "~/.zsh/secrets.zsh was applied"
ok "full tree rendered, diff empty, no secrets applied"

step "ghostty config stays appearance-only"
if grep -E '^[[:space:]]*(command|env)[[:space:]]*=' "$NEWHOME/.config/ghostty/config" >/dev/null; then
  die "ghostty config sets a shell command/env line"
fi
ok "no command=/env= lines"

step "light-mode: the whole stack follows the appearance setting"
# theme lookup helpers: the same resolver the templates call at apply time.
# Settings come from theme.toml (the user-facing file at the repo root).
themeset() { python3 "$SOURCE/scripts/ghostty-theme.py" --setting "$1"; }
themeget() { python3 "$SOURCE/scripts/ghostty-theme.py" --get "$@"; }
MODE="$(themeset theme)"
LTHEME="$(themeset light_theme)"
DTHEME="$(themeset dark_theme)"
[[ "$MODE" == system || "$MODE" == light || "$MODE" == dark ]] \
  || die "theme.toml: theme must be system|light|dark, got: $MODE"
# Ghostty is the anchor: one theme line, pair when following the OS, single
# theme when pinned.
if [[ "$MODE" == system ]]; then
  want_theme="theme = light:$LTHEME,dark:$DTHEME"
else
  want_theme="theme = $([[ $MODE == light ]] && echo "$LTHEME" || echo "$DTHEME")"
fi
[[ "$(grep '^theme = ' "$NEWHOME/.config/ghostty/config")" == "$want_theme" ]] \
  || die "ghostty theme line does not match the palette settings"
# Neovim: 'background' comes from the mode (OS when system) at startup,
# re-checked on focus.
[[ -f "$NEWHOME/.config/nvim/lua/bruce/core/appearance.lua" ]] \
  || die "nvim core/appearance.lua missing"
grep -q "mode = \"$MODE\"" "$NEWHOME/.config/nvim/lua/bruce/core/theming.lua" \
  || die "nvim theming.lua mode does not match the palette setting"
grep -q 'bruce.core.appearance' "$NEWHOME/.config/nvim/init.lua" \
  || die "init.lua does not sync the OS appearance"
grep -q 'FocusGained' "$NEWHOME/.config/nvim/lua/bruce/core/autocmds.lua" \
  || die "no FocusGained re-sync of the appearance"
# delta: git and lazygit render through the appearance-aware wrapper.
[[ -x "$NEWHOME/.local/bin/delta-theme" ]] \
  || die "~/.local/bin/delta-theme missing or not executable"
grep -q $'^\tpager = delta-theme$' "$NEWHOME/.gitconfig" \
  || die "git core.pager is not delta-theme"
grep -q 'command: delta-theme --paging=never' "$NEWHOME/.config/lazygit/config.yml" \
  || die "lazygit does not render through delta-theme"
# pi: the pair when following the OS, one theme when pinned; files are
# named dotfiles-{light,dark} regardless of which themes are active.
if [[ "$MODE" == system ]]; then want_pi="dotfiles-light/dotfiles-dark"
elif [[ "$MODE" == light ]]; then want_pi="dotfiles-light"
else want_pi="dotfiles-dark"; fi
[[ "$(sed -n 's/.*"theme": "\([^"]*\)".*/\1/p' "$NEWHOME/.pi/agent/settings.json")" == "$want_pi" ]] \
  || die "pi TUI theme setting does not match the mode"
for t in dotfiles-light dotfiles-dark; do
  [[ -f "$NEWHOME/.pi/agent/themes/$t.json" ]] \
    || die "pi theme $t.json missing from ~/.pi/agent/themes"
done
out="$(fresh_zsh '[[ $path[(r)$HOME/.local/bin] ]] && echo lbin=yes')"
[[ "$out" == *lbin=yes* ]] || die "login PATH does not include ~/.local/bin"
# The wrapper itself, hermetically: fake `defaults` + fake `delta`, both
# shadowed per state so the real OS appearance cannot leak into the result.
# In system mode both states are exercised; pinned modes must ignore the OS.
wrap="$WORK/wrap"
for st in dark light; do
  mkdir -p "$wrap/$st"
  printf '#!/bin/sh\nprintf "ARGV:%%s\\n" "$@"\n' > "$wrap/$st/delta"
  if [[ $st == dark ]]; then printf '#!/bin/sh\necho Dark\n' > "$wrap/$st/defaults"
  else printf '#!/bin/sh\nexit 1\n' > "$wrap/$st/defaults"; fi
  chmod +x "$wrap/$st/defaults" "$wrap/$st/delta"
done
ddark="none"; dlight="none"   # delta's syntax theme: always none -- diffs
                            # render in the terminal's own palette
run_case() { # $1 = expected wrapper state, $2 = simulated OS state
  out="$(env PATH="$wrap/$2:/usr/bin:/bin" \
        "$NEWHOME/.local/bin/delta-theme" extra </dev/null | tr '\n' ' ')"
  local syn; [[ $1 == dark ]] && syn="$ddark" || syn="$dlight"
  [[ "$out" == "ARGV:--$1 ARGV:--syntax-theme ARGV:$syn ARGV:extra " ]] \
    || die "delta-theme: mode=$MODE wanted=$1 os=$2 rendered: $out"
}
if [[ "$MODE" == system ]]; then
  run_case dark dark
  run_case light light
elif [[ "$MODE" == light ]]; then
  run_case light dark; run_case light light   # pinned: OS must not matter
else
  run_case dark dark; run_case dark light
fi
ok "ghostty theme line, nvim mode, delta wrapper, pi pair all match the settings"

step "colors: themes resolve on the fly, no orphan hexes"
# The palette system: 3 settings (theme.toml, repo root) and NO cached
# theme data -- templates resolve each name at apply time via
# scripts/ghostty-theme.py, straight from Ghostty's own catalog. Guards, in order: both names
# resolve (this is the same call the templates make); every hex in a
# rendered output is one the resolved themes define (including files that
# should hold none); rendered surfaces carry the chosen themes' roles
# verbatim, not strays.
themeget "$LTHEME" roles.bg >/dev/null \
  || die "light_theme '$LTHEME' does not resolve (is Ghostty installed?)"
themeget "$DTHEME" roles.bg >/dev/null \
  || die "dark_theme '$DTHEME' does not resolve (is Ghostty installed?)"
# Every hex in any color-carrying output must come from the resolved
# themes -- including files that should hold none today (ps1, ghostty
# config, gitconfig, delta-theme, the static nvim files): a hardcoded color
# anywhere defeats the whole single-source design.
palhex="$(python3 "$SOURCE/scripts/ghostty-theme.py" --hexes "$LTHEME" "$DTHEME")"
for f in "$NEWHOME/.pi/agent/themes/dotfiles-light.json" \
         "$NEWHOME/.pi/agent/themes/dotfiles-dark.json" \
         "$NEWHOME/.config/nvim/lua/bruce/core/theming.lua" \
         "$NEWHOME/.config/zsh/ps1.zsh" \
         "$NEWHOME/.config/nvim/lua/bruce/plugins/ui.lua" \
         "$NEWHOME/.config/nvim/lua/bruce/colors/scheme.lua" \
         "$NEWHOME/.config/ghostty/config" \
         "$NEWHOME/.gitconfig" \
         "$NEWHOME/.tmux.conf" \
         "$NEWHOME/.local/bin/delta-theme"; do
  [[ -f "$f" ]] || die "expected rendered output missing: $f"
  for h in $(grep -hoE '#[0-9a-fA-F]{6}' "$f" | sort -u); do
    grep -qxF "$h" <<<"$palhex" \
      || die "$(basename "$f") carries hex $h, not defined by the active themes"
  done
done
# The rendered nvim data module must carry the chosen themes' roles verbatim.
for side in light dark; do
  t="$( [[ $side == light ]] && echo "$LTHEME" || echo "$DTHEME" )"
  for role in bg fg red blue; do
    want="$(themeget "$t" "roles.$role")"
    grep -q "[[:space:]]$role = \"$want\"" "$NEWHOME/.config/nvim/lua/bruce/core/theming.lua" \
      || die "theming.lua $side.$role does not match the $t roles"
  done
done
ok "themes resolve, no orphan hexes, roles verbatim"

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

step "prompt git-state glyphs keep their spacing"
# The staged/unstaged markers carry their own leading space (issue #5): they
# must never render touching each other or the branch name, and a clean tree
# must carry neither glyph nor a stray gap. Branch name is irrelevant to the
# assertions, so CI's git default (master) is fine.
grepo="$WORK/grepo"
git init -q "$grepo"
git -C "$grepo" -c user.email=smoke@t -c user.name=smoke commit -q --allow-empty -m x
run_vcs() { (cd "$grepo" && zsh -c '
  source "'$NEWHOME'"/.config/zsh/ps1.zsh
  vcs_info; print -r -- "$vcs_info_msg_0_"'); }
msg="$(run_vcs)"
[[ "$msg" == *" ○"* || "$msg" == *" ●"* ]] && die "clean tree shows markers: $msg"
echo x >"$grepo/f" && git -C "$grepo" add f
msg="$(run_vcs)"
[[ "$msg" == *" ●"* && "$msg" != *"○"* ]] || die "staged-only state wrong: $msg"
echo y >>"$grepo/f"
msg="$(run_vcs)"
[[ "$msg" == *" ○"* && "$msg" == *" ●"* ]] || die "markers lost their gap: $msg"
ok "glyphs separated; clean tree clean"

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

step "one blank line before each prompt after output"
# Locks in the fix for #4 plus the clear/Ctrl-L refinement. Drive a real
# interactive shell over stdin with an isolated ZDOTDIR whose .zshrc only
# sources the applied ps1.zsh: two commands must each be followed by exactly
# one blank line (2 total), Enter-only prompts add none, the session must not
# open with one, and `clear` must not leave one at the top of the cleared
# screen. Output is captured to a file (command substitution would strip the
# trailing blank) and ANSI escapes are stripped before counting -- they are
# invisible in a terminal but would otherwise mask the clear blank-line bug,
# because `clear` emits no trailing newline for the prompt's print to occupy.
zdot="$WORK/zdot"; mkdir -p "$zdot"
printf '%s\n' "source $NEWHOME/.config/zsh/ps1.zsh" > "$zdot/.zshrc"
printf 'echo one\nclear\n\n\necho two\nexit\n' \
  | env -i HOME="$NEWHOME" ZDOTDIR="$zdot" TERM=xterm-256color \
      PATH="/usr/bin:/bin" /bin/zsh -i > "$WORK/prompt-out" 2>/dev/null || true
LC_ALL=C sed $'s/\x1b\[[0-9;]*[A-Za-z]//g' "$WORK/prompt-out" > "$WORK/prompt-visual"
out="$(cat "$WORK/prompt-visual")"
[[ "$(sed -n 1p "$WORK/prompt-visual")" == one ]] || die "session opens with a blank line: $out"
blanks="$(grep -c '^$' "$WORK/prompt-visual")"
(( blanks == 2 )) || die "want exactly 2 blank lines (one per command, none after clear), got $blanks: $out"
ok "2 commands -> 2 blank lines; clear and empty prompts add none"

if [[ "$WITH_NVIM" == 1 ]]; then
  step "neovim bootstrap from scratch (--nvim)"
  HOME="$NEWHOME" nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 \
    || die "Lazy restore failed"
  [[ -d "$NEWHOME/.local/share/nvim/lazy" ]] \
    || die "plugins were not installed into the temp HOME"
  ok "plugins restored from lazy-lock.json into pristine HOME"
fi

step "pi wrapper: new sessions only, named after the project or topic"
# The wrapper in .zshrc: `pi` always starts a NEW tmux session wrapped
# around a new pi conversation -- rejoining is explicit `tmux attach -t`,
# which lands straight inside the running pi. Fake tmux/pi shims stand in
# for the real binaries; PI_TMUX_WRAP=force substitutes for the tty this
# harness cannot provide (that one branch runs for real in manual use).
wbin="$WORK/wbin"; mkdir -p "$wbin"
SESS="$WORK/wrap-sessions"; TLOG="$WORK/wrap-tmux.log"; PLOG="$WORK/wrap-pi.log"
: > "$SESS"; : > "$TLOG"; : > "$PLOG"
cat > "$wbin/tmux" <<SH
#!/usr/bin/env bash
# fake tmux: has-session/list-sessions read \$FAKE_SESS (one name/line);
# new-session records its argv in \$FAKE_LOG and mints the name.
case "\$1" in
  has-session)   grep -qxF "\${3#=}" "\$FAKE_SESS" && exit 0; exit 1 ;;
  list-sessions) cat "\$FAKE_SESS" ;;
  new-session)
    printf '%s\n' "\$*" >> "\$FAKE_LOG"
    while [[ \$# -gt 0 ]]; do
      [[ \$1 == -s ]] && printf '%s\n' "\$2" >> "\$FAKE_SESS"
      shift
    done ;;
esac
SH
cat > "$wbin/pi" <<SH
#!/bin/sh
echo "pi \$*" >> "\$FAKE_PI"
SH
chmod +x "$wbin/tmux" "$wbin/pi"
wrap_zsh() {  # $1 = cwd, $2 = pi args (single-quoted inside the payload)
  env -i HOME="$NEWHOME" TERM=xterm-256color SHELL=/bin/zsh \
      PATH="$wbin:/usr/bin:/bin" FAKE_SESS="$SESS" FAKE_LOG="$TLOG" \
      FAKE_PI="$PLOG" PI_TMUX_WRAP=force \
      /bin/zsh -l -i -c "PATH=\"$wbin:/usr/bin:/bin\"; cd '$1' && pi $2" 2>&1
}
proj="$WORK/demoproj"; mkdir -p "$proj"
# 1. topic-named session, args passed through, hint printed
rc=0; out="$(wrap_zsh "$proj" "-n 'Auth Refactor'")" \
  || { rc=$?; die "case-1 inner zsh exited $rc -- output: $out"; }
grep -qF 'new-session -s auth-refactor command pi -n Auth\ Refactor' "$TLOG" \
  || die "topic naming/passthrough wrong: $(tail -1 "$TLOG")"
grep -qxF auth-refactor "$SESS" || die "topic session not minted"
[[ "$(cat "$PLOG")" == "" ]] || die "fake pi must not run at wrapper time"
[[ "$out" == *'detach Ctrl-b d'* ]] || die "creation hint missing: $out"
# 2. default name from the project dir; numbered siblings on collision
: > "$TLOG"; printf 'demoproj\ndemoproj-2\n' > "$SESS"
rc=0; out2="$(wrap_zsh "$proj" "")" \
  || { rc=$?; die "case-2 inner zsh exited $rc -- output: $out2"; }
grep -qF 'new-session -s demoproj-3 command pi' "$TLOG" \
  || die "collision numbering wrong: $(tail -1 "$TLOG")"
# 3. an explicitly taken topic refuses -- nothing silently renamed
: > "$TLOG"; printf 'auth-refactor\n' > "$SESS"
rc=0; out="$(wrap_zsh "$proj" '-n auth-refactor')" || rc=$?
(( rc != 0 )) || die "taken topic should exit nonzero"
[[ ! -s "$TLOG" ]] || die "taken topic must not create a session"
[[ "$out" == *'tmux attach -t auth-refactor'* ]] || die "rejoin hint missing: $out"
# 4. guards: all fall through to plain pi, never touching tmux
guard_plain() {  # $1 = extra env, $2 = pi args
  : > "$TLOG"; : > "$PLOG"
  env -i HOME="$NEWHOME" TERM=xterm-256color SHELL=/bin/zsh \
      PATH="$wbin:/usr/bin:/bin" FAKE_SESS="$SESS" FAKE_LOG="$TLOG" \
      FAKE_PI="$PLOG" PI_TMUX_WRAP=force $1 \
      /bin/zsh -l -i -c "PATH=\"$wbin:/usr/bin:/bin\"; cd '$proj' && pi $2" \
      >/dev/null 2>&1
  [[ -s "$PLOG" ]] || die "guard($1 $2): pi never ran"
  [[ ! -s "$TLOG" ]] || die "guard($1 $2): wrapper must not touch tmux"
}
guard_plain "TMUX=yes" ""
guard_plain "" "-p 'quick one'"
guard_plain "" "--mode json 'hello'"
guard_plain "" "--help"
guard_plain "" "list"
guard_plain "PI_TMUX_WRAP=never" ""
# from $HOME: plain pi even with everything else in place. HOME is
# normalized to its physical path first: mktemp yields /var/folders/...
# but cd resolves /var -> /private/var, and the guard compares strings.
homep=$(cd "$NEWHOME" && /bin/pwd -P)
: > "$TLOG"; : > "$PLOG"
env -i HOME="$homep" TERM=xterm-256color SHELL=/bin/zsh \
    PATH="$wbin:/usr/bin:/bin" FAKE_SESS="$SESS" FAKE_LOG="$TLOG" \
    FAKE_PI="$PLOG" PI_TMUX_WRAP=force \
    /bin/zsh -l -i -c "PATH=\"$wbin:/usr/bin:/bin\"; cd '$homep' && pi" \
    >/dev/null 2>&1
[[ -s "$PLOG" && ! -s "$TLOG" ]] || die "from \$HOME pi must run plain"
# no tmux binary on PATH: plain pi, no crash. The payload PATH drops
# /usr/bin entirely -- GitHub's Ubuntu runners SHIP tmux there, which
# would turn this case into a real (failing) attach; nothing in the
# payload needs coreutils, so the shim dir alone is enough.
nobin="$WORK/nobin"; mkdir -p "$nobin"
cp "$wbin/pi" "$nobin/pi"; : > "$PLOG"
env -i HOME="$NEWHOME" TERM=xterm-256color SHELL=/bin/zsh \
    PATH="$nobin:/usr/bin:/bin" FAKE_PI="$PLOG" PI_TMUX_WRAP=force \
    /bin/zsh -l -i -c "PATH='$nobin'; cd '$proj' && pi" \
    >/dev/null 2>&1 || true
[[ -s "$PLOG" ]] || die "without tmux the wrapper must fall through to pi"
ok "creates named sessions, never attaches; guards fall through to plain pi"

printf '\nALL PASS\n'
