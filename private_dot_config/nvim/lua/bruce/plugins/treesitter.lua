-- nvim-treesitter, `main` branch.
--
-- This is the 0.12 rewrite, not the old `master`. The classic API
-- (require("nvim-treesitter.configs").setup{ highlight = ... }) no longer
-- exists: the plugin now only installs parsers, and highlighting is started by
-- core via vim.treesitter.start() -- see the FileType autocmd in
-- lua/bruce/core/autocmds.lua.
--
-- Neovim bundles parsers for c, lua, markdown, markdown_inline, query, vim and
-- vimdoc only. Python in particular has to be installed here.

local ensure = {
    "bash",
    "diff",
    "gitcommit",
    "git_rebase",
    "json",
    "lua",
    "luadoc",
    "markdown",
    "markdown_inline",
    "python",
    "query",
    "regex",
    "toml",
    "vim",
    "vimdoc",
    "yaml",
}

return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter").setup()

        local installed = require("nvim-treesitter.config").get_installed("parsers")
        local missing = vim.tbl_filter(function(lang)
            return not vim.tbl_contains(installed, lang)
        end, ensure)

        if #missing > 0 then
            require("nvim-treesitter").install(missing)
        end
    end,
}
