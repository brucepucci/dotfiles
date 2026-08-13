-- Parsers to keep installed. Neovim already bundles c, lua, markdown,
-- markdown_inline, query, vim and vimdoc, so only the extras are listed here.
-- Exposed so that chezmoi's bootstrap script can install them synchronously.
local M = {
  ensure_installed = {
    "python",
    "bash",
    "json",
    "yaml",
    "toml",
    "html",
    "css",
    "javascript",
  },
}

-- import nvim-treesitter plugin safely
local setup, treesitter = pcall(require, "nvim-treesitter")
if not setup then
  return M
end

treesitter.setup()

-- Install anything missing in the background on startup.
local installed = treesitter.get_installed()
local missing = vim.tbl_filter(function(lang)
  return not vim.tbl_contains(installed, lang)
end, M.ensure_installed)

if #missing > 0 then
  treesitter.install(missing)
end

-- nvim-treesitter's main branch does not turn any features on by itself:
-- highlighting is Neovim's, and has to be started per buffer.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if lang and pcall(vim.treesitter.language.add, lang) then
      pcall(vim.treesitter.start, ev.buf, lang)
    end
  end,
})

return M
