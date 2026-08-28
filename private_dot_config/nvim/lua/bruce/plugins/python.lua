-- Iron REPL. Config and all 11 keymaps carried over unchanged.
--
-- Note the keymaps use a literal "<space>" prefix rather than "<leader>".
-- Identical in effect only because mapleader is space -- left as-is
-- deliberately, since these are in muscle memory.

return {
    "Vigemus/iron.nvim",
    cmd = { "IronRepl", "IronRestart", "IronFocus", "IronHide" },
    -- No `keys` entry: the <leader>` toggle lives in core/keymaps.lua and
    -- runs :IronRepl, which the `cmd` trigger above already lazy-loads. A
    -- lazy `keys` stub here would replace that mapping and then delete
    -- itself on load, leaving <leader>` unmapped.
    config = function()
        require("iron.core").setup({
            config = {
                scratch_repl = true,
                repl_definition = {
                    python = {
                        -- Fall back to the plain interpreter rather than
                        -- erroring out when ipython is not installed.
                        command = function()
                            if vim.fn.executable("ipython") == 1 then
                                return { "ipython", "--no-autoindent" }
                            end
                            vim.notify(
                                "ipython not found -- using python3. `brew install ipython`",
                                vim.log.levels.WARN
                            )
                            return { "python3" }
                        end,
                    },
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
