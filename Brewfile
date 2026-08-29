# Dependencies for this config.
#
# Not run by chezmoi. Install with:
#   brew bundle --file="$(chezmoi source-path)/Brewfile"
#
# Homebrew is the only supported install path on every OS -- Debian 12 and
# Ubuntu 22.04 cannot supply Neovim 0.12, lua-language-server, marksman, or
# tree-sitter-cli >= 0.26.1 from their own repos. This file is evaluated as
# Ruby, so OS.mac? / OS.linux? gate the platform-specific entries.

# --- editor ---------------------------------------------------------------
brew "neovim"               # 0.12+ REQUIRED: nvim-treesitter main branch, vim.hl

# --- pickers and search ---------------------------------------------------
brew "ripgrep"              # snacks.picker grep -- no fallback, <leader>fs needs it
brew "fd"                   # snacks.picker file finding (falls back to find)
brew "fzf"                  # shell fuzzy-find; nvim's picker has its own matcher

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
brew "node"                 # REQUIRED: pi (below) installs via npm; also builds
                            # markdown-preview on aarch64 Linux
brew "fastfetch"            # banner in the Ghostty zshrc (guarded, optional)

# --- coding agent ---------------------------------------------------------
# pi, the terminal coding agent. No Homebrew formula exists, so it comes from
# npm -- which is why `node` above is a hard dependency. Unpinned = latest,
# matching the brew entries; `pi --version` shows what landed. Config and
# model defaults come from chezmoi (~/.pi/agent/settings.json); the Z.ai API
# key is a secret and is NOT in this repo -- see README, new-machine step 5.
system "npm", "install", "-g", "@earendil-works/pi-coding-agent"

# --- macOS only -----------------------------------------------------------
# The config renders Nerd Font glyphs (diagnostics, markdown icons, file
# icons). Ghostty ships one as its default face, so this is invisible here --
# but any other terminal shows placeholder boxes.
cask "font-jetbrains-mono-nerd-font" if OS.mac?
cask "ghostty" if OS.mac?

# --- Linux only -----------------------------------------------------------
# macOS has pbcopy built in. On Linux, options.lua's clipboard=unnamedplus has
# nothing to talk to, and every yank SILENTLY fails to reach the system
# clipboard -- only :checkhealth reports it. Install both; Neovim picks
# whichever matches the session (Wayland vs X11).
#
# WSL is different again: neither of these works. Install win32yank instead --
# see the WSL note in the README.
brew "wl-clipboard" if OS.linux?
brew "xclip" if OS.linux?
