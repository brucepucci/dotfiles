-- scheme.lua -- the colorscheme, generated from the active Ghostty themes.
--
-- Built from the themes' semantic roles (core/theming.lua) at apply time,
-- so the editor matches the terminal for ANY theme picked in
-- theme.toml -- the same source Ghostty itself renders
-- from. Applied by core/appearance.lua: at startup (before plugins) and
-- again whenever 'background' changes, exactly like a shipped colorscheme.

local theming = require("bruce.core.theming")

local M = {}

-- The 16 ANSI colors, verbatim from the theme's own palette, so :terminal
-- and any ANSI-emitting tool inside nvim renders exactly what the terminal
-- does -- including the bright variants, which many themes differentiate
-- (e.g. Gruvbox Dark's bright red vs its normal red).
local function terminal_colors(pal)
    for i, color in ipairs(pal.terminal) do
        vim.g["terminal_color_" .. (i - 1)] = color
    end
end

-- Highlight groups, from roles. Ordering is cosmetic (a plain lookup table);
-- the group set targets what this config actually renders: normal editing,
-- treesitter, diffs, diagnostics, completion/floating UI, statusline-adjacent
-- groups, and the plugins in lua/bruce/plugins/.
local function groups(p)
    return {
        Normal = { fg = p.fg, bg = p.bg },
        NormalNC = { fg = p.fg, bg = p.bg },
        NormalFloat = { fg = p.fg, bg = p.surface },
        FloatBorder = { fg = p.grey_dim, bg = p.surface },
        Cursor = { fg = p.bg, bg = p.fg },
        CursorLine = { bg = p.bg_deep },
        CursorColumn = { bg = p.bg_deep },
        ColorColumn = { bg = p.bg_deep },
        LineNr = { fg = p.grey_dim },
        CursorLineNr = { fg = p.orange, bold = true },
        SignColumn = { fg = p.fg, bg = p.bg },
        FoldColumn = { fg = p.grey_dim },
        WinSeparator = { fg = p.grey_dim },
        VertSplit = { link = "WinSeparator" },
        NonText = { fg = p.grey_dim },
        Whitespace = { fg = p.grey_dim },
        Conceal = { fg = p.grey_dim },
        EndOfBuffer = { fg = p.grey_dim },

        -- search / selection
        Visual = { bg = p.statusline_accent },
        Search = { fg = p.bg, bg = p.yellow },
        CurSearch = { fg = p.bg, bg = p.orange, bold = true },
        IncSearch = { fg = p.bg, bg = p.orange },
        Substitute = { bg = p.tint_red },
        MatchParen = { bg = p.statusline_accent, bold = true },
        Pmenu = { fg = p.fg, bg = p.surface },
        PmenuSel = { fg = p.on_accent, bg = p.statusline_accent },
        PmenuSbar = { bg = p.surface },
        PmenuThumb = { bg = p.grey_dim },
        WildMenu = { link = "PmenuSel" },

        -- messages / prompts
        MsgArea = { fg = p.fg },
        ModeMsg = { fg = p.grey },
        MoreMsg = { fg = p.aqua },
        Question = { fg = p.aqua },
        WarningMsg = { fg = p.yellow },
        ErrorMsg = { fg = p.red, bold = true },
        Directory = { fg = p.blue },
        Title = { fg = p.orange, bold = true },
        Todo = { fg = p.yellow, bold = true },

        -- statusline / tabs (lualine carries its own; these cover the rest)
        StatusLine = { fg = p.statusline_fg, bg = p.statusline },
        StatusLineNC = { fg = p.grey_dim, bg = p.bg_deep },
        TabLine = { fg = p.fg, bg = p.surface },
        TabLineSel = { fg = p.fg, bg = p.statusline_accent, bold = true },
        TabLineFill = { fg = p.grey_dim, bg = p.bg },

        -- syntax (treesitter captures fall through to these)
        Comment = { fg = p.grey_neutral },
        Constant = { fg = p.purple },
        String = { fg = p.green },
        Character = { fg = p.green },
        Number = { fg = p.purple },
        Boolean = { fg = p.purple },
        Float = { fg = p.purple },
        Identifier = { fg = p.fg },
        Function = { fg = p.blue },
        Statement = { fg = p.red },
        Conditional = { fg = p.red },
        Repeat = { fg = p.red },
        Label = { fg = p.red },
        Operator = { fg = p.fg },
        Keyword = { fg = p.red },
        Exception = { fg = p.red },
        PreProc = { fg = p.purple },
        Include = { fg = p.red },
        Define = { fg = p.purple },
        Macro = { fg = p.purple },
        PreCondit = { fg = p.purple },
        Type = { fg = p.yellow },
        StorageClass = { fg = p.yellow },
        Structure = { fg = p.yellow },
        Typedef = { fg = p.yellow },
        Special = { fg = p.orange },
        SpecialChar = { fg = p.orange },
        Tag = { fg = p.blue },
        Delimiter = { fg = p.grey_neutral },
        SpecialComment = { fg = p.grey_neutral },
        Debug = { fg = p.orange },
        Underlined = { fg = p.blue, underline = true },
        Ignore = { fg = p.grey_dim },
        Error = { fg = p.red },

        -- treesitter captures that differ from the above
        ["@comment"] = { link = "Comment" },
        ["@string"] = { link = "String" },
        ["@string.escape"] = { fg = p.orange },
        ["@character"] = { link = "Character" },
        ["@number"] = { link = "Number" },
        ["@boolean"] = { link = "Boolean" },
        ["@function"] = { link = "Function" },
        ["@function.call"] = { link = "Function" },
        ["@method"] = { link = "Function" },
        ["@constructor"] = { fg = p.orange },
        ["@keyword"] = { link = "Keyword" },
        ["@keyword.function"] = { link = "Keyword" },
        ["@keyword.return"] = { link = "Keyword" },
        ["@conditional"] = { link = "Conditional" },
        ["@repeat"] = { link = "Repeat" },
        ["@label"] = { fg = p.blue },
        ["@operator"] = { link = "Operator" },
        ["@exception"] = { link = "Exception" },
        ["@type"] = { link = "Type" },
        ["@type.builtin"] = { fg = p.orange },
        ["@type.qualifier"] = { link = "Keyword" },
        ["@attribute"] = { fg = p.purple },
        ["@variable"] = { link = "Identifier" },
        ["@variable.builtin"] = { fg = p.orange },
        ["@property"] = { fg = p.fg },
        ["@parameter"] = { fg = p.fg },
        ["@constant"] = { link = "Constant" },
        ["@constant.builtin"] = { fg = p.orange },
        ["@namespace"] = { fg = p.blue },
        ["@symbol"] = { link = "Constant" },
        ["@punctuation.delimiter"] = { fg = p.grey_neutral },
        ["@punctuation.bracket"] = { fg = p.fg },
        ["@punctuation.special"] = { fg = p.orange },
        ["@tag"] = { fg = p.blue },
        ["@tag.attribute"] = { fg = p.aqua },
        ["@tag.delimiter"] = { fg = p.grey_neutral },

        -- diffs (vim's groups; gitsigns and diffview use them or their own,
        -- which default to these)
        DiffAdd = { fg = p.fg, bg = p.tint_green },
        DiffChange = { fg = p.fg, bg = p.surface },
        DiffDelete = { fg = p.fg, bg = p.tint_red },
        DiffText = { fg = p.fg, bg = p.statusline_accent, bold = true },
        diffAdded = { fg = p.green },
        diffRemoved = { fg = p.red },
        diffChanged = { fg = p.yellow },
        diffOldFile = { fg = p.orange },
        diffNewFile = { fg = p.green },
        diffFile = { fg = p.blue },
        diffLine = { fg = p.grey_dim },
        diffIndexLine = { fg = p.purple },
        GitSignsAdd = { fg = p.green },
        GitSignsChange = { fg = p.yellow },
        GitSignsDelete = { fg = p.red },

        -- diagnostics
        DiagnosticError = { fg = p.red },
        DiagnosticWarn = { fg = p.yellow },
        DiagnosticInfo = { fg = p.blue },
        DiagnosticHint = { fg = p.aqua },
        DiagnosticOk = { fg = p.green },
        DiagnosticUnderlineError = { sp = p.red, undercurl = true },
        DiagnosticUnderlineWarn = { sp = p.yellow, undercurl = true },
        DiagnosticUnderlineInfo = { sp = p.blue, undercurl = true },
        DiagnosticUnderlineHint = { sp = p.aqua, undercurl = true },
        DiagnosticVirtualTextError = { fg = p.red, bg = p.tint_red },
        DiagnosticVirtualTextWarn = { fg = p.yellow, bg = p.surface },
        DiagnosticVirtualTextInfo = { fg = p.blue, bg = p.surface },
        DiagnosticVirtualTextHint = { fg = p.aqua, bg = p.surface },

        -- lsp / misc UI
        LspReferenceText = { bg = p.surface },
        LspReferenceRead = { bg = p.surface },
        LspReferenceWrite = { bg = p.surface },
        WhichKey = { fg = p.fg },
        WhichKeyGroup = { fg = p.blue },
        WhichKeyDesc = { fg = p.fg },
        WhichKeySeparator = { fg = p.grey_dim },
        NetrwDir = { fg = p.blue },
        NetrwClassify = { fg = p.orange },
        NetrwExe = { fg = p.green },
        SnacksPickerBorder = { fg = p.grey_dim },
        SnacksPickerInputBorder = { fg = p.grey_dim },
        RenderMarkdownH1 = { fg = p.orange, bold = true },
        RenderMarkdownH2 = { fg = p.yellow, bold = true },
        RenderMarkdownH3 = { fg = p.green, bold = true },
        RenderMarkdownLink = { fg = p.blue, underline = true },
        RenderMarkdownCode = { bg = p.surface },
    }
end

function M.apply(background)
    local p = theming.palettes[background == "light" and "light" or "dark"]
    vim.cmd("hi clear")
    vim.g.colors_name = "dotfiles"
    terminal_colors(p)
    for name, spec in pairs(groups(p)) do
        vim.api.nvim_set_hl(0, name, spec)
    end
    -- Let plugins that own groups (gitsigns, etc.) re-apply theirs, the way
    -- a shipped colorscheme would.
    vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "dotfiles", modeline = false })
end

return M
