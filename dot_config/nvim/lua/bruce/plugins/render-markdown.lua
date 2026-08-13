-- import render-markdown plugin safely
local render_markdown_setup, render_markdown = pcall(require, "render-markdown")
if not render_markdown_setup then
  return
end

render_markdown.setup({
    heading = {
        -- Turn on / off heading icon & background rendering
        enabled = true,
        -- Turn on / off any sign column related rendering
        sign = true,
        -- Replaces '#+' of headings
        icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
    },
    code = {
        -- Turn on / off code block & inline code rendering
        enabled = true,
        -- Turn on / off any sign column related rendering
        sign = true,
        -- Determines how code blocks & inline code are rendered:
        --  none: disables all rendering
        --  normal: adds highlight group to code blocks & inline code
        --  language: adds language icon to sign column if enabled
        --  full: normal + language
        style = 'full',
        -- Width of the code block background:
        --  block: width of the code block
        --  full: full width of the window
        width = 'full',
        -- Minimum width to use for code blocks when width is 'block'
        min_width = 60,
    },
    bullet = {
        -- Turn on / off list bullet rendering
        enabled = true,
        -- Replaces '-'|'+'|'*' of 'unordered' lists
        icons = { '●', '○', '◆', '◇' },
    },
    checkbox = {
        -- Turn on / off checkbox state rendering
        enabled = true,
        unchecked = {
            -- Replaces '[ ]' of 'task_list_marker_unchecked'
            icon = '󰄱 ',
        },
        checked = {
            -- Replaces '[x]' of 'task_list_marker_checked'
            icon = '󰱒 ',
        },
    },
    quote = {
        -- Turn on / off block quote & callout rendering
        enabled = true,
        -- Replaces '>' of 'block_quote'
        icon = '▎',
    },
    pipe_table = {
        -- Turn on / off pipe table rendering
        enabled = true,
        -- Determines how the table as a whole is rendered:
        --  none: disables all rendering
        --  normal: applies the 'cell' style rendering to each row of the table
        --  full: normal + a top & bottom line that fill out the table when lengths match
        style = 'full',
        -- Determines how individual cells of a table are rendered:
        --  overlay: writes completely over the table, removing conceal behavior and highlights
        --  raw: replaces only the '|' characters in each row, leaving the cells unmodified
        --  padded: raw + cells are padded with whitespace to make the table appear more uniform
        --  trimmed: padded + cells are trimmed of leading and trailing whitespace
        cell = 'padded',
    },
    link = {
        -- Turn on / off inline link icon rendering
        enabled = true,
        -- Inlined with 'image' elements
        image = '󰥶 ',
        -- Inlined with 'inline_link' elements
        hyperlink = '󰌹 ',
        -- Applies to the fallback inlined icon
        highlight = 'RenderMarkdownLink',
    },
})