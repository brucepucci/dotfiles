-- Window classification shared by the modules that reason about layout:
-- core/maximize.lua (geometry save/restore) and core/autocmds.lua (the
-- application-exit rule). One scanner, one definition of "a window that
-- is part of the layout" -- see those call sites for why each needs it.
local M = {}

-- Real (non-floating) windows in the current tabpage. Floats (hover,
-- diagnostics, which-key, pickers, notify toasts) are not part of the
-- split layout: they must never satisfy a "more than one window" test,
-- and they close with the tabpage rather than holding anything open.
-- Scoped to THIS tabpage on purpose -- the same rule core/keymaps.lua
-- applies when it hunts for the REPL window.
function M.real_wins()
    local wins = {}
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(w).relative == "" then
            wins[#wins + 1] = w
        end
    end
    return wins
end

return M
