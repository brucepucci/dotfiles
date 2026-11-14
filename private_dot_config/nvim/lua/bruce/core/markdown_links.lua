-- Two Markdown client compatibility gaps in rumdl 0.3.4. Keep the server's
-- indexing/navigation and Neovim's existing actions; do not change keymaps.
local M = {}
local definitions = vim.treesitter.query.parse("markdown", [[
    (link_reference_definition (link_label) @label)
]])

local function position(bufnr, row, col, encoding)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    return { line = row, character = vim.str_utfindex(line, encoding, col, false) }
end

local function context(params, encoding, completion)
    local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
    if not vim.api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].filetype ~= "markdown" then return end
    local row = params.position.line
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if not line then return end
    local col = vim.str_byteindex(line, encoding, params.position.character, false)
    local parser = vim.treesitter.get_parser(bufnr, "markdown")
    local tree = parser:parse({ row, row + 1 })[1]
    -- Completion positions are gaps, including the gap just past an inline
    -- tree's end. Inspect the preceding byte without changing the edit range.
    local probe = completion and math.max(0, col - 1) or col
    local range = { row, probe, row, probe }
    local block = tree:root():named_descendant_for_range(unpack(range))
    while block and block:type() ~= "inline" and block:type() ~= "pipe_table_cell" do
        block = block:parent()
    end
    -- Admit paragraph/table inline content only from the original block tree;
    -- never descend into fenced Markdown injections or code blocks.
    if not block then return end
    local inline = parser:children().markdown_inline
    if not inline then return end
    return bufnr, inline:named_node_for_range(range), tree, inline
end

local function destination(params, encoding)
    local bufnr, node = context(params, encoding)
    while node do
        -- Keep rumdl's original request when the cursor is already in the
        -- destination; only the surrounding link span needs translation.
        if node:type() == "link_destination" then return params end
        if node:type() == "inline_link" then
            for child in node:iter_children() do
                if child:type() == "link_destination" then
                    local row, col = child:range()
                    if vim.treesitter.get_node_text(child, bufnr):sub(1, 1) == "<" then col = col + 1 end
                    local forwarded = vim.deepcopy(params)
                    forwarded.position = position(bufnr, row, col, encoding)
                    return forwarded
                end
            end
        end
        node = node:parent()
    end
    return params
end

local function reference_range(bufnr, node, inline, params, encoding)
    while node do
        if node:type() == "link_label" and node:parent():type() == "full_reference_link" then
            local sr, sc, er, ec = node:range()
            -- LSP completion edits must be single-line. Leave multiline
            -- usages to the server instead of returning an invalid edit.
            if sr ~= er then return end
            local first = position(bufnr, sr, sc + 1, encoding)
            local last = position(bufnr, er, ec - 1, encoding)
            local cursor = params.position
            if cursor.line < first.line or cursor.line > last.line
                or (cursor.line == first.line and cursor.character < first.character)
                or (cursor.line == last.line and cursor.character > last.character) then return end
            return { start = first, ["end"] = last }, ""
        elseif node:type() == "collapsed_reference_link" then
            local _, _, er, ec = node:range()
            local empty = position(bufnr, er, ec - 1, encoding)
            if params.position.line == empty.line and params.position.character == empty.character then
                return { start = empty, ["end"] = vim.deepcopy(empty) }, ""
            end
        end
        node = node:parent()
    end
    -- An unfinished second label has no link_label node yet. Recognize only
    -- an opening '[' immediately after a real shortcut_link, not code/images
    -- or arbitrary bracket-like text. The edit also supplies the missing ']'.
    local row = params.position.line
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local col = vim.str_byteindex(line, encoding, params.position.character, false)
    if col ~= #line then return end
    local opening = line:match("()%[[^%[%]]*$")
    if not opening or opening < 2 then return end
    local previous = inline:named_node_for_range({ row, opening - 2, row, opening - 2 })
    while previous do
        if previous:type() == "shortcut_link" then
            local _, _, er, ec = previous:range()
            if er == row and ec == opening - 1 then
                return {
                    start = position(bufnr, row, opening, encoding),
                    ["end"] = vim.deepcopy(params.position),
                }, "]"
            end
        end
        previous = previous:parent()
    end
end

local function reference_items(params, encoding)
    local bufnr, node, tree, inline = context(params, encoding, true)
    if not bufnr then return end
    local range, closing = reference_range(bufnr, node, inline, params, encoding)
    if not range then return end
    local items, seen = {}, {}
    -- Definitions belong to this document, not a workspace or fenced
    -- Markdown injection. Use syntax, not buffer-word suggestions.
    for _, label_node in definitions:iter_captures(tree:root(), bufnr) do
        local label = vim.treesitter.get_node_text(label_node, bufnr):sub(2, -2)
            :gsub("[ \t\r\n]+", " "):match("^%s*(.-)%s*$")
        if not seen[label] then
            seen[label] = true
            items[#items + 1] = {
                label = label,
                kind = vim.lsp.protocol.CompletionItemKind.Reference,
                textEdit = { range = range, newText = label .. closing },
            }
        end
    end
    return { isIncomplete = false, items = items }, bufnr, vim.api.nvim_buf_get_changedtick(bufnr)
end

function M.attach(client)
    -- Preserve the public transport's request IDs, callbacks and cancellation.
    -- Client:request()/request_sync(), built-in actions and blink all use it.
    local request = client.rpc.request
    client.rpc.request = function(method, params, callback, ...)
        if params and params.position and params.textDocument then
            if method == "textDocument/definition" then
                params = destination(params, client.offset_encoding)
            elseif method == "textDocument/completion" then
                local fallback, bufnr, tick = reference_items(params, client.offset_encoding)
                if fallback and #fallback.items > 0 then
                    local handler = callback
                    callback = function(err, result, ...)
                        local empty = not result or result == vim.NIL or vim.tbl_isempty(result.items or result)
                        if not err and empty and vim.api.nvim_buf_is_loaded(bufnr)
                            and vim.api.nvim_buf_get_changedtick(bufnr) == tick then
                            result = fallback
                        end
                        handler(err, result, ...)
                    end
                end
            end
        end
        return request(method, params, callback, ...)
    end
end

return M
