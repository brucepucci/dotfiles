-- Plugin management with lazy.nvim.
--
-- Each plugin's configuration still lives in its own file under
-- lua/bruce/plugins/, and is wired in here through `config` so that it runs
-- once the plugin is actually loaded, rather than unconditionally at startup.

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- `mapleader` must be set before lazy.setup so that any `keys = {...}` specs
-- resolve the leader correctly. core.keymaps sets it, and is required first.
require("lazy").setup({
  spec = {
    -- lua functions that many plugins use
    { "nvim-lua/plenary.nvim", lazy = true },

    -- colorscheme, loaded before everything else so there is no startup flash
    {
      "catppuccin/nvim",
      name = "catppuccin",
      lazy = false,
      priority = 1000,
      config = function()
        require("bruce.core.colorscheme")
      end,
    },
    -- vim-nightfly-guicolors was removed: it had no load trigger and nothing
    -- referenced it. lualine's nightfly theme is bundled with lualine itself.

    -- tmux & split window navigation
    { "christoomey/vim-tmux-navigator", lazy = false },

    -- maximizes and restores current window
    { "szw/vim-maximizer", cmd = "MaximizerToggle" },

    -- Comment.nvim was removed: Neovim ships vim._comment with gc/gcc/gbc
    -- mappings since 0.10, and the plugin was only overriding them.

    -- add, delete, change surroundings (it's awesome)
    { "tpope/vim-surround", event = "VeryLazy" },

    -- replace with register contents using motion (gr + motion)
    { "inkarkat/vim-ReplaceWithRegister", event = "VeryLazy" },

    {
      "nvim-tree/nvim-tree.lua",
      -- not lazy-loaded: it registers a VimEnter autocmd to open the tree when
      -- nvim is started on a directory or with no file
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("bruce.plugins.nvim-tree")
      end,
    },
    { "nvim-tree/nvim-web-devicons", lazy = true },

    {
      "nvim-lualine/lualine.nvim",
      event = "VeryLazy",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("bruce.plugins.lualine")
      end,
    },

    -- fuzzy finder
    {
      "nvim-telescope/telescope.nvim",
      branch = "0.1.x",
      cmd = "Telescope",
      dependencies = {
        "nvim-lua/plenary.nvim",
        -- dependency for better sorting performance
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      },
      config = function()
        require("bruce.plugins.telescope")
      end,
    },

    -- completion plugin
    {
      "hrsh7th/nvim-cmp",
      event = "InsertEnter",
      dependencies = {
        "hrsh7th/cmp-buffer", -- source for text in buffer
        "hrsh7th/cmp-path", -- source for file system paths
        "saadparwaiz1/cmp_luasnip", -- for autocompletion
        "onsails/lspkind.nvim", -- vs-code like icons for autocompletion
        {
          "L3MON4D3/LuaSnip", -- snippet engine
          dependencies = { "rafamadriz/friendly-snippets" }, -- useful snippets
        },
      },
      config = function()
        require("bruce.plugins.nvim-cmp")
      end,
    },

    -- easily configure language servers
    {
      "neovim/nvim-lspconfig",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = {
        -- in charge of managing lsp servers, linters & formatters
        "williamboman/mason.nvim",
        -- bridges gap b/w mason & lspconfig
        "williamboman/mason-lspconfig.nvim",
        -- supplies the completion capabilities handed to every server
        "hrsh7th/cmp-nvim-lsp",
      },
      config = function()
        -- order matters: mason puts its bin directory on PATH, and
        -- mason-lspconfig must be set up before servers are enabled
        require("bruce.plugins.lsp.mason")
        require("bruce.plugins.lsp.lspconfig")
      end,
    },

    -- enhanced lsp uis
    {
      "nvimdev/lspsaga.nvim",
      cmd = "Lspsaga",
      dependencies = {
        "nvim-tree/nvim-web-devicons",
        "nvim-treesitter/nvim-treesitter",
      },
      config = function()
        require("bruce.plugins.lsp.lspsaga")
      end,
    },

    {
      "m4xshen/autoclose.nvim",
      event = "InsertEnter",
      config = function()
        require("bruce.plugins.autoclose")
      end,
    },

    {
      "nvim-treesitter/nvim-treesitter",
      -- nvim-treesitter's main branch explicitly does not support lazy-loading
      lazy = false,
      build = ":TSUpdate",
      config = function()
        require("bruce.plugins.treesitter")
      end,
    },

    { "Vimjas/vim-python-pep8-indent", ft = "python" },

    -- interactive repl for python and other languages
    {
      "Vigemus/iron.nvim",
      -- the <leader>` toggle runs :IronRepl, and the send mappings are created
      -- by iron's own setup, so load it as soon as a Python buffer appears
      ft = "python",
      cmd = { "IronRepl", "IronFocus", "IronRestart", "IronHide" },
      config = function()
        require("bruce.plugins.iron")
      end,
    },

    -- in-buffer markdown rendering
    {
      "MeanderingProgrammer/render-markdown.nvim",
      ft = "markdown",
      dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
      config = function()
        require("bruce.plugins.render-markdown")
      end,
    },

    -- browser markdown preview
    {
      "iamcco/markdown-preview.nvim",
      ft = "markdown",
      cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
      build = "cd app && npm install",
      -- its settings are plain globals that must be set before the plugin loads
      init = function()
        require("bruce.plugins.markdown-preview")
      end,
    },
  },

  -- pin plugins to the versions recorded in lazy-lock.json; `:Lazy update`
  -- moves them forward and rewrites the lockfile
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
  install = { colorscheme = { "catppuccin-macchiato", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
})
