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
                -- Follows 'background', which core/appearance.lua sets from the
                -- OS: lualine re-runs setup() on OptionSet background, and a
                -- function theme re-evaluates then. Dark side is lualine's
                -- built-in gruvbox-material; light side is a hand-rolled table
                -- because lualine ships no material-light theme (its
                -- "gruvbox_light" is plain Gruvbox, off-palette next to
                -- gruvbox-material's light rendering). Colors are Gruvbox
                -- Material Light Hard, taken verbatim from the colorscheme's
                -- own palette (autoload/gruvbox_material.vim), mirroring the
                -- segment shape of lualine's gruvbox-material (dark) theme.
                theme = function()
                    if vim.o.background ~= "light" then
                        return "gruvbox-material"
                    end
                    local fg = "#654735" -- fg0
                    local surface1, surface2 = "#f5edca", "#eee0b7" -- bg1/bg_statusline3
                    local on_accent = "#f9f5d7" -- bg0
                    return {
                        normal = {
                            a = { fg = on_accent, bg = "#a89984", gui = "bold" },
                            b = { fg = fg, bg = surface2 },
                            c = { fg = fg, bg = surface1 },
                        },
                        command = { a = { fg = on_accent, bg = "#45707a", gui = "bold" } }, -- blue
                        inactive = { a = { fg = fg, bg = surface2 } },
                        insert = { a = { fg = on_accent, bg = "#6c782e", gui = "bold" } }, -- green
                        replace = { a = { fg = on_accent, bg = "#b47109", gui = "bold" } }, -- yellow
                        terminal = { a = { fg = on_accent, bg = "#945e80", gui = "bold" } }, -- purple
                        visual = { a = { fg = on_accent, bg = "#c14a4a", gui = "bold" } }, -- red
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
