# Dependencies for the Neovim config.
#
# Not managed or run by chezmoi. Install with:
#   brew bundle --file="$(chezmoi source-path)/Brewfile"

brew "neovim"               # 0.12+ required: vim.lsp.config, built-in gc comments
brew "ripgrep"              # snacks.picker grep
brew "fd"                   # snacks.picker file finding
brew "fzf"                  # shell fuzzy-find
brew "lazygit"              # <leader>gg
brew "git-delta"            # git pager -- see "Manual setup" in README
brew "gh"                   # GitHub CLI

# Language servers (installed via Homebrew rather than Mason, so there is one
# package manager and the versions live in a reviewable file)
brew "ruff"                 # python lint + format -- `ruff server`
brew "pyright"              # python types -- provides pyright-langserver
brew "lua-language-server"  # lua_ls, for editing this config
brew "marksman"             # markdown

brew "uv"                   # python envs
brew "tree-sitter-cli"      # nvim-treesitter `main` builds parsers with this
brew "node"                 # markdown-preview.nvim
