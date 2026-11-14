-- Markdown client compatibility gaps in rumdl 0.3.4. Keep the server's
-- indexing/navigation and Neovim's existing actions; do not change keymaps.
local M = {}
local definitions = vim.treesitter.query.parse("markdown", [[
    (link_reference_definition (link_label) @label)
]])

local function position(bufnr, row, col, encoding)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    return { line = row, character = vim.str_utfindex(line, encoding, col, false) }
end

local function inline_block(tree, row, col)
    local block = tree:root():named_descendant_for_range(row, col, row, col)
    while block and block:type() ~= "inline" and block:type() ~= "pipe_table_cell" do
        block = block:parent()
    end
    return block
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
    -- Admit paragraph/table inline content only from the original block tree;
    -- never descend into fenced Markdown injections or code blocks.
    if not inline_block(tree, row, probe) then return end
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

local label_usages = vim.treesitter.query.parse("markdown_inline", [[
    (full_reference_link (link_label) @label)
    (collapsed_reference_link (link_text) @label)
    (shortcut_link (link_text) @label)
]])

local function fold_labels(records)
    local labels, unicode = {}, false
    for i, record in ipairs(records) do
        local label = record.label:gsub("[ \t\r\n]+", " "):gsub("^ ", ""):gsub(" $", "")
        unicode = unicode or label:find("[\128-\255]") ~= nil
        labels[i] = label
    end
    if not unicode then
        for i, label in ipairs(labels) do labels[i] = label:lower() end
        return labels
    end
    -- Neovim's lowercase/stricmp APIs do not implement Unicode casefold
    -- expansions (e.g. Straße/STRASSE). Batch through the existing Python3
    -- toolchain, without user/site packages, rather than vendor Unicode data.
    local folded = vim.system({ "python3", "-I", "-S", "-c", [[
import json, sys
json.dump([label.casefold() for label in json.load(sys.stdin)], sys.stdout)
    ]] }, { stdin = vim.json.encode(labels), text = true }):wait(1000)
    assert(folded.code == 0, "Markdown label casefold failed: " .. (folded.stderr or ""))
    return vim.json.decode(folded.stdout)
end

local function label_references(params, encoding)
    local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
    if not vim.api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].filetype ~= "markdown" then return end
    local row = params.position.line
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if not line then return end
    local col = vim.str_byteindex(line, encoding, params.position.character, false)
    local parser = vim.treesitter.get_parser(bufnr, "markdown")
    -- Discover all inline regions even before highlighting has initialized
    -- injections (for example, a newly attached unhighlighted buffer).
    local tree = parser:parse(true)[1]
    local records, selected = {}, nil
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local function add(node, declaration)
        local sr, sc, er, ec = node:range()
        if not declaration and not inline_block(tree, sr, sc) then return end
        local label = vim.treesitter.get_node_text(node, bufnr)
        if node:type() == "link_label" then label = label:sub(2, -2) end
        local subject = declaration and node or node:parent()
        records[#records + 1] = {
            label = label,
            declaration = declaration,
            location = {
                uri = params.textDocument.uri,
                range = { start = position(bufnr, sr, sc, encoding), ["end"] = position(bufnr, er, ec, encoding) },
            },
        }
        if vim.treesitter.is_in_node_range(subject, row, col) then selected = #records end
    end
    for _, node in definitions:iter_captures(tree:root(), bufnr) do add(node, true) end
    -- Fences explicitly tagged markdown_inline can share this language tree,
    -- so add() also checks original-block ancestry for every collected usage.
    -- Reference-label namespaces are document-local, not URL-based.
    local inline = parser:children().markdown_inline
    if inline then
        for _, inline_tree in pairs(inline:trees()) do
            for _, node in label_usages:iter_captures(inline_tree:root(), bufnr) do add(node, false) end
        end
    end
    if not selected then return end
    local folded = fold_labels(records)
    local declaration, locations = nil, {}
    for i, record in ipairs(records) do
        if folded[i] == folded[selected] then
            if record.declaration then
                declaration = declaration or record.location
            else
                locations[#locations + 1] = record.location
            end
        end
    end
    if not declaration then return end -- unresolved bracket text is not a semantic link
    if params.context and params.context.includeDeclaration then locations[#locations + 1] = declaration end
    return locations, bufnr, tick
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
            elseif method == "textDocument/references" then
                local locations, bufnr, tick = label_references(params, client.offset_encoding)
                if locations then
                    local handler = callback
                    callback = function(err, result, ...)
                        if not err and vim.api.nvim_buf_is_loaded(bufnr)
                            and vim.api.nvim_buf_get_changedtick(bufnr) == tick then
                            result = locations
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
