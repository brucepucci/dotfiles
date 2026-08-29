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
        opts = {
            options = {
                -- Follows 'background', which core/appearance.lua derives from
                -- the palette settings (theme = "system" follows the OS).
                -- lualine re-runs setup() on OptionSet background, and a
                -- function theme re-evaluates then.
                --
                -- The statusline colors come from the active Ghostty themes'
                -- roles (core/theming.lua): segment backgrounds from the
                -- statusline/surface roles, mode segments from the mode_*
                -- roles -- so the statusline matches the terminal for any
                -- theme picked in .chezmoidata/palette.toml.
                theme = function()
                    local theming = require("bruce.core.theming")
                    local light = vim.o.background == "light"
                    if not light and theming.nvim_colorscheme ~= "" then
                        -- curated dark side: lualine ships a theme matching
                        -- the gruvbox-material plugin scheme
                        return "gruvbox-material"
                    end
                    local p = theming.palettes[light and "light" or "dark"]
                    return {
                        normal = {
                            a = { fg = p.on_accent, bg = p.grey_dim, gui = "bold" },
                            b = { fg = p.statusline_fg, bg = p.statusline_accent },
                            c = { fg = p.statusline_fg, bg = p.statusline },
                        },
                        command = { a = { fg = p.on_accent, bg = p.mode_blue, gui = "bold" } },
                        inactive = { a = { fg = p.statusline_fg, bg = p.statusline_accent } },
                        insert = { a = { fg = p.on_accent, bg = p.mode_green, gui = "bold" } },
                        replace = { a = { fg = p.on_accent, bg = p.mode_yellow, gui = "bold" } },
                        terminal = { a = { fg = p.on_accent, bg = p.mode_purple, gui = "bold" } },
                        visual = { a = { fg = p.on_accent, bg = p.mode_red, gui = "bold" } },
                    }
                end,
            },
        },
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
