local core = require("table-generator.core")
local M = {}

M.edit_table_at_cursor = function()
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    local buf = vim.api.nvim_get_current_buf()
    local total_lines = vim.api.nvim_buf_line_count(buf)

    -- Find the top and bottom lines marked by +
    local top = cursor_row
    while top > 1 do
        local line = vim.api.nvim_buf_get_lines(buf, top - 2, top - 1, false)[1]
        if not line or not line:match("^%s*[%+|]") then break end
        top = top - 1
    end

    local bottom = cursor_row
    while bottom < total_lines do
        local line = vim.api.nvim_buf_get_lines(buf, bottom, bottom + 1, false)[1]
        if not line or not line:match("^%s*[%+|]") then break end
        bottom = bottom + 1
    end

    -- Extract the table lines
    local table_lines = vim.api.nvim_buf_get_lines(buf, top - 1, bottom, false)
    if #table_lines < 3 then
        print("Could not find full table.")
        return
    end

    -- Extract headers from first non-+ line
    local headers
    for _, line in ipairs(table_lines) do
        if line:find("|") and not line:match("^%s*%+") then
            local fields = {}
            local clean_line = line:match("^%s*|%s*(.-)%s*|%s*$") or ""
            for h in clean_line:gmatch("%s*([^|]+)%s*|?") do
                fields[#fields + 1] = h:lower():gsub("%s+", "")
            end
            headers = fields
            break
        end
    end

    if not headers then
        print("No headers found.")
        return
    end

    -- Find matching CSV file
    local files = vim.fn.glob("*.csv", 0, 1)
    for _, file in ipairs(files) do
        local rows, _ = core.read_csv(file)
        if #rows > 0 and #rows[1] == #headers then
            local match = true
            for i = 1, #headers do
                local from_table = headers[i]:lower():gsub("%s+", "")
                local from_csv = rows[1][i]:lower():gsub("%s+", "")
                if from_table ~= from_csv then
                    match = false
                    break
                end
            end
            local normalized_csv = {}
            for _, h in ipairs(rows[1]) do
                normalized_csv[#normalized_csv + 1] = h:lower():gsub("%s+", "")
            end
            if match then
                M._edit_range = { top = top - 1, bottom = bottom }
                print("Found match: " .. file)
                M.edit_existing_csv(file)
                return
            end
        end
    end

    print("No matching CSV found.")
end

M.edit_existing_csv = function(filename)
    local rows, total_width = core.read_csv(filename)
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.4)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = { "+", "-", "+", "|" },
    })

    local lines = { "Edit Table. Width: " .. (total_width or ""), "" }
    for _, row in ipairs(rows) do
        local quoted = {}
        for _, field in ipairs(row) do
            table.insert(quoted, '"' .. field .. '"')
        end
        table.insert(lines, table.concat(quoted, ","))
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>bd!<CR>", { noremap = true, silent = true })

    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('table-generator.commands.edit')._finalize_edit('" .. filename .. "')<CR>", { noremap = true, silent = true })

    M.input_win = win
    M.input_buf = buf
end

M._finalize_edit = function(filename)
    local lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
    local width = tonumber(lines[1]:match("Width:%s*(%d+)")) or 40
    local file = io.open(vim.fn.getcwd() .. "/" .. filename, "w")
    if not file then print("Failed to save CSV."); return end

    file:write(width .. "\n")
    for i = 3, #lines do
        file:write(lines[i], "\n")
    end
    file:close()
    vim.api.nvim_win_close(M.input_win, true)

    -- Delete old table
    local range = M._edit_range
    if range then
        vim.api.nvim_buf_set_lines(0, range.top, range.bottom, false, {})
    end

    -- Insert updated table
    local rows = core.read_csv(filename)
    local table_lines = core.generate_ascii_table(rows, width)
    vim.api.nvim_put(table_lines, 'l', true, true)
end

M.setup = function()
    vim.api.nvim_create_user_command("TableEdit", function()
        M.edit_table_at_cursor()
    end, {})
end

return M