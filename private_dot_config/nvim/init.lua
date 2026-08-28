-- Entry point.

-- Hard floor. Below 0.12: vim.lsp.config/enable and vim.hl do not exist, and
-- nvim-treesitter `main` refuses to load. The 0.10 failure mode is a silently
-- dead LSP, which is the exact thing this config was rebuilt to prevent.
if vim.fn.has("nvim-0.12") ~= 1 then
    vim.api.nvim_echo({
        { "This config requires Neovim 0.12+.\n", "ErrorMsg" },
        { "Found: " .. tostring(vim.version()) .. "\n", "WarningMsg" },
        { "Upgrade, or run the previous config: NVIM_APPNAME=nvim-old nvim\n", "WarningMsg" },
    }, true, {})
    return
end

-- mapleader must be set before lazy.nvim loads: plugin specs declare their keys
-- at spec-evaluation time, and a leader set afterwards would not apply to them.
vim.g.mapleader = " "
-- Unused by this config; set because lazy.nvim's own UI binds <localleader>l/i/t
-- inside :Lazy, and it must be defined before lazy loads.
vim.g.maplocalleader = " "

-- Nothing here uses the remote-plugin providers. Leaving python3 enabled costs
-- ~65ms on the first Python buffer, because $VIMRUNTIME/ftplugin/python.vim
-- calls has('python3'), which spawns python3 to hunt for pynvim.
-- (iron.nvim drives a terminal job; markdown-preview ships its own binary.)
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

require("bruce.core.options")
require("bruce.core.keymaps")
require("bruce.core.autocmds")
require("bruce.lazy")
