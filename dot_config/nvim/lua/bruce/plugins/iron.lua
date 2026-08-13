-- import iron plugin safely
local iron_setup, iron = pcall(require, "iron.core")
if not iron_setup then
  return
end

iron.setup({
  config = {
    -- Whether a repl should be discarded or not
    scratch_repl = true,
    -- Your repl definitions come here
    repl_definition = {
      python = {
        -- Can be a table or a function that
        -- returns a table (see below)
        command = {"ipython", "--no-autoindent"}
      }
    },
    -- How the repl window will be displayed
    -- Create a proper horizontal split at bottom
    repl_open_cmd = "belowright 30split",
    -- Ensure we can navigate to the REPL window
    should_map_plug = false,
    -- Make sure the repl window is properly focusable
    close_window_on_exit = false,
  },
  -- Iron doesn't set keymaps by default anymore.
  -- You can set them here or manually add keymaps to the functions in iron.core
  keymaps = {
    send_motion = "<space>rc",
    visual_send = "<C-CR>", -- Send selected text with Ctrl+Enter
    send_line = "<C-CR>",   -- Send current line with Ctrl+Enter
    send_mark = "<space>rm",
    mark_motion = "<space>rmc",
    mark_visual = "<space>rmv",
    remove_mark = "<space>rmd",
    cr = "<space>r<cr>",
    interrupt = "<space>r<space>",
    exit = "<space>rq",
    clear = "<space>cl",
  },
  -- If the highlight is on, you can change how it looks
  -- For the available options, check nvim_set_hl
  highlight = {
    italic = true
  },
  ignore_blank_lines = true, -- ignore blank lines when sending visual selection or motion.
})