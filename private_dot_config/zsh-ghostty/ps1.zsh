# ps1.zsh — theme-following prompt for zsh 5.7+ (macOS ships 5.9)
# Source it from .zshrc:   source ${ZDOTDIR:-$HOME}/ps1.zsh

zmodload zsh/datetime
autoload -Uz vcs_info add-zsh-hook
setopt PROMPT_SUBST

# ---------------------------------------------------------------------------
# Palette — indexed colors (0-15), so the prompt follows whatever theme Ghostty
# has set rather than pinning hex. Currently Gruvbox Material Dark; switching
# themes now recolors the prompt automatically, no edit here required.
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
zstyle ':vcs_info:git:*' unstagedstr "%F{$GB_RED}●%f"
zstyle ':vcs_info:git:*' stagedstr   "%F{$GB_YELLOW}●%f"
zstyle ':vcs_info:git:*' formats       " %F{$GB_AQUA}${GB_GIT_ICON}%b%f%u%c"
zstyle ':vcs_info:git:*' actionformats " %F{$GB_AQUA}${GB_GIT_ICON}%b%f %F{$GB_ORANGE}(%a)%f%u%c"

# vcs_info ignores untracked files by default; this adds a gray dot for them.
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked
+vi-git-untracked() {
  [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]] || return
  git ls-files --others --exclude-standard --directory --no-empty-directory \
    --error-unmatch . >/dev/null 2>&1 && hook_com[unstaged]+="%F{$GB_GRAY}●%f"
}

# ---------------------------------------------------------------------------
# Hooks: command duration (only when it exceeds the threshold) + vcs refresh
# ---------------------------------------------------------------------------
GB_SLOW_THRESHOLD=2   # seconds

_gb_preexec() { _gb_start=$EPOCHREALTIME }

_gb_precmd() {
  local -F elapsed
  _gb_elapsed=''
  if (( ${+_gb_start} )); then
    elapsed=$(( EPOCHREALTIME - _gb_start ))
    unset _gb_start
    (( elapsed > GB_SLOW_THRESHOLD )) && _gb_elapsed=$(printf '%.1fs' $elapsed)
  fi
  vcs_info
}

add-zsh-hook preexec _gb_preexec
add-zsh-hook precmd  _gb_precmd

# ---------------------------------------------------------------------------
# Prompt assembly
#   [user@host ]path git-branch●● [⚙jobs] ❯
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
