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
#      output carries a hex the themes don't define, nvim's generated
#      data module carries the chosen roles verbatim, and pi's themes
#      ride the viewing terminal's indexed slots (bg/fg/accents/grey on
#      0-15 and defaults, shades on the fixed xterm cube) so SSH'd pi
#      follows the terminal you are looking at -- only the two tool
#      tints remain live hexes
#  11. the tmux config renders with pi's requirements intact: extended
#      keys (Shift+Enter survives the tmux layer), OSC 52 clipboard,
#      truecolor passthrough, mouse-wheel copy-mode scrollback, status-bar
#      window separator — file-shape only; no tmux binary needed
#  12. the pi wrapper: `pi` always CREATES a session (never attaches —
#      rejoining is manual `tmux attach`), names it after the project dir
#      (-2/-3 on collision) or the sanitized -n topic, passes
#      --use-theme dotfiles-{light,dark} decided from the VIEWING terminal
#      (pi cannot ask through the tmux layer; non-tty runs fall back dark),
#      keeps tmux wrapping for a user-supplied --use-theme (only the
#      injection is suppressed), and falls through to plain pi inside
#      tmux / without the binary / from $HOME / for one-shot -p runs —
#      exercised with fake tmux+pi shims
#  13. the tmux_wrap setting: "on" (the committed value) renders no env
#      default and leaves PI_TMUX_WRAP unset; "off" renders
#      : ${PI_TMUX_WRAP:=never} into ~/.zshrc (second apply against a
#      flipped settings file via DOTFILES_SETTINGS_FILE, the same override
#      pattern as the themes dir); an invalid value fails the resolver
#  14. the shell integrations' shape: fzf + autosuggestions + syntax
#      highlighting blocks render after compinit, ghost text uses indexed
#      color 8 (no hex), and zsh-syntax-highlighting is the LAST source in
#      ~/.zshrc -- the absent-formula branch is what CI exercises live
#  15. sparse custom themes: a palette slot the theme never set defaults
#      to the background -- pi must emit the role's hex, not ride the slot
#      index (the viewing terminal's own color there would silently
#      diverge from nvim/lualine's rendering of the same theme)
#  16. a pinned theme mode (theme = "dark"): PI_THEME_PINNED renders into
#      ~/.zshrc, pi's settings.json carries the single theme, and the
#      wrapper wraps WITHOUT --use-theme (the flag beats settings.json
#      and would silently override the pin)
#  17. the theme probe itself, on a real pty: the 997;1/2 mapping, the
#      gamma-corrected luminance threshold (mid-tones classify opposite
#      to a naive average), every OSC 11 reply shape pi's parser accepts,
#      typeahead preservation, and the silent-terminal dark fallback
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
# Settings come from settings.toml (the user-facing file at the repo root).
themeset() { python3 "$SOURCE/scripts/ghostty-theme.py" --setting "$1"; }
themeget() { python3 "$SOURCE/scripts/ghostty-theme.py" --get "$@"; }
MODE="$(themeset theme)"
LTHEME="$(themeset light_theme)"
DTHEME="$(themeset dark_theme)"
[[ "$MODE" == system || "$MODE" == light || "$MODE" == dark ]] \
  || die "settings.toml: theme must be system|light|dark, got: $MODE"
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
# The palette system: the appearance settings (settings.toml, repo root)
# and NO cached
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
# pi themes: the SSH guarantee, checked against the resolver's own
# output instead of restated constants. bg/fg/accents/grey ride the
# viewing terminal's slots, shades no slot can carry ride the xterm
# cube, and a hex that is not one of the two live tints would mean
# SSH'd pi is back to showing the rendering machine's opinion.
# Provenance: each accent role IS its palette entry, and pi rides that
# same slot -- if derive_roles ever maps a role from a different entry,
# pi and nvim/lualine silently disagree and this fails. The rendered
# themes are then loaded as JSON and every colors reference resolved
# against the vars block: the old per-key templating failed `chezmoi
# apply` loudly on a bad name, the vars indirection renders fine -- pi
# would silently fall back to its built-in theme.
if ! python3 - "$LTHEME" "$DTHEME" "$NEWHOME" "$SOURCE" <<'PY'
import json, subprocess, sys
ltheme, dtheme, home, src = sys.argv[1:5]
py, script = "python3", src + "/scripts/ghostty-theme.py"

def run(*args):
    return subprocess.run([py, script, *args], capture_output=True,
                          text=True, check=True).stdout

def parse_hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

ACCENT_SLOTS = {"red": 1, "green": 2, "yellow": 3,
                "blue": 4, "purple": 5, "aqua": 6}
for side, theme in (("light", ltheme), ("dark", dtheme)):
    data = json.loads(run(theme))
    term, roles = data["terminal"], data["roles"]
    piv = json.loads(run("--pi", theme))
    if piv["bg"] != "" or piv["fg"] != "":
        sys.exit("pi vars: bg/fg must ride the terminal defaults")
    for role, slot in ACCENT_SLOTS.items():
        if parse_hex(term["palette_%d" % slot]) != parse_hex(roles[role]):
            sys.exit("%s: roles.%s drifted from palette_%d -- pi and "
                     "nvim/lualine would disagree" % (theme, role, slot))
        if piv[role] != slot:
            sys.exit("%s: pi var %s no longer rides its slot" % (theme, role))
    # grey family: slot 8 is the theme author's muted color by design
    # (roles.grey is a blend -- no identity to assert, just the slot)
    for k in ("grey", "grey_neutral", "grey_soft"):
        if piv[k] != 8:
            sys.exit("%s: pi var %s must ride slot 8" % (theme, k))
    # fg_bright: slot 15 on dark (verbatim palette_15), cube on light
    if piv["fg_bright"] == 15:
        if parse_hex(term["palette_15"]) != parse_hex(roles["fg_bright"]):
            sys.exit("%s: roles.fg_bright drifted from palette_15" % theme)
    elif not (isinstance(piv["fg_bright"], int) and 16 <= piv["fg_bright"] <= 255):
        sys.exit("%s: fg_bright must be slot 15 or a cube index" % theme)
    for k in ("grey_dim", "surface", "orange"):
        if not (isinstance(piv[k], int) and 16 <= piv[k] <= 255):
            sys.exit("%s: pi var %s must ride the xterm cube" % (theme, k))
    for k in ("tint_green", "tint_red"):
        if piv[k] != roles[k]:
            sys.exit("%s: pi var %s must stay the live-derived hex" % (theme, k))
    # the rendered theme file: valid JSON, vars exactly the --pi block,
    # every colors value a var name ("" = the terminal default)
    f = "%s/.pi/agent/themes/dotfiles-%s.json" % (home, side)
    t = json.load(open(f))
    if t["vars"] != piv:
        sys.exit("%s: rendered vars differ from the --pi output" % f)
    names = set(t["vars"]) | {""}
    for k, v in t["colors"].items():
        if v not in names:
            sys.exit("%s: colors.%s references unknown var %r -- pi would "
                     "silently fall back to its built-in theme" % (f, k, v))
    print("  ok  %s: slots + provenance verified; dotfiles-%s refs resolve"
          % (theme, side))
PY
then
  die "pi vars left the slot/cube/tint discipline, or a theme ref dangles (see above)"
fi
for side in light dark; do
  f="$NEWHOME/.pi/agent/themes/dotfiles-$side.json"
  for want in '"bg": ""' '"red": 1' '"grey": 8'; do
    grep -qF "$want" "$f" || die "$f: slot $want did not render"
  done
done
ok "themes resolve, no orphan hexes, roles verbatim, pi follows the terminal"

step "pi vars: sparse custom themes ride hexes, not defaulted slots"
# Every catalog theme ships a full 16-color palette, but a hand-written
# theme (DOTFILES_GHOSTTY_THEMES) can leave slots out -- the resolver
# defaults them to the background hex. Riding such a slot as an index
# would show the VIEWING terminal's own color there while nvim/lualine
# render the derived roles: a silent divergence between the apps.
sparse="$WORK/sparse-themes"; mkdir -p "$sparse"
cat > "$sparse/SparseTest" <<'CONF'
background = #101010
foreground = #e0e0e0
palette = 0=#101010
palette = 2=#00cc00
CONF
spiv="$(DOTFILES_GHOSTTY_THEMES="$sparse" \
  python3 "$SOURCE/scripts/ghostty-theme.py" --pi SparseTest)"
grep -qF '"green": 2' <<<"$spiv" \
  || die "sparse theme: a defined slot (green/2) must still ride the index"
grep -qF '"red": "#101010"' <<<"$spiv" \
  || die "sparse theme: a defaulted slot (red/1) must emit the role hex"
grep -qF '"fg_bright": "#101010"' <<<"$spiv" \
  || die "sparse theme: defaulted palette_15 must emit the role hex"
sred="$(DOTFILES_GHOSTTY_THEMES="$sparse" \
  python3 "$SOURCE/scripts/ghostty-theme.py" --get SparseTest roles.red)"
[[ "$sred" == "#101010" ]] \
  || die "sparse theme: roles.red should be the defaulted background hex"
ok "sparse themes: defined slots ride indices, defaulted slots ride hexes"

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

step "shell integrations: guarded, after compinit, syntax highlighting last"
# The three quality-of-life blocks (fzf keybindings, autosuggestions,
# syntax highlighting) are guarded by file existence: an environment
# without the brew formulas -- CI, a fresh install mid-setup -- takes the
# absent branch and stays quiet, which is exactly what this run exercises
# functionally. What every environment CAN check is shape: all three
# source lines render, they sit after compinit, ghost text is indexed
# color 8 (never a hex), and zsh-syntax-highlighting is the final source
# in the file (it wraps ZLE widgets at load; a later binding would wrap
# a stale copy).
zrc="$NEWHOME/.zshrc"
compinit_line="$(grep -nE '^[[:space:]]*compinit ' "$zrc" | cut -d: -f1 | head -1 || true)"
fzf_line="$(grep -nF '$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh' "$zrc" | cut -d: -f1 | head -1 || true)"
asugg_line="$(grep -nF '$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh' "$zrc" | cut -d: -f1 | head -1 || true)"
zshy_line="$(grep -nF '$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' "$zrc" | cut -d: -f1 | head -1 || true)"
[[ -n "$compinit_line" ]] || die "~/.zshrc: compinit invocation not found"
for pair in "fzf:$fzf_line" "autosuggestions:$asugg_line" "syntax-highlighting:$zshy_line"; do
  name="${pair%%:*}"; line="${pair##*:}"
  [[ -n "$line" ]] || die "~/.zshrc: $name integration source line missing"
  (( line > compinit_line )) \
    || die "~/.zshrc: $name must source after compinit (line $line <= $compinit_line)"
done
grep -qF "ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'" "$zrc" \
  || die "~/.zshrc: ghost text must be indexed color 8, not a hex"
last_source="$(grep -E '^[^#]*[[:space:]]source [^[:space:]]' "$zrc" | tail -1 || true)"
[[ "$last_source" == *zsh-syntax-highlighting* ]] \
  || die "~/.zshrc: zsh-syntax-highlighting must be the last source (got: $last_source)"
ok "all three render after compinit; ghost text indexed; highlighting last"

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
# harness cannot provide (that one branch runs for real in manual use;
# the probe itself gets a real pty in its own step below). Non-tty runs
# fall back dark, so every wrapped case here expects dotfiles-dark.
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
grep -qF 'new-session -s auth-refactor command pi --use-theme dotfiles-dark -n Auth\ Refactor' "$TLOG" \
  || die "topic naming/passthrough wrong: $(tail -1 "$TLOG")"
grep -qxF auth-refactor "$SESS" || die "topic session not minted"
[[ "$(cat "$PLOG")" == "" ]] || die "fake pi must not run at wrapper time"
[[ "$out" == *'detach Ctrl-b d'* ]] || die "creation hint missing: $out"
# 2. default name from the project dir; numbered siblings on collision
: > "$TLOG"; printf 'demoproj\ndemoproj-2\n' > "$SESS"
rc=0; out2="$(wrap_zsh "$proj" "")" \
  || { rc=$?; die "case-2 inner zsh exited $rc -- output: $out2"; }
grep -qF 'new-session -s demoproj-3 command pi --use-theme dotfiles-dark' "$TLOG" \
  || die "collision numbering wrong: $(tail -1 "$TLOG")"
# 3. an explicitly taken topic refuses -- nothing silently renamed
: > "$TLOG"; printf 'auth-refactor\n' > "$SESS"
rc=0; out="$(wrap_zsh "$proj" '-n auth-refactor')" || rc=$?
(( rc != 0 )) || die "taken topic should exit nonzero"
[[ ! -s "$TLOG" ]] || die "taken topic must not create a session"
[[ "$out" == *'tmux attach -t auth-refactor'* ]] || die "rejoin hint missing: $out"
# 3b. a user-supplied --use-theme is an interactive-run flag: the session
# still wraps (it is not one-shot like -p/--help), but the wrapper must
# not stack its own detected theme on top of the user's choice
: > "$TLOG"; printf 'demoproj\n' > "$SESS"
rc=0; out="$(wrap_zsh "$proj" '--use-theme my-theme')" \
  || { rc=$?; die "case-3b inner zsh exited $rc -- output: $out"; }
grep -qF 'new-session -s demoproj-2 command pi --use-theme my-theme' "$TLOG" \
  || die "user --use-theme must wrap exactly as given: $(tail -1 "$TLOG")"
grep -qF 'dotfiles-' "$TLOG" \
  && die "user --use-theme must suppress the detected theme injection"
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

step "tmux_wrap setting: on leaves the env alone, off defaults it to never"
# settings.toml (repo root) carries tmux_wrap = on|off. The committed value
# is "on": the applied ~/.zshrc carries no default and PI_TMUX_WRAP stays
# unset in interactive shells. "off" renders : ${PI_TMUX_WRAP:=never} into
# ~/.zshrc -- proven with a second apply against a settings file flipped to
# off (the resolver reads DOTFILES_SETTINGS_FILE, same override pattern as
# DOTFILES_GHOSTTY_THEMES).
[[ "$(python3 "$SOURCE/scripts/ghostty-theme.py" --setting tmux_wrap)" == on ]] \
  || die "resolver: committed tmux_wrap must read 'on'"
grep -qF ': ${PI_TMUX_WRAP:=never}' "$NEWHOME/.zshrc" \
  && die "tmux_wrap=on must not render a PI_TMUX_WRAP default into ~/.zshrc"
fresh_zsh '[[ -z ${PI_TMUX_WRAP:-} ]]' >/dev/null \
  || die "tmux_wrap=on: PI_TMUX_WRAP must stay unset in interactive shells"
offsettings="$WORK/settings-off.toml"
sed 's/^tmux_wrap = "on"/tmux_wrap = "off"/' "$SOURCE/settings.toml" > "$offsettings"
offhome="$WORK/home-off"; mkdir -p "$offhome"
DOTFILES_SETTINGS_FILE="$offsettings" \
  chezmoi --source "$SOURCE" --destination "$offhome" apply \
  || die "tmux_wrap=off: apply failed"
grep -qF ': ${PI_TMUX_WRAP:=never}' "$offhome/.zshrc" \
  || die 'tmux_wrap=off must render ": ${PI_TMUX_WRAP:=never}" into ~/.zshrc'
env -i HOME="$offhome" TERM=xterm-256color PATH="/usr/bin:/bin" \
    /bin/zsh -l -i -c '[[ ${PI_TMUX_WRAP:-} == never ]]' >/dev/null 2>&1 \
  || die "tmux_wrap=off: interactive shells must see PI_TMUX_WRAP=never"
badsettings="$WORK/settings-bad.toml"
sed 's/^tmux_wrap = "on"/tmux_wrap = "sometimes"/' "$SOURCE/settings.toml" > "$badsettings"
DOTFILES_SETTINGS_FILE="$badsettings" \
  python3 "$SOURCE/scripts/ghostty-theme.py" --setting tmux_wrap >/dev/null 2>&1 \
  && die "resolver: an invalid tmux_wrap value must fail loudly"
ok "on leaves the env alone; off defaults it to never; invalid fails apply"

step "pinned theme mode: the wrapper never overrides the pin"
# theme = "light"|"dark" in settings.toml renders the single theme into
# pi's settings.json -- and --use-theme beats settings.json, so the
# wrapper must not inject one. The pin renders PI_THEME_PINNED into
# ~/.zshrc and the probe is skipped entirely: the pin wins no matter
# what the viewing terminal reports. (Committed settings stay system,
# so the main HOME must carry no pin.)
pinnedsettings="$WORK/settings-pinned.toml"
sed 's/^theme = "system"/theme = "dark"/' "$SOURCE/settings.toml" > "$pinnedsettings"
pinnedhome="$WORK/home-pinned"; mkdir -p "$pinnedhome"
DOTFILES_SETTINGS_FILE="$pinnedsettings" \
  chezmoi --source "$SOURCE" --destination "$pinnedhome" apply \
  || die "theme=dark: apply failed"
grep -qF 'PI_THEME_PINNED="dark"' "$pinnedhome/.zshrc" \
  || die 'theme=dark must render PI_THEME_PINNED="dark" into ~/.zshrc'
[[ "$(sed -n 's/.*"theme": "\([^"]*\)".*/\1/p' "$pinnedhome/.pi/agent/settings.json")" == "dotfiles-dark" ]] \
  || die "theme=dark: pi settings.json must carry the single dark theme"
grep -qF ': ${PI_TMUX_WRAP:=never}' "$pinnedhome/.zshrc" \
  && die "tmux_wrap=on must stay silent even when the theme is pinned"
: > "$TLOG"; : > "$SESS"; : > "$PLOG"
rc=0; out="$(env -i HOME="$pinnedhome" TERM=xterm-256color SHELL=/bin/zsh \
      PATH="$wbin:/usr/bin:/bin" FAKE_SESS="$SESS" FAKE_LOG="$TLOG" \
      FAKE_PI="$PLOG" PI_TMUX_WRAP=force \
      /bin/zsh -l -i -c "PATH=\"$wbin:/usr/bin:/bin\"; cd '$proj' && pi" 2>&1)" \
  || { rc=$?; die "pinned wrapper run exited $rc -- output: $out"; }
grep -qF 'new-session -s demoproj command pi' "$TLOG" \
  || die "pinned mode must still wrap in tmux: $(tail -1 "$TLOG")"
grep -qF -- '--use-theme' "$TLOG" \
  && die "pinned mode must not inject --use-theme (it would beat the pin)"
! grep -qF 'PI_THEME_PINNED=' "$NEWHOME/.zshrc" \
  || die "theme=system (committed) must not render a pin into ~/.zshrc"
ok "pin renders, wraps without --use-theme; system mode stays unpinned"

step "theme probe: reply parsing on a real pty"
# __pi_theme_side needs a tty, so wrap_zsh above cannot exercise it --
# and the tty is exactly where its bugs live: the 997;1/2 mapping, the
# gamma-corrected luminance threshold, the OSC 11 reply formats, and
# typeahead preservation. Drive the applied ~/.zshrc's own function from
# a pty (python stdlib), answering its queries the way a terminal would:
# an inverted mapping, a naive /255 average, a narrow rgb: regex, or an
# 'n'-terminated read loop each fail a case below.
if ! python3 -u - "$NEWHOME" <<'PY'
import os, pty, re, select, signal, sys, time
signal.alarm(240)
home = sys.argv[1]

# GitHub's runner images ship zsh fpath dirs owned by neither root nor
# the job's uid, so on a tty (this harness is the one place the test
# tree gets one) compinit asks "Ignore insecure directories and continue
# [y] or abort compinit [n]?" and blocks the shell before the probe
# ever runs -- the same quirk AGENTS.md documents for the -u branch.
# Answer it the way an interactive user would; on real machines the
# prompt never appears. Single 'y', no newline: it is a read -k1.
COMPINIT_PROMPT = b"[y] or abort compinit [n]"

def run_case(name, dsr_feed, osc_feed, want, want_typed=None, timeout=15):
    pid, fd = pty.fork()
    if pid == 0:
        env = {"HOME": home, "TERM": "xterm-256color",
               "PATH": "/usr/bin:/bin", "LC_ALL": "C.UTF-8"}
        os.execve("/bin/zsh", ["/bin/zsh", "-i", "-c",
                  '__pi_theme_side; print -r -- "RESULT=$REPLY"; '
                  'print -r -- "TYPED=${__pi_typed}"'], env)
    buf = b""
    fed_dsr = fed_osc = compinit_answered = False
    deadline = time.time() + timeout
    while time.time() < deadline:
        r, _, _ = select.select([fd], [], [], 0.2)
        if not r:
            continue
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
        # split-safe: matched against everything read so far, answered once
        if not compinit_answered and COMPINIT_PROMPT in buf:
            os.write(fd, b"y")
            compinit_answered = True
        if not fed_dsr and b"\x1b[?996n" in buf:
            fed_dsr = True
            if dsr_feed is not None:
                os.write(fd, dsr_feed)   # typeahead first, then the reply
        if not fed_osc and b"\x1b]11;?" in buf:
            fed_osc = True
            if osc_feed is not None:
                os.write(fd, osc_feed)
        if b"TYPED=" in buf:
            break
    try:
        os.kill(pid, 9); os.waitpid(pid, 0)
    except Exception:
        pass
    try:
        os.close(fd)
    except OSError:
        pass
    text = buf.decode("utf-8", "replace")
    m = re.search(r"RESULT=(\w+)", text)
    got = m.group(1) if m else None
    typed = None
    if "TYPED=" in text:
        typed = text.split("TYPED=", 1)[1].split("\r")[0].split("\n")[0]
    if got != want or (want_typed is not None and typed != want_typed):
        # Diagnostics for exactly the situation that once failed this
        # step silently on CI: what did the child print, and is it
        # alive, stopped, or gone? /proc is linux-only; guarded for macOS.
        state = "?"
        try:
            with open("/proc/%d/status" % pid) as f:
                ms = re.search(r"State:\s+(\S+)", f.read())
                state = ms.group(1) if ms else "?"
        except OSError:
            pass
        print("  FAIL %s: result=%r typed=%r (want %r/%r) child=%s buflen=%d"
              % (name, got, typed, want, want_typed, state, len(buf)))
        print("       raw tail: %r" % buf[-300:])
        return False
    print("  ok  %s" % name)
    return True

G = b"\x1b[?997;9n"   # scheme report naming no known side -> OSC fallback
cases = [
    # kitty-spec mapping: 997;1 = dark, 997;2 = light (the branch under
    # review shipped this inverted -- every reporting terminal got the
    # wrong theme, and the OSC fallback never ran to correct it)
    ("scheme report 997;1 -> dark",   b"\x1b[?997;1n", None, "dark", ""),
    ("scheme report 997;2 -> light",  b"\x1b[?997;2n", None, "light", ""),
    # OSC 11 replies in every shape pi's own parser accepts
    ("OSC #RRGGBB light",             G, b"\x1b]11;#ffffff\x07", "light", ""),
    ("OSC #RRGGBB dark",              G, b"\x1b]11;#000000\x07", "dark", ""),
    ("OSC rgb:16-bit light",          G, b"\x1b]11;rgb:ffff/ffff/ffff\x07", "light", ""),
    ("OSC rgb:16-bit dark, ST-ended", G, b"\x1b]11;rgb:0000/0000/0000\x1b\\", "dark", ""),
    ("OSC #RRRRGGGGBBBB light",       G, b"\x1b]11;#ffffffffffff\x07", "light", ""),
    ("OSC rgba:, alpha ignored",      G, b"\x1b]11;rgba:ffff/ffff/ffff/ffff\x07", "light", ""),
    # pi's luminance is gamma-corrected: these mid-tones are DARK even
    # though a naive weighted-average of /255 calls them light
    ("OSC #999999 -> dark (gamma)",   G, b"\x1b]11;rgb:9999/9999/9999\x07", "dark", ""),
    ("OSC #b4b4b4 -> dark (gamma)",   G, b"\x1b]11;#b4b4b4\x07", "dark", ""),
    ("OSC #c8c8c8 -> light",          G, b"\x1b]11;#c8c8c8\x07", "light", ""),
    # keystrokes during the probe are preserved verbatim and re-injected
    # into the session -- including 'n's, which must not end the reply
    # read, and arrow keys, which must not be mistaken for reports
    ("typeahead 'n's + arrow kept",   b"nn\x1b[D\x1b[?997;2n", None, "light", "nn\x1b[D"),
    ("arrow key before reply kept",   b"\x1b[A\x1b[?997;1n", None, "dark", "\x1b[A"),
    ("typeahead between queries",     G, b"hi\x1b]11;#ffffff\x07", "light", "hi"),
    # a terminal that answers nothing keeps pi's own fallback
    ("no reply -> dark fallback",     None, None, "dark", ""),
]
if not all([run_case(*c) for c in cases]):
    sys.exit(1)
PY
then
  die "theme probe misparsed a reply (see above)"
fi
ok "997 mapping, gamma threshold, OSC formats, typeahead all correct"

printf '\nALL PASS\n'
