-- lazydev.nvim: lua_ls set up properly for editing THIS config.
--
-- The problem it fixes: lua_ls statically analyzes Lua with zero knowledge
-- of Neovim, so every `vim.` reference warned "Undefined global `vim`" -- the
-- yellow triangles on every config file in the explorer were all this.
-- lazydev wires lua_ls to Neovim's bundled API type definitions (and loads
-- per-plugin types on demand), which makes the false warnings disappear AND
-- gives real vim.* types: hover, completion, and catching actual typos.
--
-- It augments vim.lsp.config("lua_ls") by itself; the settings block in
-- lsp.lua still applies, because vim.lsp.config merges.
--
-- Library entries load types only when their `words` pattern appears in the
-- buffer, so a Lua file costs nothing until it mentions the plugin.

return {
    "folke/lazydev.nvim",
    ft = "lua",
    cmd = "LazyDev",
    opts = {
        library = {
            -- luv/libuv types when `vim.uv` is seen
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            -- runtime globals that plugins inject, with their real types
            { path = "snacks.nvim", words = { "Snacks" } },
            { path = "mini.icons", words = { "MiniIcons" } },
        },
    },
}
