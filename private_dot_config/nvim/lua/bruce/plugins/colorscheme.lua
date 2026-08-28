return {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 1000, -- load before everything else so nothing renders unstyled
    config = function()
        vim.g.gruvbox_material_background = "hard" -- "hard" | "medium" | "soft"
        vim.g.gruvbox_material_foreground = "material" -- "material" | "mix" | "original"
        vim.g.gruvbox_material_better_performance = 1
        vim.cmd.colorscheme("gruvbox-material")
    end,
}
