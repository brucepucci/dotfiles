-- Core keymaps. Plugin-owned keys live with their plugin spec in
-- lua/bruce/plugins/*.lua so lazy-loading triggers stay accurate.
--
-- Scheme: <leader> + one letter for the DOMAIN, one for the verb/object.
-- Capital = wider scope. Chords (<C-hjkl>) are always movement, never actions.
--
-- mapleader is set in init.lua (must precede lazy.nvim).

local keymap = vim.keymap

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode" })

keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

keymap.set("n", "x", '"_x', { desc = "Delete char without yanking" })

-- increment / decrement
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

-- splits
keymap.set("n", "<leader>st", "<C-w>v", { desc = "Split vertically" })
keymap.set("n", "<leader>sT", "<C-w>s", { desc = "Split horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Equalize splits" })
keymap.set("n", "<leader>sw", ":close<CR>", { desc = "Close split" })

-- tabs
keymap.set("n", "<leader>tt", ":tabnew<CR>", { desc = "New tab" })
keymap.set("n", "<leader>tw", ":tabclose<CR>", { desc = "Close tab" })
keymap.set("n", "<leader>tl", ":tabn<CR>", { desc = "Next tab" })
keymap.set("n", "<leader>th", ":tabp<CR>", { desc = "Previous tab" })

-- buffers
keymap.set("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer" })

-- window navigation. All four directions, consistently -- the file explorer
-- lives on <leader>. only.
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window below" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window above" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- terminal mode: escape back to the code window from the REPL.
-- <C-j> is deliberately absent -- the REPL is the bottom split, nothing below.
keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Leave terminal, window above" })
keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Leave terminal, window left" })
keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Leave terminal, window right" })

-- maximize / restore the current window (replaces vim-maximizer)
keymap.set("n", "<leader>sm", function()
    require("bruce.core.maximize").toggle()
end, { desc = "Maximize window (toggle)" })

-- REPL window visibility toggle.
--
-- Scoped deliberately: only Iron's own terminal, only in the current tabpage,
-- only real (non-floating) windows. A bare "first terminal buffer" search would
-- close a :terminal split, or the lazygit float, or a REPL sitting in another
-- tab -- all of which looked like the toggle doing nothing.
keymap.set("n", "<leader>`", function()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        if
            vim.bo[buf].buftype == "terminal"
            and vim.bo[buf].filetype == "iron"
            and vim.api.nvim_win_get_config(win).relative == ""
        then
            if #wins > 1 then
                vim.api.nvim_win_close(win, false)
            end
            return
        end
    end
    vim.cmd("IronRepl")
end, { desc = "Toggle REPL window" })

-- Diagnostics / docs.
-- Wrapped in functions on purpose: referencing vim.diagnostic.open_float or
-- vim.lsp.buf.hover directly forces vim.lsp and vim.diagnostic to load during
-- startup, before any file is even open (~4ms).
keymap.set("n", "<leader>d", function()
    vim.diagnostic.open_float()
end, { desc = "Line diagnostics" })
keymap.set("n", "<leader>/", function()
    vim.lsp.buf.hover()
end, { desc = "Hover docs" })

-- Docs living with the config. One key, then pick -- rather than <leader>?
-- plus <leader>??, where the first would be a strict prefix of the second and
-- would stall for 'timeoutlen' on every press. <leader>? is the discoverable
-- entry point; which-key advertises it the moment you press <leader>.
keymap.set("n", "<leader>?", function()
    local dir = vim.fn.stdpath("config") .. "/docs"
    local files = vim.fn.glob(dir .. "/*.md", false, true)
    table.sort(files)
    vim.ui.select(files, {
        prompt = "Docs",
        format_item = function(f)
            return vim.fn.fnamemodify(f, ":t:r"):gsub("-", " ")
        end,
    }, function(choice)
        if choice then
            vim.cmd("vsplit " .. vim.fn.fnameescape(choice))
        end
    end)
end, { desc = "Docs" })
