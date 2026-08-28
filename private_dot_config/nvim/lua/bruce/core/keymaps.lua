-- Core keymaps. Plugin-owned keys live with their plugin spec in
-- lua/bruce/plugins/*.lua so that lazy-loading triggers stay accurate.
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

-- window navigation
--
-- NOTE: there is deliberately no <C-h> here. The previous config mapped it to
-- <C-w>h on one line and then overrode it with the file-explorer toggle 38
-- lines later, so the explorer always won. That is the behaviour in muscle
-- memory, so <C-h> stays the explorer toggle (see plugins/snacks.lua).
-- To focus the window on the left, use the built-in <C-w>h.
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window below" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window above" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- terminal mode: escape back to the code window from the REPL.
-- <C-j> is deliberately absent -- the REPL sits below, so there is nothing to
-- move down into.
keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Leave terminal, window above" })
keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Leave terminal, window left" })
keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Leave terminal, window right" })

-- maximize / restore the current window (replaces vim-maximizer)
keymap.set("n", "<leader>sm", function()
    require("bruce.core.maximize").toggle()
end, { desc = "Maximize window (toggle)" })

-- REPL window visibility toggle.
-- Closes the first terminal window found, otherwise starts the Iron REPL.
keymap.set("n", "<leader>`", function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "terminal" then
            vim.api.nvim_win_close(win, false)
            return
        end
    end
    vim.cmd("IronRepl")
end, { desc = "Toggle REPL window" })

-- diagnostics (LSP action keys are Neovim 0.11+ built-ins: grn gra grr gri gO)
keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line diagnostics" })
keymap.set("n", "<leader>/", vim.lsp.buf.hover, { desc = "Hover docs" })
