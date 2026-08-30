-- appearance.lua -- the light/dark mode, from the palette settings.
--
-- The mode is rendered into core/theming.lua from .chezmoidata/palette.toml:
--   theme = "system" -- follow the macOS interface style live, the way
--     Ghostty's theme pair and the prompt's indexed colors do; flipping the
--     OS mid-session needs no restart (Dark stays the default where the
--     probe is unavailable, i.e. non-macOS hosts).
--   theme = "light"/"dark" -- pin the whole stack, OS be damned.
--
-- The colorscheme itself is generated from the active Ghostty themes' roles
-- (lua/bruce/colors/scheme.lua), so the editor matches the terminal for any
-- theme picked in the settings.
--
-- Called from init.lua before plugins load, so the first frame renders the
-- right palette, and again from autocmds.lua on FocusGained.

local theming = require("bruce.core.theming")

local M = {}

-- Whether the scheme for the current background has been applied at least
-- once: the first sync() must apply even when 'background' already matches,
-- because at startup nothing else would.
local applied = false

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

-- Resolve the mode, set 'background', and (re)render the scheme if needed.
function M.sync()
    local detected
    if theming.mode == "system" then
        detected = M.detect()
    else
        detected = theming.mode
    end
    if vim.o.background == detected and applied then
        return
    end
    vim.o.background = detected
    applied = true
    require("bruce.colors.scheme").apply(detected)
    -- Let listeners react (lualine needs no nudge -- it re-setups itself on
    -- OptionSet background -- but anything else can hook this).
    vim.api.nvim_exec_autocmds("User", { pattern = "AppearanceChanged", modeline = false })
end

return M
