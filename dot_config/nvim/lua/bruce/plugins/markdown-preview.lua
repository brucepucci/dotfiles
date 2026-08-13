-- markdown-preview.nvim configuration
-- Note: This plugin is configured via global variables

-- Specify browser
vim.g.mkdp_browser = ''

-- Set to 1, nvim will open the preview window after entering the markdown buffer
vim.g.mkdp_auto_start = 0

-- Set to 1, the nvim will auto close current preview window when change
-- from markdown buffer to another buffer
vim.g.mkdp_auto_close = 1

-- Set to 1, the vim will refresh markdown when save the buffer or
-- leave from insert mode, default 0 is auto refresh markdown as you edit or
-- move the cursor
vim.g.mkdp_refresh_slow = 0

-- Set to 1, the MarkdownPreview command can be use for all files,
-- by default it can be use in markdown file
vim.g.mkdp_command_for_global = 0

-- Set to 1, preview server available to others in your network
-- by default, the server listens on localhost (127.0.0.1)
vim.g.mkdp_open_to_the_world = 0

-- Use custom IP to open preview page
-- useful when you work in remote vim and preview on local browser
vim.g.mkdp_open_ip = ''

-- Specify browser to open preview page
vim.g.mkdp_echo_preview_url = 0

-- A custom vim function name to open preview page
vim.g.mkdp_browserfunc = ''

-- Options for markdown render
vim.g.mkdp_preview_options = {
    mkit = {},
    katex = {},
    uml = {},
    maid = {},
    disable_sync_scroll = 0,
    sync_scroll_type = 'middle',
    hide_yaml_meta = 1,
    sequence_diagrams = {},
    flowchart_diagrams = {},
    content_editable = false,
    disable_filename = 0,
    toc = {}
}

-- Use a custom markdown style must be absolute path
vim.g.mkdp_markdown_css = ''

-- Use a custom highlight style must be absolute path
vim.g.mkdp_highlight_css = ''

-- Use a custom port to start server or random for empty
vim.g.mkdp_port = ''

-- Preview page title
vim.g.mkdp_page_title = '${name}'

-- Recognized filetypes
vim.g.mkdp_filetypes = {'markdown'}

-- Set default theme (dark or light)
vim.g.mkdp_theme = 'light'