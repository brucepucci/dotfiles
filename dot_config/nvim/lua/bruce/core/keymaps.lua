vim.g.mapleader = " "

local keymap = vim.keymap

keymap.set("i", "jk", "<ESC>")

keymap.set("n", "<leader>nh", ":nohl<CR>")

keymap.set("n", "x", '"_x')

-- increment, decrement
keymap.set("n", "<leader>+", "<C-a>")
keymap.set("n", "<leader>-", "<C-x>")

-- splits
keymap.set("n", "<leader>st", "<C-w>v") -- split vertically
keymap.set("n", "<leader>sT", "<C-w>s") -- split horizontally
keymap.set("n", "<leader>se", "<C-w>=") -- make split equal width & height
keymap.set("n", "<leader>sw", ":close<CR>") -- close current split

-- tabs
keymap.set("n", "<leader>tt", ":tabnew<CR>") -- open new tab
keymap.set("n", "<leader>tw", ":tabclose<CR>") -- close current tab
keymap.set("n", "<leader>tl", ":tabn<CR>") --  go to next tab
keymap.set("n", "<leader>th", ":tabp<CR>") --  go to previous tab

-- plugin keymaps
keymap.set("n", "<leader>sm", ":MaximizerToggle<CR>") -- toggle split window maximization

-- nvim-tree
keymap.set("n", "<leader>.", ":NvimTreeToggle<CR>")

-- telescope
keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>") -- find files within current working directory, respects .gitignore
keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>") -- find string in current working directory as you type
keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>") -- find string under cursor in current working directory
keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>") -- list open buffers in current neovim instance
keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>") -- list available help tags

-- buffer navigation
keymap.set("n", "<leader>bd", ":bdelete<CR>") -- delete buffer

-- window navigation
keymap.set("n", "<C-j>", "<C-w>j") -- move to window below
keymap.set("n", "<C-k>", "<C-w>k") -- move to window above
keymap.set("n", "<C-h>", "<C-w>h") -- move to window left  
keymap.set("n", "<C-l>", "<C-w>l") -- move to window right


-- REPL window visibility toggle
keymap.set("n", "<leader>`", function()
  local windows = vim.api.nvim_list_wins()
  local terminal_win = nil
  
  -- Find terminal window
  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "terminal" then
      terminal_win = win
      break
    end
  end
  
  if terminal_win then
    -- Hide terminal window
    vim.api.nvim_win_close(terminal_win, false)
  else
    -- Show/create REPL
    vim.cmd("IronRepl")
  end
end) -- toggle REPL window visibility

-- markdown keymaps
keymap.set("n", "<leader>mp", ":MarkdownPreview<CR>") -- start markdown preview
keymap.set("n", "<leader>ms", ":MarkdownPreviewStop<CR>") -- stop markdown preview
keymap.set("n", "<leader>mm", ":MarkdownPreviewToggle<CR>") -- toggle markdown preview

-- terminal mode navigation (for when you're in the REPL)
keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k") -- exit terminal and move back to code
keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h") -- exit terminal and move to window left
keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l") -- exit terminal and move to window right

-- global
vim.api.nvim_set_keymap("n", "<C-h>", ":NvimTreeToggle<cr>", {silent = true, noremap = true})

