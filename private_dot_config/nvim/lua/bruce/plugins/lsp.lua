-- LSP.
--
-- Neovim 0.11+ owns the framework (vim.lsp.config / vim.lsp.enable) and the
-- action keymaps (grn rename, gra code action, grr references, gri
-- implementation, gO symbols, K hover, ]d/[d diagnostics, <C-S> signature).
-- nvim-lspconfig is here purely as a package of server definitions -- core
-- ships none of its own.
--
-- Servers come from Homebrew (see Brewfile), not Mason: one package manager,
-- versions visible in a reviewable file, no duplicate copies on disk.

return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        vim.diagnostic.config({
            virtual_text = { spacing = 2, prefix = "●" },
            severity_sort = true,
            float = { border = "rounded", source = true },
            signs = {
                text = {
                    [vim.diagnostic.severity.ERROR] = " ",
                    [vim.diagnostic.severity.WARN] = " ",
                    [vim.diagnostic.severity.HINT] = " ",
                    [vim.diagnostic.severity.INFO] = " ",
                },
            },
        })

        -- ruff: lint + format. Hover is deliberately off so Pyright is the
        -- single source of hover text -- otherwise two popups compete.
        vim.lsp.config("ruff", {
            init_options = { settings = { lineLength = 88 } },
        })

        vim.lsp.config("pyright", {
            settings = {
                python = {
                    analysis = {
                        typeCheckingMode = "basic",
                        autoSearchPaths = true,
                        useLibraryCodeForTypes = true,
                        -- ruff owns linting; Pyright owns types.
                        diagnosticSeverityOverrides = { reportUnusedImport = "none" },
                    },
                },
            },
        })

        vim.lsp.config("lua_ls", {
            settings = {
                Lua = {
                    runtime = { version = "LuaJIT" },
                    workspace = { checkThirdParty = false },
                    telemetry = { enable = false },
                },
            },
        })

        vim.lsp.enable({ "ruff", "pyright", "lua_ls", "marksman" })

        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("bruce_lsp_attach", { clear = true }),
            callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if client and client.name == "ruff" then
                    client.server_capabilities.hoverProvider = false
                end
            end,
        })
    end,
}
