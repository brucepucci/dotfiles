-- blink.cmp replaces nvim-cmp + cmp-buffer + cmp-path + cmp-nvim-lsp +
-- cmp_luasnip + LuaSnip + lspkind (7 plugins -> 2).

return {
    "saghen/blink.cmp",
    event = "InsertEnter",
    dependencies = { "rafamadriz/friendly-snippets" },

    -- Pulls a prebuilt Rust matcher binary; avoids needing a Rust toolchain.
    version = "1.*",

    ---@module 'blink.cmp'
    opts = {
        keymap = {
            -- "none" is load-bearing: any other preset merges blink's own
            -- <C-n>/<C-p>/<C-y> defaults on top of these.
            preset = "none",
            ["<C-k>"] = { "select_prev", "fallback" },
            ["<C-j>"] = { "select_next", "fallback" },
            ["<C-b>"] = { "scroll_documentation_up", "fallback" },
            ["<C-f>"] = { "scroll_documentation_down", "fallback" },
            ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
            ["<C-e>"] = { "hide", "fallback" },
            ["<CR>"] = { "accept", "fallback" },
        },

        appearance = { nerd_font_variant = "mono" },

        completion = {
            -- Equivalent to nvim-cmp's confirm({ select = false }): nothing is
            -- chosen until you move to it, so <CR> never inserts a surprise.
            list = { selection = { preselect = false, auto_insert = false } },
            documentation = { auto_show = true, auto_show_delay_ms = 200 },
        },

        sources = { default = { "lsp", "path", "snippets", "buffer" } },
        fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
}
