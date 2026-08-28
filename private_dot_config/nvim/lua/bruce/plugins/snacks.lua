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
            -- <C-j>/<C-k>/<C-q> need no overrides: snacks already binds them
            -- to list_down/list_up/qflist, matching the old telescope config.
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
        -- A live search of every mapping in the session, jumping to its
        -- definition. This is the one keymap reference that cannot go stale.
        { "<leader>fk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
        { "<leader>fr", function() Snacks.picker.resume() end, desc = "Resume last picker" },

        -- Explorer is <leader>. only. <C-h> went back to window-left so the
        -- <C-h/j/k/l> set is consistent -- and because Snacks.explorer() toggles,
        -- reaching left toward an open tree used to close it.
        { "<leader>.", function() Snacks.explorer() end, desc = "File explorer" },

        -- lazygit
        { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
    },
}
