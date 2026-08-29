-- appearance.lua -- follow the macOS interface style.
--
-- The whole terminal stack renders light when the OS is Light: Ghostty
-- switches itself via its `theme = light:...,dark:...` line, the zsh prompt
-- follows the terminal's indexed colors by design, and this module does the
-- same for Neovim. Dark stays the default where the probe is unavailable
-- (Linux, non-macOS hosts), which is exactly today's look.
--
-- Called from init.lua before plugins load, so the colorscheme renders the
-- right palette from the first frame, and again from autocmds.lua on
-- FocusGained, so flipping the OS mid-session needs no restart.

local M = {}

-- `defaults read -g AppleInterfaceStyle` prints "Dark" and exits 0 in dark
-- mode; in light mode the key does not exist and it exits nonzero.
function M.detect()
    if vim.fn.executable("defaults") ~= 1 then
        return "dark"
    end
    local style = vim.trim(vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }))
    if vim.v.shell_error == 0 and style == "Dark" then
        return "dark"
    end
    return "light"
end

-- Set 'background' from the OS, and react when it changed.
function M.sync()
    local detected = M.detect()
    if vim.o.background == detected then
        return
    end
    vim.o.background = detected
    -- Setting 'background' alone does not recolor an already-loaded scheme:
    -- gruvbox-material picks its palette when :colorscheme runs. Re-issue it
    -- (only meaningful once a scheme is loaded; at startup the plugin's own
    -- colorscheme call right after this renders the new palette anyway).
    if vim.g.colors_name then
        vim.cmd.colorscheme(vim.g.colors_name)
    end
    -- Let listeners react (lualine needs no nudge -- it re-setups itself on
    -- OptionSet background -- but anything else can hook this).
    vim.api.nvim_exec_autocmds("User", { pattern = "AppearanceChanged", modeline = false })
end

return M
