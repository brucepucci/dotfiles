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
