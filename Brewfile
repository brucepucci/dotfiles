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
brew "node"                 # REQUIRED: pi (below) installs via npm
brew "fastfetch"            # banner in ~/.zshrc (guarded, optional)

# --- coding agent ---------------------------------------------------------
# pi, the terminal coding agent. No Homebrew formula exists, so it comes from
# npm -- which is why `node` above is a hard dependency. Unpinned = latest,
# matching the brew entries; `pi --version` shows what landed. Config and
# model defaults come from chezmoi (~/.pi/agent/settings.json); the Z.ai API
# key lives in ~/.zsh/secrets.zsh with the other secrets -- see README,
# new-machine step 5.
system "npm", "install", "-g", "@earendil-works/pi-coding-agent"

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
# font there by hand, glyphs show as placeholder boxes. Ghostty is also a
# hard prerequisite for `chezmoi apply` itself: the palette resolver reads
# its bundled theme catalog (see scripts/ghostty-theme.py).
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
