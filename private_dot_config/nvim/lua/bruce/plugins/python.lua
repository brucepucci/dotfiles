-- Iron REPL.

return {
    "Vigemus/iron.nvim",
    -- ft as well as cmd: iron registers its keymaps inside config(), so with a
    -- cmd-only trigger <C-CR> and every <leader>r* key did not exist until you
    -- had already started the REPL by hand.
    ft = "python",
    cmd = { "IronRepl", "IronRestart", "IronFocus", "IronHide" },
    config = function()
        local common = require("iron.fts.common")
        local warned = false

        require("iron.core").setup({
            config = {
                scratch_repl = true,
                repl_definition = {
                    -- Extend iron's own ipython definition rather than
                    -- replacing it. iron merges repl_definition SHALLOWLY, so
                    -- supplying a bare { command = ... } silently dropped
                    -- `format = bracketed_paste_python`. Without it, a blank
                    -- line inside a function ends the block in ipython: the
                    -- body executes at top level, `return` raises SyntaxError,
                    -- and the function comes back None -- wrong results, with
                    -- nothing shown in the editor.
                    python = vim.tbl_extend("force", require("iron.fts.python").ipython, {
                        command = function()
                            if vim.fn.executable("ipython") == 1 then
                                return { "ipython", "--no-autoindent" }
                            end
                            -- bracketed_paste_python calls command() on every
                            -- send, so warn once rather than on each keypress.
                            if not warned then
                                warned = true
                                vim.notify(
                                    "ipython not found -- using python3. `brew install ipython`",
                                    vim.log.levels.WARN
                                )
                            end
                            return { "python3" }
                        end,
                        format = common.bracketed_paste_python,
                    }),
                },
                repl_open_cmd = "belowright 30split",
                should_map_plug = false,
                close_window_on_exit = false,
                -- Belongs inside `config` -- iron.core.setup only reads
                -- opts.config / opts.keymaps / opts.highlight, so a top-level
                -- key here would be silently ignored.
                ignore_blank_lines = true,
            },
            keymaps = {
                send_motion = "<leader>rc",
                visual_send = "<C-CR>",
                send_line = "<C-CR>",
                -- send_mark was <leader>rm, a strict prefix of rmc/rmv/rmd,
                -- so it stalled for the full 'timeoutlen' (1s) on every press.
                send_mark = "<leader>rs",
                mark_motion = "<leader>rmc",
                mark_visual = "<leader>rmv",
                remove_mark = "<leader>rmd",
                cr = "<leader>r<cr>",
                interrupt = "<leader>ri",
                exit = "<leader>rq",
                clear = "<leader>rl",
            },
            highlight = { italic = true },
        })
    end,
}
