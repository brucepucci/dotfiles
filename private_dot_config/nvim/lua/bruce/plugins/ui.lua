return {
    -- Icon provider for lualine and snacks. mini.icons also mocks the
    -- nvim-web-devicons API, so plugins expecting that module still work.
    {
        "echasnovski/mini.icons",
        lazy = false,
        priority = 950,
        config = function()
            require("mini.icons").setup()
            MiniIcons.mock_nvim_web_devicons()
        end,
    },

    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        opts = { options = { theme = "gruvbox-material" } },
    },

    -- Anti-rot: this keymap set is idiosyncratic, so make it self-documenting
    -- rather than relying on a hand-written table that drifts out of date.
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            preset = "helix",
            spec = {
                { "<leader>f", group = "find" },
                { "<leader>s", group = "split" },
                { "<leader>t", group = "tab" },
                { "<leader>h", group = "hunk (git)" },
                { "<leader>v", group = "diffview" },
                { "<leader>g", group = "git (lazygit)" },
                { "<leader>m", group = "markdown" },
                { "<leader>r", group = "repl" },
            },
        },
    },
}
