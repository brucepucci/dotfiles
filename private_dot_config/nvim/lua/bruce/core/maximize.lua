-- Replacement for szw/vim-maximizer (last released 2022).
-- The whole plugin was winrestcmd() plus `wincmd _` / `wincmd |`.

local M = {}

-- Real (non-floating) windows in this tabpage: floats (hover, diagnostics,
-- which-key, pickers) would otherwise satisfy the "more than one window"
-- test and let us save geometry for a layout that is not split.
local real_wins = require("bruce.core.wins").real_wins

function M.toggle()
    local wins = real_wins()

    -- State is per tabpage. winrestcmd() is only meaningful for the tabpage it
    -- was captured in; a module-level variable would apply tab 1's geometry to
    -- tab 2 and strand tab 1 permanently maximized.
    local saved = vim.t.bruce_maximize

    if saved then
        -- A window opened or closed while maximized, so the saved command no
        -- longer describes this layout. vim.cmd() would apply it silently and
        -- corrupt the sizes rather than erroring, so equalize instead.
        if #wins == saved.count then
            vim.cmd(saved.cmd)
        else
            vim.cmd("wincmd =")
        end
        vim.t.bruce_maximize = nil
        return
    end

    -- Nothing to maximize in a single-window layout; bail rather than storing a
    -- restore command that would be a no-op on the next press.
    if #wins < 2 then
        return
    end

    vim.t.bruce_maximize = { cmd = vim.fn.winrestcmd(), count = #wins }
    vim.cmd("wincmd _") -- max height
    vim.cmd("wincmd |") -- max width
end

return M
