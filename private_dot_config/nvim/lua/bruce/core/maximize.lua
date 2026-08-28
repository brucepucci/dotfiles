-- Replacement for szw/vim-maximizer (last released 2022).
-- The whole plugin was winrestcmd() plus `wincmd _` / `wincmd |`.

local M = {}

local saved -- nil while not maximized

function M.toggle()
    if saved then
        vim.cmd(saved)
        saved = nil
        return
    end

    -- Nothing to maximize in a single-window layout; bail rather than storing
    -- a restore command that would be a no-op on the next press.
    if #vim.api.nvim_tabpage_list_wins(0) < 2 then
        return
    end

    saved = vim.fn.winrestcmd()
    vim.cmd("wincmd _") -- max height
    vim.cmd("wincmd |") -- max width
end

return M
