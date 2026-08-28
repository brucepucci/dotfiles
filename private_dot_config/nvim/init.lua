-- Entry point.
--
-- mapleader must be set before lazy.nvim loads: plugin specs declare their keys
-- at spec-evaluation time, and a leader set afterwards would not apply to them.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("bruce.core.options")
require("bruce.core.keymaps")
require("bruce.core.autocmds")
require("bruce.lazy")
