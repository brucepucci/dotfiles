-- import mason plugin safely
local mason_status, mason = pcall(require, "mason")
if not mason_status then
  return
end

-- import mason-lspconfig plugin safely
local mason_lspconfig_status, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_lspconfig_status then
  return
end

-- enable mason (also puts ~/.local/share/nvim/mason/bin on nvim's PATH)
mason.setup()

mason_lspconfig.setup({
  -- list of servers for mason to install
  ensure_installed = {
    "pylsp",
  },
  -- mason-lspconfig v2 auto-enables every installed server. Servers are enabled
  -- explicitly in lsp/lspconfig.lua instead, so that only what is configured
  -- there actually starts.
  automatic_enable = false,
})
