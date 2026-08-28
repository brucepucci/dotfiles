-- Iron REPL. Config and all 11 keymaps carried over unchanged.
--
-- Note the keymaps use a literal "<space>" prefix rather than "<leader>".
-- Identical in effect only because mapleader is space -- left as-is
-- deliberately, since these are in muscle memory.

return {
    "Vigemus/iron.nvim",
    cmd = { "IronRepl", "IronRestart", "IronFocus", "IronHide" },
    keys = { { "<leader>`", desc = "Toggle REPL window" } },
    config = function()
        require("iron.core").setup({
            config = {
                scratch_repl = true,
                repl_definition = {
                    python = { command = { "ipython", "--no-autoindent" } },
                },
                repl_open_cmd = "belowright 30split",
                should_map_plug = false,
                close_window_on_exit = false,
            },
            keymaps = {
                send_motion = "<space>rc",
                visual_send = "<C-CR>",
                send_line = "<C-CR>",
                send_mark = "<space>rm",
                mark_motion = "<space>rmc",
                mark_visual = "<space>rmv",
                remove_mark = "<space>rmd",
                cr = "<space>r<cr>",
                interrupt = "<space>r<space>",
                exit = "<space>rq",
                clear = "<space>cl",
            },
            highlight = { italic = true },
            ignore_blank_lines = true,
        })
    end,
}
