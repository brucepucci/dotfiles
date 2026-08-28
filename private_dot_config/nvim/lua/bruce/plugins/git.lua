-- The review layer.
--
-- Two tools, two granularities -- they are not redundant:
--   gitsigns  = inline, per-HUNK accept/reject, in your normal editing buffer.
--   diffview  = side-by-side, per-CHANGESET survey across every touched file.
--
-- Both live under <leader>g. Lowercase acts on this hunk/file, capital widens
-- the scope. Hunk navigation is <leader>gh/gl to match <leader>th/tl for tabs.

return {
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            on_attach = function(bufnr)
                local gs = require("gitsigns")
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
                end

                -- navigation: h/l = prev/next, same as <leader>th/tl for tabs
                map("n", "<leader>gh", function() gs.nav_hunk("prev") end, "Prev hunk")
                map("n", "<leader>gl", function() gs.nav_hunk("next") end, "Next hunk")

                -- accept / reject
                map({ "n", "x" }, "<leader>gs", ":Gitsigns stage_hunk<CR>", "Stage hunk")
                map({ "n", "x" }, "<leader>gr", ":Gitsigns reset_hunk<CR>", "Reset hunk")
                map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
                map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
                -- Deprecated upstream in favour of stage_hunk() on a staged
                -- sign, but still functional and warning-free. It pops one
                -- entry off the stage stack, so after <leader>gS it unstages
                -- only the most recent hunk.
                map("n", "<leader>gu", gs.undo_stage_hunk, "Undo stage hunk")

                -- inspect
                map("n", "<leader>gp", gs.preview_hunk_inline, "Preview hunk inline")
                map("n", "<leader>gP", gs.preview_hunk, "Preview hunk (float)")
                map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
                map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle inline blame")

                map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Hunk textobject")
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
            { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff: review changeset" },
            { "<leader>gD", "<cmd>DiffviewOpen --staged<cr>", desc = "Diff: review staged" },
            { "<leader>gm", "<cmd>DiffviewOpen origin/main...HEAD<cr>", desc = "Diff: branch vs main" },
            { "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", desc = "Diff: this file's history" },
            { "<leader>gF", "<cmd>DiffviewFileHistory<cr>", desc = "Diff: repo history" },
            { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Diff: close" },
        },
    },
}
