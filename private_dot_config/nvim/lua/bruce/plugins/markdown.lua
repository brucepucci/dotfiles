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
        -- Downloads a prebuilt binary. Two things this avoids:
        --   * `cd app && npm install` rewrites app/yarn.lock, leaving the
        --     repo dirty so lazy.nvim refuses every later update.
        --   * mkdp#util#install() spawns an async job, which a headless
        --     bootstrap (`nvim --headless +Lazy! restore`) exits before.
        build = function(plugin)
            vim.fn.system({ "sh", plugin.dir .. "/app/install.sh" })
        end,
        -- These must be set in init, not config: the plugin reads them as it
        -- loads, which happens before config runs.
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
            vim.g.mkdp_browser = ""
            vim.g.mkdp_auto_start = 0
            vim.g.mkdp_auto_close = 1
            vim.g.mkdp_refresh_slow = 0
            vim.g.mkdp_command_for_global = 0
            vim.g.mkdp_open_to_the_world = 0
            vim.g.mkdp_open_ip = ""
            vim.g.mkdp_echo_preview_url = 0
            vim.g.mkdp_browserfunc = ""
            vim.g.mkdp_preview_options = {
                mkit = {},
                katex = {},
                uml = {},
                maid = {},
                disable_sync_scroll = 0,
                sync_scroll_type = "middle",
                hide_yaml_meta = 1,
                sequence_diagrams = {},
                flowchart_diagrams = {},
                content_editable = false,
                disable_filename = 0,
                toc = {},
            }
            vim.g.mkdp_markdown_css = ""
            vim.g.mkdp_highlight_css = ""
            vim.g.mkdp_port = ""
            vim.g.mkdp_page_title = "${name}"
            vim.g.mkdp_theme = "light"
        end,
        keys = {
            { "<leader>mp", "<cmd>MarkdownPreview<cr>", desc = "Markdown preview start" },
            { "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", desc = "Markdown preview stop" },
            { "<leader>mm", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview toggle" },
        },
    },
}
