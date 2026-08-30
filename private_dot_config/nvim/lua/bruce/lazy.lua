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

    -- None of the plugins here are rockspecs, so skip the hererocks
    -- bootstrap and its :checkhealth complaint.
    rocks = { enabled = false },

    -- No install-time colorscheme is listed: ours is generated from the
    -- active Ghostty themes (core/appearance + colors/scheme), applied
    -- before lazy even loads, so there is nothing to wait for. lazy's own
    -- "habamax" fallback covers the bootstrap window anyway.

    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "tarPlugin",
                "tutor",
                "zipPlugin",
                -- 0.12 replaced netrw with TWO plugins: legacy netrwPlugin.vim
                -- and the new net.lua. Disabling only the old name left net.lua
                -- sourcing at startup. The snacks explorer replaces it, and
                -- gx is a core mapping since 0.11, so nothing is lost.
                "netrwPlugin",
                "net",
                "matchit",
                "matchparen",
                "rplugin",
                "spellfile",
            },
        },
    },
})
