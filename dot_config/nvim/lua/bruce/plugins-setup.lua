local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

return require('packer').startup(function(use)
  use('wbthomason/packer.nvim')
  use("nvim-lua/plenary.nvim") -- lua functions that many plugins use
  use({ "catppuccin/nvim", as = "catppuccin" })
  use("bluz71/vim-nightfly-guicolors")
  use("christoomey/vim-tmux-navigator") -- tmux & split window navigation
  use("szw/vim-maximizer") -- maximizes and restores current window
  use("numToStr/Comment.nvim")
  use("tpope/vim-surround") -- add, delete, change surroundings (it's awesome)
  use("inkarkat/vim-ReplaceWithRegister") -- replace with register contents using motion (gr + motion)
  use("nvim-tree/nvim-tree.lua")
  use("kyazdani42/nvim-web-devicons")
  use("nvim-lualine/lualine.nvim")
  use({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" }) -- dependency for better sorting performance
  use({ "nvim-telescope/telescope.nvim", branch = "0.1.x" }) -- fuzzy finder
  use("hrsh7th/nvim-cmp") -- completion plugin
  use("hrsh7th/cmp-buffer") -- source for text in buffer
  use("hrsh7th/cmp-path") -- source for file system paths
  use("L3MON4D3/LuaSnip") -- snippet engine
  use("saadparwaiz1/cmp_luasnip") -- for autocompletion
  use("rafamadriz/friendly-snippets") -- useful snippets
  use("williamboman/mason.nvim") -- in charge of managing lsp servers, linters & formatters
  use("williamboman/mason-lspconfig.nvim") -- bridges gap b/w mason & lspconfig
  use("neovim/nvim-lspconfig") -- easily configure language servers
  use("hrsh7th/cmp-nvim-lsp") -- for autocompletion
  use('m4xshen/autoclose.nvim')
  use({'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'})
  use('Vimjas/vim-python-pep8-indent')
  use({
    "glepnir/lspsaga.nvim",
    branch = "main",
    requires = {
      { "nvim-tree/nvim-web-devicons" },
      { "nvim-treesitter/nvim-treesitter" },
    },
  }) -- enhanced lsp uis
  use("onsails/lspkind.nvim") -- vs-code like icons for autocompletion
  use("Vigemus/iron.nvim") -- interactive repl for python and other languages
  use("MeanderingProgrammer/render-markdown.nvim") -- in-buffer markdown rendering
  use({"iamcco/markdown-preview.nvim", run = "cd app && npm install", setup = function() vim.g.mkdp_filetypes = {"markdown"} end, ft = {"markdown"}}) -- browser markdown preview

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)

