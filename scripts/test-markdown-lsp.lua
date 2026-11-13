-- Run against an applied config and restored plugins in a disposable HOME.
-- scripts/smoke-test.sh --nvim owns setup; assertion failures must exit nonzero.
local case = vim.env.DOTFILES_MARKDOWN_CASE or "file"
assert(case == "file" or case == "heading" or case == "legacy", "Unknown Markdown test case: " .. case)
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/workspace/docs", "p")
vim.fn.mkdir(root .. "/unrelated", "p")
root = assert(vim.uv.fs_realpath(root)) -- macOS /var aliases /private/var.
local workspace = root .. "/workspace"
if case == "legacy" then
    vim.fn.writefile({}, workspace .. "/.marksman.toml")
else
    vim.fn.mkdir(workspace .. "/.git")
end
local source = workspace .. "/docs/source.md"
local target = workspace .. "/docs/target.md"
local input = case == "legacy" and "[other](target.md#target-heading)" or "[other](tar"
vim.fn.writefile({ input }, source)
vim.fn.writefile({ "Introduction.", "", "## target heading", "", "Target text." }, target)

local function definition(client)
    local params = {
        textDocument = { uri = vim.uri_from_bufnr(0) },
        position = { line = 0, character = 10 },
    }
    for _ = 1, 30 do
        local response = client:request_sync("textDocument/definition", params, 2000, 0)
        assert(response and not response.err, vim.inspect(response))
        local result = response.result
        local location = result and (result.uri and result or result[1])
        if location then return location end
        vim.wait(100)
    end
    error("No definition for the Markdown link")
end

local ok, err = xpcall(function()
    vim.cmd.cd(root .. "/unrelated")
    vim.cmd.edit(source)
    assert(vim.wait(15000, function()
        return #vim.lsp.get_clients({ bufnr = 0, name = "markdown_oxide" }) == 1
    end), "Markdown Oxide did not attach")
    local client = vim.lsp.get_clients({ bufnr = 0, name = "markdown_oxide" })[1]
    assert(client.root_dir == workspace, "Lost Markdown workspace root: " .. tostring(client.root_dir))
    if case == "legacy" then
        local location = definition(client)
        assert(location.uri == vim.uri_from_fname(target), vim.inspect(location))
        assert(location.range.start.line == 2, "Definition did not reach the target heading")
        print("PASS: legacy Marksman workspace navigation from an unrelated directory")
        return
    end
    local params = {
        textDocument = { uri = vim.uri_from_bufnr(0) },
        position = { line = 0, character = 11 },
    }
    local completion
    for _ = 1, 30 do
        local response = client:request_sync("textDocument/completion", params, 2000, 0)
        assert(response and not response.err, vim.inspect(response))
        local items = response.result and (response.result.items or response.result) or {}
        for _, item in ipairs(items) do
            local wanted = case == "file" and vim.lsp.protocol.CompletionItemKind.File
                or vim.lsp.protocol.CompletionItemKind.Reference
            if item.kind == wanted and item.label:match("^target") then
                completion = item
                break
            end
        end
        if completion then break end
        vim.wait(100)
    end
    assert(completion, "No completion for target.md")
    -- Accept the server's edit/snippet, rather than just checking its label.
    local edit = assert(completion.textEdit)
    vim.lsp.util.apply_text_edits(
        { { range = edit.range, newText = "" } }, vim.api.nvim_get_current_buf(), client.offset_encoding
    )
    vim.api.nvim_win_set_cursor(0, { edit.range.start.line + 1, edit.range.start.character })
    vim.snippet.expand(edit.newText)
    vim.snippet.stop()
    local accepted = vim.api.nvim_get_current_line()
    local expected = case == "file" and "[other](target.md)" or "[other](target.md#target-heading)"
    assert(accepted == expected, "Non-portable accepted completion: " .. accepted)
    local location = definition(client)
    assert(location.uri == vim.uri_from_fname(target), "Accepted completion does not navigate")
    if case == "heading" then
        assert(location.range.start.line == 2, "Accepted heading completion did not reach its heading")
    end
    print("PASS: portable accepted Markdown " .. case .. " completion")
end, debug.traceback)

for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
vim.fn.delete(root, "rf")
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
end
vim.cmd("qa!")
