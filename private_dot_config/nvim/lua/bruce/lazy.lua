-- lazy.nvim bootstrap and setup.
--
-- Plugin specs live one-per-file in lua/bruce/plugins/ and are auto-imported,
-- so adding a plugin means dropping in a file -- no edit to this file or to
-- init.lua.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = { { import = "bruce.plugins" } },

    -- Pinned by lazy-lock.json, which is committed. Updates are deliberate:
    --   :Lazy update  ->  test  ->  chezmoi re-add ~/.config/nvim/lazy-lock.json
    checker = { enabled = false },
    change_detection = { notify = false },

    install = { colorscheme = { "gruvbox-material", "habamax" } },

    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
                "netrwPlugin",
            },
        },
    },
})
