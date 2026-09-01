# zsh — the one shell

**One shell everywhere** is a load-bearing design decision. Every terminal
on this machine — Ghostty, Terminal.app, iTerm2 — and every SSH session
logging in from anywhere reads the same three files. The prompt looks the
same, history is shared live, and there is exactly one obvious place to
change shell behavior. oh-my-zsh and powerlevel10k are gone; what they
provided here is either built in, replaced by three Homebrew formulas,
small enough to reimplement outright (`clipcopy`/`clippaste` below), or
wasn't wanted.

**Managed files** (source in the repo root and `private_dot_config/zsh*/`):

| Source file | Installs to | Job |
|---|---|---|
| `dot_zprofile` | `~/.zprofile` | login-shell PATH: Homebrew + `~/.local/bin` |
| `dot_zshrc.tmpl` | `~/.zshrc` | the interactive half: options, history, completion, keybindings, integrations, aliases, clipboard helpers, the `pi()` wrapper, secrets, prompt |
| `private_dot_config/zsh/ps1.zsh` | `~/.config/zsh/ps1.zsh` | the prompt |
| `private_dot_config/zsh-ghostty/dot_zshenv` | `~/.config/zsh-ghostty/.zshenv` | legacy redirect guard (see below) |

## History: one shared file

`HISTFILE` is deliberately pinned to `~/.zsh_history` so nothing can fork
history off to a second file. `SHARE_HISTORY` merges sessions live: a
command typed in one terminal is immediately on Ctrl-R in another, even
mid-flight. 50,000 entries, extended timestamps, dups and blanks collapsed,
space-prefixed commands kept secret (`HIST_IGNORE_SPACE`), and
`HIST_VERIFY` makes `!!`-style expansions show themselves before running.

## The prompt (`ps1.zsh`)

`[ssh-host ]path  branch ●○ [ jobs] ❯` with `✗exit` and elapsed time on the
right — rendered entirely in **indexed colors 0–15**. That's the SSH trick:
indexed slots are resolved by the *viewing* terminal through its own
palette, so the prompt automatically matches whatever theme the terminal in
front of you runs, without the Mac shipping hexes around (see
[theming.md](theming.md)).

Details worth knowing:

- Git state via `vcs_info`: the branch glyph is a Nerd Font codepoint
  (`U+E0A0`, written in the file as an escape — never pasted, pasting is
  how it was once lost), then `●` purple for staged and `○` yellow for
  unstaged. Untracked files are deliberately **not** shown — probing for
  them meant `git ls-files --others` scanning the whole worktree on every
  prompt, by far the most expensive thing it did. `git status` for the full
  picture.
- The `ssh host` segment (orange, with a server glyph) appears only when
  `SSH_CONNECTION` is set — that's how you always know which side of the
  glass you're on.
- Commands slower than 2s report their duration on the right.
- A blank line separates command output from the next prompt — but only
  after real commands (not on empty Enter, not at the first prompt, and
  `clear` resets the flag so a cleared screen stays clean).
- Every icon is followed by a space where text comes next: Nerd Font glyph
  ink is wider than the one cell a terminal grants it, and without the
  space the icon overpaints the following character (first seen over SSH).
  This spacing rule is asserted in the smoke test.
- Fallbacks if a glyph renders as a box are listed at the top of the file
  (`git:` instead of the branch glyph, etc.).

## Shell integrations (three Homebrew formulas)

Each is a guarded block — a machine without the formula (CI, a fresh
install mid-setup) just skips the feature. The guard probes
`HOMEBREW_PREFIX`, which covers Apple Silicon and Intel alike.

1. **fzf** — fuzzy Ctrl-R (history), Ctrl-T (files into the command line),
   Alt-C (directories). Sourced after `compinit`, which fzf's completion
   script expects.
2. **zsh-autosuggestions** — fish-style ghost text from history, colored
   with indexed color **8** so it follows the terminal palette like the
   prompt does. Because suggestions read the in-memory history,
   `SHARE_HISTORY` makes other terminals' commands suggestable live.
3. **zsh-syntax-highlighting** — invalid commands turn red before you press
   Enter. **Sourced last in `~/.zshrc` and it must stay that way**: it wraps
   every ZLE widget at load time, so every other binding has to exist
   first or it wraps a stale copy.

## Keybindings

Emacs mode (`bindkey -e`) — Ctrl-A/Ctrl-E/Ctrl-K behave like macOS text
fields. On top of that:

| Key | Action |
|---|---|
| Up / Down arrows | History search using what's already typed (beginning-search) |
| `Ctrl-R` | fzf fuzzy history search |
| `Ctrl-T` | fzf: insert file paths under the cursor |
| `Alt-C` | fzf: fuzzy-cd into a directory |
| `Alt-←` / `Alt-→` | Word jumping (Ghostty works out of the box; no option-as-alt setting needed) |
| `Alt-⌫` | Kill previous word |
| `Alt-⌦` (fn+Delete) | Kill **next** word — matches pi's `alt+delete`; both CSI and Esc-prefixed encodings are bound |
| `Ctrl-Enter` | Run the visible autosuggestion **as-is** (Ghostty + tmux only — legacy bytes can't express ctrl on Enter) |
| `Ctrl-Option-Enter` | Accept the suggestion without running it (same scope) |

The suggestion chords only do their thing when the suggestion is complete
and the cursor sits at the end of the line — never on a half-typed line.
Outside Ghostty they're no-ops (ctrl+enter is byte-identical to plain
Enter there). Inside the autosuggestions guard lives a small custom widget
(`run-suggestion`) plus a load-bearing `ZSH_AUTOSUGGEST_IGNORE_WIDGETS`
entry so the plugin's deferred rebinder doesn't clear the suggestion
before the widget can see it.

## Aliases

| Alias | Runs |
|---|---|
| `l` | `ls <color>` |
| `ls` | `ls <color>` (`-G` or `--color=auto`, probed — a GNU ls shadowing BSD's still works) |
| `ll` | `ls -lh <color>` |
| `la` | `ls -lhA <color>` |
| `grep` | `grep --color=auto` |
| `clear` | clear, plus reset the prompt's blank-line flag (defined in ps1.zsh) |

## Clipboard: `clipcopy` / `clippaste`

The one oh-my-zsh convention worth keeping, reimplemented as ~15 lines
against `pbcopy`/`pbpaste` (stock macOS — the repo's one platform, so
omz's `OSTYPE` ladder collapses to nothing) instead of sourcing omz for
it:

| Command | Effect |
|---|---|
| `<command> \| clipcopy` | copies stdout to the clipboard |
| `clipcopy <file>` | copies the file's contents |
| `clippaste` | prints the clipboard (`clippaste > file` saves it) |

Semantics match omz with one deliberate simplification: an explicit file
argument wins over a pipe when both are present. A bare `clipcopy` with
neither a pipe nor a file is a usage error (exit 1), never a silent empty
copy.

They read and write the **Mac's** pasteboard — the same clipboard nvim's
yanks land on — from every terminal and over SSH into the Mac alike.
The other direction, getting tmux copy-mode yanks onto the *viewing*
device's clipboard over SSH, stays tmux's OSC 52 job (see
[tmux.md](tmux.md)).

## The `pi()` wrapper

The largest custom piece of `~/.zshrc`: typing `pi` in a project directory
always starts a **new** conversation, wrapped in its own named, detachable
tmux session that dies when pi exits. Rejoining is deliberately explicit
(`tmux attach -t <name>`), so `pi` never attaches to a stray session. The
full story — naming, guards, and the theme probe that decides light/dark
from the *viewing* terminal before the session exists — is in
[pi.md](pi.md) and [tmux.md](tmux.md).

Two settings from `settings.toml` render conditionally into this file:
`tmux_wrap = "off"` becomes a `PI_TMUX_WRAP=never` default, and a pinned
theme renders `PI_THEME_PINNED` so the wrapper never injects `--use-theme`
over the pin.

## Secrets

`~/.zshrc` sources `~/.zsh/secrets.zsh` when present — an **unmanaged**
file (listed in `.chezmoiignore`, template at
`private_dot_zsh/secrets.example.zsh`). API keys and tokens never enter
this repo. The guard makes it optional: machines with no secrets just skip
it. See [developing.md](developing.md#add-a-secret).

## Editor, banner, misc

- `EDITOR`/`VISUAL` default to nvim, guarded so a machine without Neovim
  still gets a working `vim` (an unresolvable EDITOR breaks `git commit`
  and friends).
- `fastfetch` prints a banner on new interactive shells, if installed.
- `AUTO_CD` (type a directory name to cd), `AUTO_PUSHD` +
  `PUSHD_IGNORE_DUPS` (cd history with `cd -<TAB>`), `NO_BEEP`,
  `INTERACTIVE_COMMENTS`, `NO_NOMATCH` (unmatched globs pass through like
  bash).
- Completion: `compinit` with the security audit kept for interactive
  shells but skipped (`-u`) where there's no tty to answer its y/n prompt
  (CI, `ssh host command`) — otherwise it aborts silently and you get no
  completions at all. Case-insensitive matching, group headings, menu
  selection.

## The legacy ZDOTDIR guard

`~/.config/zsh-ghostty/.zshenv` is not shell config — it exists to repair
sessions from before the "one shell everywhere" unification. The old
Ghostty config pointed `ZDOTDIR` at that directory; a Ghostty still
running from before the change keeps exporting it, and zsh would find no
rc files there and silently fall back to stock defaults (no prompt, no
Homebrew PATH). The file unsets `ZDOTDIR` so zsh re-resolves it back to
`$HOME` and picks up the real config. Inert once no pre-migration process
remains; safe to delete after a reboot. The smoke test covers it.
