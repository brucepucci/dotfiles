return {
    -- In-buffer rendering. Icon and style choices carried over unchanged.
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown" },
        opts = {
            heading = {
                enabled = true,
                sign = true,
                icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
            },
            code = {
                enabled = true,
                sign = true,
                style = "full",
                width = "full",
                min_width = 60,
            },
            bullet = { enabled = true, icons = { "●", "○", "◆", "◇" } },
            checkbox = {
                enabled = true,
                unchecked = { icon = "󰄱 " },
                checked = { icon = " " },
            },
            quote = { enabled = true, icon = "▎" },
            pipe_table = { enabled = true, style = "full", cell = "padded" },
            link = {
                enabled = true,
                image = "󰥶 ",
                hyperlink = "󰌹 ",
                highlight = "RenderMarkdownLink",
            },
        },
    },

    -- Browser preview. All vim.g.mkdp_* settings carried over unchanged.
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
        ft = { "markdown" },
        -- Prefer the prebuilt binary; fall back to building the Node app.
        --
        -- Three traps this avoids:
        --   * `cd app && npm install` rewrites app/yarn.lock, leaving the repo
        --     dirty so lazy.nvim refuses every later update. We restore it.
        --   * mkdp#util#install() spawns an async job, which a headless
        --     bootstrap (`nvim --headless +Lazy! restore`) exits before.
        --   * install.sh prints "No pre-built binary available" and exits 0 on
        --     platforms upstream does not ship for (notably Linux aarch64:
        --     WSL-on-ARM, Graviton, Raspberry Pi). Without the glob check
        --     below, lazy records a successful build and <leader>mp only fails
        --     later, at runtime.
        build = function(plugin)
            local function has_binary()
                return #vim.fn.glob(plugin.dir .. "/app/bin/markdown-preview-*", false, true) > 0
            end

            vim.fn.system({ "sh", plugin.dir .. "/app/install.sh" })
            if has_binary() then
                return
            end

            local u = vim.uv.os_uname()
            if vim.fn.executable("npm") == 0 then
                error(
                    ("markdown-preview: no prebuilt binary for %s/%s, and npm is not "):format(u.sysname, u.machine)
                        .. "installed to build the fallback. Install Node, then :Lazy build markdown-preview.nvim"
                )
            end

            vim.fn.system({ "npm", "--prefix", plugin.dir .. "/app", "install" })
            if vim.v.shell_error ~= 0 then
                error(("markdown-preview: npm install failed on %s/%s"):format(u.sysname, u.machine))
            end
            -- npm rewrites yarn.lock; hand it back so lazy can still update.
            vim.fn.system({ "git", "-C", plugin.dir, "checkout", "--", "app/yarn.lock" })
        end,
        -- Only the two settings that differ from the plugin's own defaults.
        -- The other 14 restated them, and the empty Lua tables in
        -- mkdp_preview_options marshalled to Vimscript Lists rather than Dicts
        -- (json_encode showed "mkit": [] where the plugin expects {}).
        --
        -- These must be set in init, not config: the plugin reads them as it
        -- loads, which happens before config runs.
        init = function()
            vim.g.mkdp_page_title = "${name}" -- default is the CJK-bracketed form
            vim.g.mkdp_theme = "light"
        end,
        keys = {
            { "<leader>mp", "<cmd>MarkdownPreview<cr>", desc = "Markdown preview start" },
            { "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", desc = "Markdown preview stop" },
            { "<leader>mm", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview toggle" },
        },
    },
}
