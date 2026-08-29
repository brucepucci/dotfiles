# ps1.zsh — theme-following prompt for zsh 5.7+ (macOS ships 5.9)
# Sourced by ~/.zshrc from here (~/.config/zsh/ps1.zsh). Same prompt in
# every terminal: Ghostty, Terminal.app, iTerm2, SSH.

zmodload zsh/datetime
autoload -Uz vcs_info add-zsh-hook
setopt PROMPT_SUBST

# ---------------------------------------------------------------------------
# Palette — indexed colors (0-15), so the prompt follows whatever theme the
# terminal emulator has set rather than pinning hex. Currently Gruvbox
# Material Dark in Ghostty; switching themes there recolors the prompt
# automatically, no edit here required. Terminals without theme support just
# render the indexed colors of their own palette.
# Orange has no slot in the 16-color palette, so it stays hex.
# ---------------------------------------------------------------------------
GB_GRAY=8
GB_RED=1
GB_GREEN=2
GB_YELLOW=3
GB_BLUE=4
GB_PURPLE=5
GB_AQUA=6
GB_ORANGE='#e78a4e'

# Branch glyph. Replace with 'git:' or '⎇ ' if it renders as a box.
GB_GIT_ICON=' '

# ---------------------------------------------------------------------------
# Git state via vcs_info: branch, in-progress action, staged/unstaged markers
# ---------------------------------------------------------------------------
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
# Git state, in sync with the snacks explorer's git-status column -- same
# glyphs (snacks defaults), same colors (its Staged/Modified groups link to
# DiagnosticHint/DiagnosticWarn = gruvbox-material purple/yellow, which are
# indexed colors 5 and 3 here):
#   ● purple -- staged, in the index (filled = locked in)
#   ○ yellow -- changed, not staged (open = still loose)
# Untracked files are deliberately NOT shown: probing for them meant
# `git ls-files --others` scanning the whole worktree on EVERY prompt -- by
# far the most expensive thing this prompt did. `git status` when you want
# the full picture; set check-for-changes to false for a branch-only prompt.
#
# Each marker carries a leading space. It separates the two glyphs when both
# are present and separates the first from the branch name (the nerd-font
# branch icon is wide and crowds what follows), while vanishing with the
# marker itself -- a clean tree gets no stray gap.
zstyle ':vcs_info:git:*' unstagedstr "%F{$GB_YELLOW} ○%f"
zstyle ':vcs_info:git:*' stagedstr   "%F{$GB_PURPLE} ●%f"
zstyle ':vcs_info:git:*' formats       " %F{$GB_AQUA}${GB_GIT_ICON}%b%f%u%c"
zstyle ':vcs_info:git:*' actionformats " %F{$GB_AQUA}${GB_GIT_ICON}%b%f %F{$GB_ORANGE}(%a)%f%u%c"

# ---------------------------------------------------------------------------
# Hooks: command duration (only when it exceeds the threshold) + vcs refresh
# ---------------------------------------------------------------------------
GB_SLOW_THRESHOLD=2   # seconds

_gb_preexec() {
  _gb_start=$EPOCHREALTIME
  # Also arms the pre-prompt blank line in _gb_precmd: only a prompt that
  # follows real command output gets one.
  _gb_had_command=1
}

_gb_precmd() {
  local -F elapsed
  _gb_elapsed=''
  if (( ${+_gb_start} )); then
    elapsed=$(( EPOCHREALTIME - _gb_start ))
    unset _gb_start
    (( elapsed > GB_SLOW_THRESHOLD )) && _gb_elapsed=$(printf '%.1fs' $elapsed)
  fi
  # One blank line between the previous command's output and this prompt --
  # but only when a command actually ran: not before the shell's first
  # prompt (fastfetch already opens the session), and not on Enter or
  # Ctrl-C over an empty prompt, which would stack blank lines.
  if (( ${+_gb_had_command} )); then
    print
    unset _gb_had_command
  fi
  vcs_info
}

add-zsh-hook preexec _gb_preexec
add-zsh-hook precmd  _gb_precmd

# ---------------------------------------------------------------------------
# Prompt assembly
#   [user@host ]path git-branch●○ [⚙jobs] ❯
#                                        right side:  ✗exit  elapsed
# ---------------------------------------------------------------------------
GB_HOST=''
[[ -n $SSH_CONNECTION ]] && GB_HOST="%F{$GB_ORANGE}%n@%m%f "

# %(4~|…/%3~|%~) — full path until 4 components deep, then elide the front
PROMPT="${GB_HOST}%B%F{$GB_BLUE}%(4~|…/%3~|%~)%f%b"
PROMPT+='${vcs_info_msg_0_}'
PROMPT+="%(1j. %F{$GB_PURPLE}⚙%j%f.)"
PROMPT+=" %(?.%F{$GB_GREEN}.%F{$GB_RED})%(!.#.❯)%f "

RPROMPT="%(?..%F{$GB_RED}✗ %?%f )%F{$GB_GRAY}"'${_gb_elapsed}'"%f"
