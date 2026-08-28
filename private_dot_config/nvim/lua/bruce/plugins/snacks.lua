-- snacks.nvim replaces telescope + telescope-fzf-native + nvim-tree +
-- nvim-web-devicons + vim-maximizer's zoom, and supplies the lazygit float.

return {
    "folke/snacks.nvim",
    priority = 1000, -- snacks hooks vim.ui early; it wants >= 1000
    lazy = false,
    opts = {
        bigfile = { enabled = true },
        notifier = { enabled = true },
        quickfile = { enabled = true },
        input = { enabled = true },
        lazygit = { enabled = true },

        picker = {
            enabled = true,
            win = {
                input = {
                    keys = {
                        -- Match the muscle memory from the old telescope config.
                        ["<C-j>"] = { "list_down", mode = { "i", "n" } },
                        ["<C-k>"] = { "list_up", mode = { "i", "n" } },
                        ["<C-q>"] = { "qflist", mode = { "i", "n" } },
                    },
                },
            },
            sources = {
                buffers = {
                    win = {
                        input = {
                            keys = {
                                ["<C-d>"] = { "bufdelete", mode = { "i", "n" } },
                            },
                        },
                    },
                },
            },
        },

        explorer = { enabled = true },

        -- Not used, so keep them from loading at all.
        --
        -- NOTE: :checkhealth still reports missing magick / ghostscript /
        -- tectonic / mmdc and "no kitty graphics protocol" under snacks.
        -- snacks runs every module's health check regardless of `enabled`,
        -- so those errors are expected noise about image rendering we do
        -- not do. Same for the two `vim.ui` errors, which only appear
        -- under --headless because they are wired on UIEnter.
        image = { enabled = false },
        dashboard = { enabled = false },
        scroll = { enabled = false },
    },

    keys = {
        -- files / search
        { "<leader>ff", function() Snacks.picker.files() end, desc = "Find files" },
        { "<leader>fs", function() Snacks.picker.grep() end, desc = "Grep (live)" },
        { "<leader>fc", function() Snacks.picker.grep_word() end, desc = "Grep word under cursor", mode = { "n", "x" } },
        { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
        { "<leader>fh", function() Snacks.picker.help() end, desc = "Help tags" },

        -- explorer: two ways in, both pre-existing muscle memory
        { "<leader>.", function() Snacks.explorer() end, desc = "File explorer" },
        { "<C-h>", function() Snacks.explorer() end, desc = "File explorer" },

        -- lazygit
        { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
        { "<leader>gl", function() Snacks.lazygit.log() end, desc = "Lazygit log" },
    },
}
