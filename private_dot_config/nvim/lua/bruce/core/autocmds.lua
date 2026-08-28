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

-- Brief highlight on yank, so it is obvious what landed in the register.
vim.api.nvim_create_autocmd("TextYankPost", {
    group = aug,
    desc = "Highlight yanked text",
    callback = function()
        vim.hl.on_yank()
    end,
})
