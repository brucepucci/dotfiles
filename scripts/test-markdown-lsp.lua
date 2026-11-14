-- Run against an applied config and restored plugins in a disposable HOME.
-- scripts/smoke-test.sh --nvim owns setup; failures must exit nonzero.
local root
local function run()
    local case = vim.env.DOTFILES_MARKDOWN_CASE or "file"
    assert(vim.tbl_contains({
        "file", "heading", "titlecase", "legacy", "precedence", "crossdir", "relative",
        "linktext", "reference", "reference-open", "table-linktext", "table-reference",
    }, case), "Unknown Markdown test case: " .. case)
    root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/workspace/docs", "p")
    vim.fn.mkdir(root .. "/unrelated", "p")
    root = assert(vim.uv.fs_realpath(root)) -- macOS /var aliases /private/var.
    local workspace = root .. "/workspace"
    if case == "legacy" or case == "precedence" then
        vim.fn.writefile({}, workspace .. "/.marksman.toml")
        if case == "precedence" then vim.fn.mkdir(workspace .. "/docs/.git") end
    else
        vim.fn.mkdir(workspace .. "/.git")
    end
    local source = workspace .. "/docs/source.md"
    local crossdir = case == "crossdir" or case == "relative"
    local target = workspace .. (crossdir and "/target.md" or "/docs/target.md")
    local heading = case == "titlecase" and "Target Heading" or "target heading"
    local reference = case == "reference" or case == "reference-open"
    local table_case = case == "table-linktext" or case == "table-reference"
    local input = (case == "legacy" or case == "linktext") and "[other](target.md#target-heading)"
        or case == "relative" and "[other](../target.md#target-heading)"
        or reference and (case == "reference-open" and "[other][tar" or "[other][tar]")
        or case == "crossdir" and "[other]()" or "[other](tar)"
    vim.fn.writefile(table_case and {
        "| Link |", "| --- |", "| [other](target.md#target-heading) |", "| [other][tar] |",
        "", "[target]: target.md#target-heading",
    } or reference and {
        input, "", "[target]: target.md#target-heading", "",
        "`[target-inline]: missing.md`", "", "```markdown", "[target-fenced]: missing.md", "```",
    } or { input }, source)
    vim.fn.writefile({ "Introduction.", "", "## " .. heading, "", "Target text." }, target)
    if case == "precedence" then
        vim.fn.writefile({ "[inbound](docs/target.md#target-heading)" }, workspace .. "/inbound.md")
    end

    vim.cmd.cd(root .. "/unrelated")
    vim.cmd.edit(case == "precedence" and target or source)
    assert(vim.wait(15000, function()
        return #vim.lsp.get_clients({ bufnr = 0 }) == 1
    end), "Markdown language server did not attach")
    local client = vim.lsp.get_clients({ bufnr = 0 })[1]
    assert(client.root_dir == workspace, "Lost Markdown workspace root: " .. tostring(client.root_dir))

    local function request(method, params, select)
        local last
        for _ = 1, 30 do
            local response = client:request_sync(method, params, 2000, 0)
            assert(response and not response.err, vim.inspect(response))
            last = response.result
            local selected = select(last)
            if selected then return selected end
            vim.wait(100)
        end
        error("No expected result for " .. method .. ": " .. vim.inspect(last))
    end

    local function definition(character, row)
        return request("textDocument/definition", {
            textDocument = { uri = vim.uri_from_bufnr(0) },
            position = { line = row or 0, character = character or 10 },
        }, function(result)
            local location = result and (result.uri and result or result[1])
            if location and location.targetUri then
                location = { uri = location.targetUri, range = location.targetSelectionRange }
            end
            -- didChange/index updates may arrive after the edit was accepted.
            local points_to_heading = case == "heading" or case == "titlecase" or case == "legacy"
                or case == "relative" or case == "linktext" or case == "table-linktext"
            if location and location.uri == vim.uri_from_fname(target)
                and (not points_to_heading or location.range.start.line == 2) then
                return location
            end
        end)
    end

    if case == "table-linktext" then
        definition(14, 2) -- native destination control
        definition(5, 2) -- displayed text in the same table cell
        print("PASS: table inline-link definition from display text and destination")
        return
    end
    if case == "linktext" then
        -- Both requests must retain the existing navigation action, without
        -- requiring the user to move from displayed text into its destination.
        definition(12)
        for _, character in ipairs({ 0, 1, 3, 6, #input - 1 }) do definition(character) end
        for _, line in ipairs({
            "🙂 [**other**](target.md#target-heading)",
            "[other](<target.md#target-heading>)",
            "[other](../docs/target.md#target-heading)",
        }) do
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
            local byte = assert(line:find("other", 1, true)) -- inside the displayed text
            definition(vim.str_utfindex(line, client.offset_encoding, byte, false))
        end
        print("PASS: inline-link definition across its span; Unicode, nested text, angle/relative destinations")
        return
    end
    if case == "precedence" then
        request("textDocument/references", {
            textDocument = { uri = vim.uri_from_bufnr(0) },
            position = { line = 2, character = 5 },
            context = { includeDeclaration = false },
        }, function(result)
            for _, ref in ipairs(result or {}) do
                if ref.uri == vim.uri_from_fname(workspace .. "/inbound.md") then return ref end
            end
        end)
        print("PASS: legacy root takes precedence over nested Git; inbound reference found")
        return
    end
    if case == "legacy" or case == "relative" then
        local location = definition()
        assert(location.uri == vim.uri_from_fname(target), vim.inspect(location))
        assert(location.range.start.line == 2, "Definition did not reach the target heading")
        if case == "relative" then
            vim.cmd.edit(target)
            request("textDocument/references", {
                textDocument = { uri = vim.uri_from_bufnr(0) },
                position = { line = 2, character = 5 },
                context = { includeDeclaration = false },
            }, function(result)
                for _, ref in ipairs(result or {}) do
                    if ref.uri == vim.uri_from_fname(source) then return ref end
                end
            end)
        end
        print("PASS: " .. case .. " link navigation/references from an unrelated directory")
        return
    end

    local function complete(kind, character, label, row)
        row = row or 0
        local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
        local candidates
        local item = request("textDocument/completion", {
            textDocument = { uri = vim.uri_from_bufnr(0) },
            position = { line = row, character = character or #line - 1 }, -- before the closing delimiter
        }, function(result)
            candidates = result and (result.items or result) or {}
            for _, candidate in ipairs(candidates) do
                local is_target = vim.fs.basename(candidate.label):gsub("%.md$", "") == "target"
                if candidate.kind == kind and (not label or candidate.label == label)
                    and (kind ~= vim.lsp.protocol.CompletionItemKind.File or is_target) then
                    return candidate
                end
            end
        end)
        local edit = assert(item.textEdit)
        local bufnr = vim.api.nvim_get_current_buf()
        if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
            vim.lsp.util.apply_text_edits({ { range = edit.range, newText = "" } }, bufnr, client.offset_encoding)
            vim.api.nvim_win_set_cursor(0, { edit.range.start.line + 1, edit.range.start.character })
            vim.snippet.expand(edit.newText)
            vim.snippet.stop()
        else
            vim.lsp.util.apply_text_edits({ edit }, bufnr, client.offset_encoding)
        end
        return vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1], candidates
    end

    if case == "table-reference" then
        local accepted = complete(vim.lsp.protocol.CompletionItemKind.Reference, 13, "target", 3)
        assert(accepted == "| [other][target] |", "Table reference label was not completed: " .. accepted)
        assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "| Link |", "Completion changed the table header")
        assert(vim.api.nvim_buf_get_lines(0, 5, 6, false)[1] == "[target]: target.md#target-heading",
            "Completion changed the reference definition")
        for _, fixture in ipairs({
            {
                lines = { "| Link |", "| --- |", "| `[other][tar]` |", "", "[target]: target.md" },
                row = 2, character = 14,
            },
            {
                lines = { "```markdown", "| Link |", "| --- |", "| [other][tar] |", "```", "", "[target]: target.md" },
                row = 3, character = 13,
            },
        }) do
            vim.api.nvim_buf_set_lines(0, 0, -1, false, fixture.lines)
            local response = client:request_sync("textDocument/completion", {
                textDocument = { uri = vim.uri_from_bufnr(0) },
                position = { line = fixture.row, character = fixture.character },
            }, 2000, 0)
            assert(response and not response.err, vim.inspect(response))
            local result = response.result
            for _, candidate in ipairs(result and (result.items or result) or {}) do
                assert(candidate.kind ~= vim.lsp.protocol.CompletionItemKind.Reference,
                    "Table reference completion leaked into code: " .. vim.inspect(candidate))
            end
        end
        print("PASS: table reference-label edits preserve table/definition; code and fenced tables excluded")
        return
    end
    if reference then
        local accepted, candidates = complete(vim.lsp.protocol.CompletionItemKind.Reference,
            case == "reference-open" and #vim.api.nvim_get_current_line() or nil)
        assert(accepted == "[other][target]", "Reference label was not completed: " .. accepted)
        for _, candidate in ipairs(candidates) do
            assert(candidate.label == "target", "Not a document reference definition: " .. candidate.label)
        end
        assert(vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == "[target]: target.md#target-heading",
            "Completion changed the reference definition")
        vim.api.nvim_buf_set_lines(0, 0, 1, false, { "[other][]" })
        accepted = complete(vim.lsp.protocol.CompletionItemKind.Reference)
        assert(accepted == "[other][target]", "Empty reference label was not completed: " .. accepted)
        -- Re-read unsaved definitions, not an attachment-time index or the disk.
        vim.api.nvim_buf_set_lines(0, 0, 1, false, { "[other][lat]" })
        vim.api.nvim_buf_set_lines(0, -1, -1, false, { "", "[later]: target.md" })
        accepted = complete(vim.lsp.protocol.CompletionItemKind.Reference, nil, "later")
        assert(accepted == "[other][later]", "Unsaved reference definition was not offered: " .. accepted)
        for _, fixture in ipairs({
            { lines = { "`[other][tar]`", "", "[target]: target.md" }, row = 0, character = 12 },
            { lines = { "```markdown", "[other][tar]", "```", "", "[target]: target.md" }, row = 1, character = 11 },
        }) do
            vim.api.nvim_buf_set_lines(0, 0, -1, false, fixture.lines)
            local response = client:request_sync("textDocument/completion", {
                textDocument = { uri = vim.uri_from_bufnr(0) },
                position = { line = fixture.row, character = fixture.character },
            }, 2000, 0)
            assert(response and not response.err, vim.inspect(response))
            local result = response.result
            for _, candidate in ipairs(result and (result.items or result) or {}) do
                assert(candidate.kind ~= vim.lsp.protocol.CompletionItemKind.Reference,
                    "Reference completion leaked into code: " .. vim.inspect(candidate))
            end
        end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
            "[other][ta", "r]", "", "[target]: target.md",
        })
        local response = client:request_sync("textDocument/completion", {
            textDocument = { uri = vim.uri_from_bufnr(0) },
            position = { line = 0, character = 10 },
        }, 2000, 0)
        assert(response and not response.err, vim.inspect(response))
        local result = response.result
        for _, candidate in ipairs(result and (result.items or result) or {}) do
            if candidate.textEdit then
                local range = candidate.textEdit.range
                assert(range.start.line == 0 and range["end"].line == 0,
                    "Completion emitted a forbidden multiline edit: " .. vim.inspect(candidate))
            end
        end
        print("PASS: live reference labels (closed/open/empty), code exclusions, valid edit ranges")
        return
    end
    -- Accept real protocol edits, rather than checking only suggestion labels.
    local accepted = complete(vim.lsp.protocol.CompletionItemKind.File)
    local destination = assert(accepted:match("^%[other%]%(([^)]+)%)$"), accepted)
    assert(vim.uv.fs_realpath(vim.fs.dirname(source) .. "/" .. destination) == target,
        "Accepted completion does not name the actual file relative to its source: " .. accepted)
    local expected_path = case == "crossdir" and "../target.md" or "target.md"
    assert(destination == expected_path, "Non-portable accepted completion: " .. accepted)
    if case == "heading" or case == "titlecase" then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[other](" .. destination .. "#)" })
        accepted = complete(vim.lsp.protocol.CompletionItemKind.Reference)
        -- Evaluate the actual slug function used by the pinned preview bundle,
        -- rather than using this language server as its own anchor oracle.
        local bundles = vim.fn.glob(vim.fn.stdpath("data")
            .. "/lazy/markdown-preview.nvim/app/out/_next/static/*/pages/index.js", false, true)
        assert(#bundles == 1, "Expected one pinned preview bundle")
        local js = [[
            const fs = require('node:fs');
            const vm = require('node:vm');
            const bundle = fs.readFileSync(process.argv[1], 'utf8');
            const slug = bundle.match(/\.defaults=\{level:1,slugify:(function\([^)]*\)\{return [^}]+\})/);
            if (!slug) throw new Error('Pinned preview slug function not found');
            process.stdout.write(vm.runInNewContext('(' + slug[1] + ')(heading)',
                { heading: process.argv[2] }, { timeout: 1000 }));
        ]]
        local rendered = vim.system({ "node", "-e", js, bundles[1], heading }, { text = true }):wait()
        assert(rendered.code == 0, rendered.stderr)
        assert(rendered.stdout == "target-heading", "Unexpected preview anchor: " .. rendered.stdout)
        assert(accepted == "[other](target.md#" .. rendered.stdout .. ")",
            "Completion does not match the preview's rendered heading anchor: " .. accepted)
    end
    local location = definition()
    assert(location.uri == vim.uri_from_fname(target), "Accepted completion does not navigate: " .. vim.inspect(location))
    if case == "heading" or case == "titlecase" then
        assert(location.range.start.line == 2, "Accepted completion did not reach its heading")
    end
    print("PASS: portable accepted Markdown " .. case .. " completion")
end

local ok, err = xpcall(run, debug.traceback)
for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
if root then vim.fn.delete(root, "rf") end
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
end
vim.cmd("qa!")
