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
                { "<leader>g", group = "git" },
                { "<leader>s", group = "split/window" },
                { "<leader>t", group = "tab" },
                { "<leader>b", group = "buffer" },
                { "<leader>r", group = "repl" },
                { "<leader>m", group = "markdown" },
                { "<leader>?", desc = "Cheatsheet" },
            },
        },
    },
}
