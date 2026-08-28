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

        -- Servers are external binaries. A missing one attaches nothing and
        -- says nothing -- removing the pcall(require) guards did not cover this
        -- case, because there is no require to fail. This is the same silent
        -- failure mode that left the previous config without an LSP for months.
        local exes = {
            ruff = "ruff",
            pyright = "pyright-langserver",
            lua_ls = "lua-language-server",
            marksman = "marksman",
        }
        local absent = {}
        for server, exe in pairs(exes) do
            if vim.fn.executable(exe) == 0 then
                absent[#absent + 1] = server .. " (" .. exe .. ")"
            end
        end
        if #absent > 0 then
            table.sort(absent)
            vim.notify(
                "LSP servers not on PATH: "
                    .. table.concat(absent, ", ")
                    .. '\nRun: brew bundle --file="$(chezmoi source-path)/Brewfile"',
                vim.log.levels.WARN
            )
        end

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
