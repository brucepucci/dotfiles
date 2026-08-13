-- LSP configuration.
--
-- Neovim 0.11+ ships its own LSP framework (`vim.lsp.config` / `vim.lsp.enable`),
-- and nvim-lspconfig now only supplies the per-server defaults in its `lsp/`
-- directory, which Neovim discovers automatically from the runtimepath.
-- The old `require("lspconfig").pylsp.setup({})` style is deprecated and will be
-- removed in nvim-lspconfig v3.

-- import cmp-nvim-lsp plugin safely
local cmp_nvim_lsp_status, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not cmp_nvim_lsp_status then
  return
end

local keymap = vim.keymap -- for conciseness

-- enable keybinds only for when lsp server available
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    -- keybind options
    local opts = { noremap = true, silent = true, buffer = ev.buf }

    -- set keybinds
    keymap.set("n", "<leader>gd", "<cmd>Lspsaga peek_definition<CR>", opts) -- see definition and make edits in window
    keymap.set("n", "<leader>gD", "<cmd>Lspsaga goto_definition<CR>", opts) -- see definition and make edits in window
    keymap.set("n", "<leader>gt", "<cmd>Lspsaga term_toggle<CR>", opts) -- see definition and make edits in window
    keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", opts) -- smart rename
    keymap.set("n", "<leader>d", "<cmd>Lspsaga show_line_diagnostics<CR>", opts) -- show  diagnostics for line
    keymap.set("n", "<leader>/", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
  end,
})

-- Change the Diagnostic symbols in the sign column (gutter)
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = "ﴞ ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
})

-- used to enable autocompletion (assigned to every lsp server config)
vim.lsp.config("*", {
  capabilities = cmp_nvim_lsp.default_capabilities(),
})

vim.lsp.config("pylsp", {
  settings = {
    pylsp = {
      plugins = {
        flake8 = {
          enabled = false
        },
        autopep8 = {
          enabled = false
        },
        yapf = {
          enabled = false
        },
        pyflakes = {
          enabled = false
        },
        mccabe = {
          enabled = false
        },
        pycodestyle = {
          enabled = false
        }
      }
    }
  }
})

vim.lsp.enable("pylsp")
