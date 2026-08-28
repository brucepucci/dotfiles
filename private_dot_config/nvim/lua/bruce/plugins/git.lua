-- The review layer.
--
-- gitsigns is inline and per-hunk: walk what an agent changed and accept or
-- reject each piece. diffview is side-by-side and per-changeset: does the
-- whole thing hang together. They are not redundant.

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signcolumn = true,
            on_attach = function(bufnr)
                local gs = require("gitsigns")
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Hunk: " .. desc })
                end

                -- ]c/[c are builtin diff-mode and ]d/[d are builtin
                -- diagnostics, so hunks get ]h/[h.
                map("n", "]h", function() gs.nav_hunk("next") end, "next")
                map("n", "[h", function() gs.nav_hunk("prev") end, "prev")

                map("n", "<leader>hp", gs.preview_hunk_inline, "preview inline")
                map("n", "<leader>hP", gs.preview_hunk, "preview float")
                map({ "n", "x" }, "<leader>hs", ":Gitsigns stage_hunk<CR>", "stage")
                map({ "n", "x" }, "<leader>hr", ":Gitsigns reset_hunk<CR>", "reset")
                map("n", "<leader>hS", gs.stage_buffer, "stage buffer")
                map("n", "<leader>hR", gs.reset_buffer, "reset buffer")
                map("n", "<leader>hu", gs.undo_stage_hunk, "undo stage")
                map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "blame line")
                map("n", "<leader>hB", gs.toggle_current_line_blame, "toggle blame")
                map("n", "<leader>hd", gs.diffthis, "diff vs index")
                map("n", "<leader>hD", function() gs.diffthis("~") end, "diff vs HEAD~")
                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "textobject")
            end,
        },
    },

    {
        -- Actively-maintained fork; upstream sindrets/ last shipped Aug 2024,
        -- predating the 0.11 LSP rework and all of 0.12. Same module name, so
        -- reverting is a one-line change.
        "dlyongemallo/diffview.nvim",
        cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
        opts = {},
        keys = {
            { "<leader>vv", "<cmd>DiffviewOpen<cr>", desc = "Review working tree" },
            { "<leader>vc", "<cmd>DiffviewClose<cr>", desc = "Close diffview" },
            { "<leader>vs", "<cmd>DiffviewOpen --staged<cr>", desc = "Review staged only" },
            { "<leader>vh", "<cmd>DiffviewFileHistory %<cr>", desc = "History of this file" },
            { "<leader>vH", "<cmd>DiffviewFileHistory<cr>", desc = "History of repo" },
            { "<leader>vm", "<cmd>DiffviewOpen origin/main...HEAD<cr>", desc = "Branch vs main" },
        },
    },
}
