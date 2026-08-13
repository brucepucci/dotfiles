-- import nvim-tree plugin safely
local setup, nvimtree = pcall(require, "nvim-tree")
if not setup then
  return
end

-- recommended settings from nvim-tree documentation
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- change color for arrows in tree to light blue
vim.cmd([[ highlight NvimTreeIndentMarker guifg=#3FC5FF ]])

nvimtree.setup({
  renderer = {
    icons = {
      glyphs = {
        folder = {
          arrow_closed = "", -- arrow when folder is closed
          arrow_open = "", -- arrow when folder is open
        },
      },
    },
  },
  actions = {
    open_file = {
      window_picker = {
        enable = false,
      },
    },
  },
  on_attach = function(bufnr)
    local api = require('nvim-tree.api')
    
    local function opts(desc)
      return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    -- default mappings
    api.config.mappings.default_on_attach(bufnr)

    -- custom mappings
    vim.keymap.set('n', 'l', api.node.open.edit, opts('Open'))
    vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('Close Directory'))
  end,
})

-- configure nvim-tree
-- nvimtree.setup({
--   -- change folder arrow icons
--   renderer = {
--     icons = {
--       glyphs = {
--         folder = {
--           arrow_closed = "", -- arrow when folder is closed
--           arrow_open = "", -- arrow when folder is open
--         },
--       },
--     },
--   },
--   -- disable window_picker for
--   -- explorer to work well with
--   -- window splits
--   actions = {
--     open_file = {
--       window_picker = {
--         enable = false,
--       },
--     },
--   },
--   -- 	git = {
--   -- 		ignore = false,
--   -- 	},
-- })
--
-- -- open nvim-tree on setup
--
-- local function open_nvim_tree(data)
--   -- buffer is a [No Name]
--   local no_name = data.file == "" and vim.bo[data.buf].buftype == ""
--
--   -- buffer is a directory
--   local directory = vim.fn.isdirectory(data.file) == 1
--
--   if not no_name and not directory then
--     return
--   end
--
--   -- change to the directory
--   if directory then
--     vim.cmd.cd(data.file)
--   end
--
--   -- open the tree
--   require("nvim-tree.api").tree.open()
-- end
--
-- open nvim-tree on startup when no file is specified
local function open_nvim_tree(data)
  -- buffer is a [No Name] (no specific file passed)
  local no_name = data.file == "" and vim.bo[data.buf].buftype == ""

  -- buffer is a directory
  local directory = vim.fn.isdirectory(data.file) == 1

  if not no_name and not directory then
    return
  end

  -- change to the directory
  if directory then
    vim.cmd.cd(data.file)
  end

  -- open the tree
  require("nvim-tree.api").tree.open()
end

vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })

-- Make :bd and :q behave as usual when tree is visible
vim.api.nvim_create_autocmd({'BufEnter', 'QuitPre'}, {
  nested = false,
  callback = function(e)
    local tree = require('nvim-tree.api').tree

    -- Nothing to do if tree is not opened
    if not tree.is_visible() then
      return
    end

    -- How many focusable windows do we have? (excluding e.g. incline status window)
    local winCount = 0
    for _,winId in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(winId).focusable then
        winCount = winCount + 1
      end
    end

    -- We want to quit and only one window besides tree is left
    if e.event == 'QuitPre' and winCount == 2 then
      vim.api.nvim_cmd({cmd = 'qall'}, {})
    end

    -- :bd was probably issued an only tree window is left
    -- Behave as if tree was closed (see `:h :bd`)
    if e.event == 'BufEnter' and winCount == 1 then
      -- Required to avoid "Vim:E444: Cannot close last window"
      vim.defer_fn(function()
        -- close nvim-tree: will go to the last buffer used before closing
        tree.toggle({find_file = true, focus = true})
        -- re-open nivm-tree
        tree.toggle({find_file = true, focus = false})
      end, 10)
    end
  end
})
