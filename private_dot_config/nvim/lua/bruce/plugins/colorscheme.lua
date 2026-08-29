-- colorscheme.lua -- the editor's colors, decided by the palette settings.
--
-- The two Ghostty themes in .chezmoidata/palette.toml pick one of two paths
-- (rendered into core/theming.lua):
--   * both name the same curated nvim colorscheme (an [apps.nvim] hint in
--     their colors/<name>.toml) -- load it with its options. For the
--     gruvbox pair that is gruvbox-material, byte-for-byte the scheme this
--     config has always shipped.
--   * no curated scheme -- lua/bruce/colors/scheme.lua generates one from
--     the themes' roles; core/appearance.lua applies it before plugins
--     load. gruvbox-material stays installed (lazy-lock) but never runs.

local theming = require("bruce.core.theming")

if theming.nvim_colorscheme == "" then
    return {
        {
            "sainnhe/gruvbox-material",
            cond = false, -- not used: the active themes have no curated scheme
        },
    }
end

return {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 1001, -- ahead of snacks (1000), so nothing renders unstyled
    config = function()
        -- contrast/foreground from the theme files, mapped onto the
        -- gruvbox-material plugin's globals
        vim.g.gruvbox_material_background = theming.nvim_options.gruvbox_material_background -- "hard" | "medium" | "soft"
        vim.g.gruvbox_material_foreground = theming.nvim_options.gruvbox_material_foreground -- "material" | "mix" | "original"
        vim.g.gruvbox_material_better_performance = 1
        vim.cmd.colorscheme(theming.nvim_colorscheme)
    end,
}
