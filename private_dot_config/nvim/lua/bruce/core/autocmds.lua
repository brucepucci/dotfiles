local aug = vim.api.nvim_create_augroup("bruce", { clear = true })

-- ---------------------------------------------------------------------------
-- External writes
--
-- An agent running in an adjacent terminal split rewrites files underneath us.
-- Neovim will not notice on its own: 'autoread' only reloads when something
-- already triggered a re-stat, so we have to ask for one.
--
-- Safety: 'autoread' never discards unsaved local changes. If both we and the
-- agent edited the same buffer, this surfaces the standard W12 prompt instead.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd(
    { "FocusGained", "BufEnter", "CursorHold", "TermClose", "TermLeave" },
    {
        group = aug,
        desc = "Re-stat buffers that may have been rewritten on disk",
        callback = function()
            -- :checktime with no argument already checks every buffer and skips
            -- ones with nothing on disk, so no buftype filter is needed here.
            -- Filtering on the *current* buffer was worse than useless: it made
            -- TermClose/TermLeave dead (the terminal is current when they fire)
            -- and blocked reloads whenever the explorer had focus.
            --
            -- The mode guard stays: :checktime during cmdline-mode aborts what
            -- you are typing. It costs ~0.02ms at 400 open buffers.
            if vim.fn.mode() ~= "c" then
                -- Deferred on purpose: Vim will not reload a buffer while an
                -- autocommand is executing, so calling :checktime inline here
                -- detects the change but postpones the reload indefinitely.
                -- vim.schedule runs it on the main loop, outside that context.
                vim.schedule(function()
                    if vim.fn.mode() ~= "c" then
                        vim.cmd("checktime")
                    end
                end)
            end
        end,
    }
)

vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = aug,
    desc = "Announce reloads -- a buffer changing silently under the cursor is disorienting",
    callback = function()
        vim.notify("Buffer reloaded: changed on disk", vim.log.levels.WARN)
    end,
})

-- ---------------------------------------------------------------------------
-- OS appearance
--
-- macOS can flip Light/Dark while a session is running; Ghostty follows on
-- its own, Neovim needs a nudge on refocus. See core/appearance.lua.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FocusGained", {
    group = aug,
    desc = "Follow the OS light/dark appearance (Ghostty switches itself)",
    callback = function()
        require("bruce.core.appearance").sync()
    end,
})

-- ---------------------------------------------------------------------------
-- Treesitter
--
-- Neovim 0.12 ships parsers but does NOT start highlighting automatically.
-- render-markdown.nvim depends on this being on for markdown buffers.
-- pcall: a filetype with no installed parser is expected, not exceptional.
-- ---------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
    group = aug,
    desc = "Start treesitter highlighting where a parser exists",
    callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)
    end,
})

-- ---------------------------------------------------------------------------
-- Prose wrapping
--
-- 'wrap' is window-local and the global default is off (core/options.lua):
-- code wants long lines visible in full. Prose wants the opposite -- a
-- sentence truncated at the window edge is unreadable. So: markdown and
-- plain text wrap, every other filetype is left alone. The rule must run
-- on the way OUT of prose too -- a positive-only hook would leak wrap=true
-- into whatever code buffer the window shows next.
--
-- Both events, because neither covers the whole story alone:
--   FileType     detection -- opening a file, :set filetype=.
--   BufWinEnter  an already-typed buffer entering a window; without it a
--                second window (or one that switched away and back) misses
--                the setting. Firing twice on a fresh open is fine: the
--                callback is idempotent.
--
-- The rule only ever unwraps a window IT wrapped (flagged below). Runtime
-- ftplugins that manage their own 'wrap' (checkhealth, man) and a manual
-- `:set wrap` in windows this rule never touched must survive buffer
-- switches -- an unconditional else-branch would clobber both, and leave
-- the ftplugin's linebreak/breakindent half-applied underneath. Residual
-- edge, accepted: a window we wrapped that later shows such a buffer gets
-- unwrapped by us (rare -- checkhealth opens its own tab).
-- ---------------------------------------------------------------------------
local WRAPPED_FILETYPES = { markdown = true, text = true }

-- Dotted composite filetypes (markdown.pandoc, text.foo -- plugins set
-- these routinely) count as prose when any component is, mirroring how
-- Neovim itself dispatches ftplugins for dotted names.
local function wants_wrap(ft)
    if WRAPPED_FILETYPES[ft] then
        return true
    end
    for _, part in ipairs(vim.split(ft, ".", { plain = true })) do
        if WRAPPED_FILETYPES[part] then
            return true
        end
    end
    return false
end

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = aug,
    desc = "Soft-wrap prose buffers; unwrap only windows this rule wrapped",
    callback = function(ev)
        local wrap = wants_wrap(vim.bo[ev.buf].filetype)
        -- Every window showing the buffer, in any tabpage. A hidden buffer
        -- matches no window, so a filetype tooling sets on a buffer nothing
        -- displays touches nothing.
        for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
            if wrap then
                -- scope="local" is load-bearing: vim.wo[win].wrap (like
                -- :set) would ALSO rewrite the global default, re-wrapping
                -- every future window in the editor.
                vim.api.nvim_set_option_value("wrap", true, { win = win, scope = "local" })
                vim.w[win].bruce_prose_wrap = true
            elseif vim.w[win].bruce_prose_wrap then
                -- Unwrap only a window this rule wrapped: ftplugins that
                -- manage their own 'wrap' (checkhealth, man) and the user's
                -- manual :set wrap in windows we never touched must survive.
                vim.api.nvim_set_option_value("wrap", false, { win = win, scope = "local" })
                vim.w[win].bruce_prose_wrap = nil
            end
        end
    end,
})

-- ---------------------------------------------------------------------------
-- Application exit
--
-- `:q` from the last session-holding window should leave the app in one
-- command, instead of stranding auxiliary UI (the explorer, pickers,
-- prompts) for a separate quit of each window.
--
-- What counts is this tabpage's real (non-float) windows, classified by
-- what the user loses if the window vanishes:
--
--   holding     a normal file, a terminal (a live REPL or agent job), or
--               an acwrite buffer (written by autocommand) -- the session
--               stays open for these
--   disposable  everything else (nofile, prompt, quickfix, help...) that
--               is also unmodified -- safe to close on the way out
--
-- Buffers never enter the count: a saved hidden buffer is closed along
-- with everything else when the app exits, and an unsaved one blocks
-- the exit on its own.
--
-- The handler never exits Neovim itself -- it closes the disposable
-- windows so the pending `:quit` is quitting the last real window, and
-- Neovim's own exit rules decide the rest. `:q!` keeps its bang, an
-- unsaved buffer refuses with a clean one-line E37, and there is no
-- error to catch or force flag to lose. Another tabpage, or a terminal
-- split in this one, simply keeps the app open with stock `:q`.
-- ---------------------------------------------------------------------------
local HOLDS_SESSION = { [""] = true, terminal = true, acwrite = true }

vim.api.nvim_create_autocmd("QuitPre", {
    group = aug,
    desc = ":q from the last session-holding window closes auxiliary UI so one quit exits",
    callback = function()
        local wins = require("bruce.core.wins").real_wins()
        if #wins < 2 then
            return
        end

        local holding, disposable = {}, {}
        for _, win in ipairs(wins) do
            local buf = vim.api.nvim_win_get_buf(win)
            if HOLDS_SESSION[vim.bo[buf].buftype] then
                holding[#holding + 1] = win
            elseif not vim.bo[buf].modified then
                disposable[#disposable + 1] = win
            end
            -- a modified auxiliary buffer lands in neither list: it keeps
            -- stock `:q` behavior below
        end

        -- Only when auxiliary windows are all that would remain: this is
        -- the last session-holding window, it is the one being quit, and
        -- every other window is disposable. Anything else stays stock.
        if #holding ~= 1 or holding[1] ~= vim.api.nvim_get_current_win() then
            return
        end
        if #disposable ~= #wins - 1 then
            return
        end

        -- pcall: a close can legitimately refuse (a job that will not
        -- die, a window locked by its owner); the pending `:quit` then
        -- behaves exactly as stock, which is the safe fallback.
        for _, win in ipairs(disposable) do
            pcall(vim.api.nvim_win_close, win, false)
        end
    end,
})

-- Brief highlight on yank, so it is obvious what landed in the register.
vim.api.nvim_create_autocmd("TextYankPost", {
    group = aug,
    desc = "Highlight yanked text",
    callback = function()
        vim.hl.on_yank()
    end,
})
