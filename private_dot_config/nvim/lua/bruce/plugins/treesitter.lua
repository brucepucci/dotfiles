-- nvim-treesitter, `main` branch.
--
-- This is the 0.12 rewrite, not the old `master`. The classic API
-- (require("nvim-treesitter.configs").setup{ highlight = ... }) no longer
-- exists: the plugin now only installs parsers, and highlighting is started by
-- core via vim.treesitter.start() -- see the FileType autocmd in
-- lua/bruce/core/autocmds.lua.
--
-- Neovim bundles parsers for c, lua, markdown, markdown_inline, query, vim and
-- vimdoc. Python in particular is NOT bundled and has to be installed here.
--
-- Six of the bundled languages are re-listed below on purpose: nvim-treesitter
-- installs matching queries alongside each parser, and a parser/query version
-- mismatch is a real source of highlighting breakage. Installing both together
-- keeps them paired.

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
            local task = require("nvim-treesitter").install(missing)
            -- install() is async. Under `nvim --headless ... +qa` the event loop
            -- is torn down before it finishes, so the documented one-shot
            -- bootstrap installed exactly ONE parser and reported success.
            -- Block only when there is no UI; interactively this must not stall.
            if #vim.api.nvim_list_uis() == 0 and task and task.wait then
                pcall(function()
                    task:wait(600000)
                end)
            end
        end
    end,
}
