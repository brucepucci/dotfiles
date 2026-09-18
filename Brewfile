# Dependencies for this config.
#
# Not run by chezmoi. Install with:
#   brew bundle --file="$(chezmoi source-path)/Brewfile"
#
# macOS only -- Homebrew on a Mac is the one supported install path (the
# repo's scope; see README).

# --- editor ---------------------------------------------------------------
brew "neovim"               # 0.12+ REQUIRED: nvim-treesitter main branch, vim.hl

# --- pickers and search ---------------------------------------------------
brew "ripgrep"              # snacks.picker grep -- no fallback, <leader>fs needs it
brew "fd"                   # snacks.picker file finding (falls back to find)
brew "fzf"                  # shell fuzzy-find: Ctrl-R/Ctrl-T/Alt-C, wired in
                            # ~/.zshrc; nvim's picker has its own matcher

# --- shell quality of life ----------------------------------------------
# Guarded blocks in ~/.zshrc source these after compinit; a machine without
# them just skips the feature. zsh-syntax-highlighting MUST be sourced last
# in ~/.zshrc (it wraps ZLE widgets at load time).
brew "zsh-autosuggestions"     # fish-style ghost-text suggestions from history
brew "zsh-syntax-highlighting" # live command-validity coloring (red before Enter)

# --- git / review ---------------------------------------------------------
brew "lazygit"              # <leader>gg
brew "git-delta"            # pager for `git diff` and lazygit; set in ~/.gitconfig
brew "gh"                   # REQUIRED to clone this private repo -- see README

# --- language servers -----------------------------------------------------
# From Homebrew rather than Mason: one package manager, versions visible here.
brew "ruff"                 # python lint + format -- `ruff server`
brew "pyright"              # python types -- provides pyright-langserver
brew "lua-language-server"  # lua_ls, for editing this config
brew "marksman"             # markdown

# --- python ---------------------------------------------------------------
brew "uv"                   # envs and packaging
brew "ipython"              # the REPL iron.nvim drives (<leader>`)

# --- build / runtime ------------------------------------------------------
brew "tree-sitter-cli"      # nvim-treesitter `main` compiles parsers (needs >= 0.26.1)
brew "node"                 # pulled in by pi-coding-agent (below) anyway; explicit
                            # because markdown-preview.nvim's fallback build
                            # shells out to npm when upstream ships no binary
brew "fastfetch"            # banner in ~/.zshrc (guarded, optional)

# --- coding agent ---------------------------------------------------------
# pi, the terminal coding agent. homebrew/core carries the formula (it wraps
# the same npm package, kept in its own keg under libexec, and depends on
# `node`), so it upgrades with everything else -- `brew upgrade`, never
# `pi update`, which would write into a brew-owned keg. Do NOT go back to
# `npm install -g`: both want to own /opt/homebrew/bin/pi, and whichever
# lands second leaves the other shadowed or the symlink gone entirely.
# Unpinned = latest, matching the brew entries; `pi --version` shows what
# landed. Config and model defaults come from chezmoi
# (~/.pi/agent/settings.json); the Z.ai API key lives in ~/.zsh/secrets.zsh
# with the other secrets -- see README, new-machine step 5.
brew "pi-coding-agent"

# --- agent multiplexer ----------------------------------------------------
# herdr, a terminal multiplexer for coding-agent sessions (Rust client +
# `herdr server` daemon over a unix socket). `brew services start herdr`
# runs the daemon at login; or skip the service and let the client start it
# on demand (the current choice). chezmoi manages ~/.config/herdr/
# config.toml (theme + update settings), and ~/.zshrc wraps the binary so
# the self-updater refuses: `brew upgrade herdr` owns upgrades. See
# docs/herdr.md.
brew "herdr"

# --- remote session continuity --------------------------------------------
# tmux keeps sessions alive across disconnects: leave the desk, reattach
# from a phone over SSH (README "Picking up from another device"). 3.5+ is
# needed for extended-keys-format csi-u in ~/.tmux.conf; without those
# settings pi's Shift+Enter collapses to plain Enter under tmux.
brew "tmux"

# --- macOS: the GUI pieces -----------------------------------------------
# The config and the zsh prompt render Nerd Font glyphs (diagnostics,
# markdown icons, the prompt's git branch mark). Ghostty ships one as its
# default face, but Terminal.app and iTerm2 do not — without setting the
# font there by hand, glyphs show as placeholder boxes. Ghostty is the
# terminal this setup standardizes on; the colors it renders come from
# this repo's own theme mirror (themes/), so the app is NOT a
# prerequisite for `chezmoi apply`.
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
