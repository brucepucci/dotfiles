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

-- A language needs installing if its parser is absent, OR if its highlight
-- queries cannot be resolved. The second case matters: nvim-treesitter
-- symlinks each query directory back into its own install directory, so moving
-- or removing that directory leaves the compiled parser in place but the
-- symlink dangling. Checking only for the parser misses it entirely, and the
-- result is a buffer with treesitter attached, no highlights, and no legacy
-- syntax either -- because starting treesitter turns `syntax` off.
local installed = treesitter.get_installed()

local function needs_install(lang)
  if not vim.tbl_contains(installed, lang) then
    return true
  end
  local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  return not ok or query == nil
end

local missing = vim.tbl_filter(needs_install, M.ensure_installed)

if #missing > 0 then
  -- `force` skips the confirmation prompt and reinstalls languages that are
  -- already present, which is what repairs a broken query symlink.
  treesitter.install(missing, { force = true })
end

-- nvim-treesitter's main branch does not turn any features on by itself:
-- highlighting is Neovim's, and has to be started per buffer.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if not lang or not pcall(vim.treesitter.language.add, lang) then
      -- no parser for this filetype; leave the legacy syntax highlighting alone
      return
    end

    local ok, err = pcall(vim.treesitter.start, ev.buf, lang)
    if not ok then
      vim.notify(
        ("treesitter: failed to start for %s: %s"):format(lang, err),
        vim.log.levels.WARN
      )
    end
  end,
})

return M
