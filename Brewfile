# Dependencies for the Neovim config.
#
# Not managed or run by chezmoi. Install with:
#   brew bundle --file="$(chezmoi source-path)/Brewfile"

brew "neovim"               # 0.12+ REQUIRED: nvim-treesitter main branch, vim.hl
brew "ripgrep"              # snacks.picker grep
brew "fd"                   # snacks.picker file finding
brew "fzf"                  # shell fuzzy-find (not used by nvim; the picker has its own)
brew "lazygit"              # <leader>gg
brew "git-delta"            # git pager -- see "Manual setup" in README
brew "gh"                   # GitHub CLI -- REQUIRED to clone this private repo

# Language servers (installed via Homebrew rather than Mason, so there is one
# package manager and the versions live in a reviewable file)
brew "ruff"                 # python lint + format -- `ruff server`
brew "pyright"              # python types -- provides pyright-langserver
brew "lua-language-server"  # lua_ls, for editing this config
brew "marksman"             # markdown

brew "uv"                   # python envs
brew "ipython"              # the REPL iron.nvim drives (<leader>`)
brew "tree-sitter-cli"      # nvim-treesitter `main` builds parsers with this (needs >= 0.26.1)
brew "node"                 # fallback only; markdown-preview ships its own binary

# The config renders Nerd Font glyphs (diagnostics, markdown icons, file
# icons). Ghostty happens to ship a Nerd Font as its default face, so this is
# invisible here -- but on any other terminal you get placeholder boxes.
# brew bundle skips cask lines on Linux automatically.
cask "font-jetbrains-mono-nerd-font"
