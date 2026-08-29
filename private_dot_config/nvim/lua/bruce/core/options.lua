local opt = vim.opt

-- line numbers
opt.relativenumber = true
opt.number = true

-- tabs & indentation (4 spaces, PEP8-friendly)
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true

-- line wrapping
opt.wrap = false

-- search
opt.ignorecase = true
opt.smartcase = true

-- appearance
opt.cursorline = true
opt.termguicolors = true
-- 'background' is NOT pinned here: it follows the OS appearance (light/dark)
-- via core/appearance.lua, which runs before plugins and re-syncs on
-- FocusGained. Pinning it would fight that.
opt.signcolumn = "yes" -- always on, so gitsigns/diagnostics never shift the text

-- backspace
opt.backspace = "indent,eol,start"

-- clipboard: append, not assign -- assigning would drop any existing value
opt.clipboard:append("unnamedplus")

-- split windows
opt.splitright = true
opt.splitbelow = true

-- treat dash-separated words as a single word textobject (append, not assign)
opt.iskeyword:append("-")

-- Pick up files rewritten on disk by an agent running in an adjacent pane.
-- Paired with the :checktime autocmds in core/autocmds.lua -- 'autoread' alone
-- only acts when Neovim already has reason to re-stat the file.
opt.autoread = true

-- Drives CursorHold, which is how external writes get noticed.
-- (gitsigns' inline blame has its own delay setting and ignores this.)
opt.updatetime = 300
