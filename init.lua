local M = {}

-- Opens floating window for user input.
M.open_table_input = function()
    local buf = vim.api.nvim_create_buf(false, true)

    -- Set window in center
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.4)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create floating window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = math.floor(vim.o.columns * 0.6),
        height = math.floor(vim.o.lines * 0.4),
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = {"+","-","+","|"},
    })

    local msg = {
        "Write values in double quotes separated by commas. For rows, use a new line. Use the first row for headers. Press enter to generate table.",
        "Width: "
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, msg)
    vim.api.nvim_win_set_cursor(win, { #msg, 9})

    -- Close window using Esc
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>bd!<CR>", { noremap = true, silent = true })

    -- Keybinding to save to CSV
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('table-generator').process_input()<CR>", { noremap = true, silent = true })

    M.input_win = win
    M.input_buf = buf
end

-- Function that reads the CSV file and returns parsed rows and optional total width.
M.read_csv = function(filename)
    local path=vim.fn.getcwd() .. "/" .. filename
    local rows = {}
    local total_width = nil

    for line in io.lines(path) do
        if not total_width and line:match("^%s*%d+%s*$") then
            total_width = tonumber(line)
        else
            local fields = M.parse_csv_line(line)
            table.insert(rows, fields)
        end
    end
    return rows, total_width
end

-- Parses CSV lines and returns them as an array.
M.parse_csv_line = function(line)
    local fields = {}
    local pattern = '"(.-)"%s*,?%s*'

    local last_end = 1
    while true do
        local s, e, field = line:find(pattern, last_end)
        if not s then break end
        table.insert(fields, field)
        last_end = e + 1
    end
    return fields
end

-- Computes the max widths of columns.
M.get_col_widths = function(rows)
    local widths = {}
    for i = 1, #rows[1] do
        widths[i] = #rows[1][i]  -- start with header width
    end

    for row_index = 2, #rows do
        for i, cell in ipairs(rows[row_index]) do
            widths[i] = math.max(widths[i], #cell)
        end
    end

    return widths
end

-- Builds horizontal separator using - and + signs.
M.make_separator = function(widths)
  local sep = "+"
  for _, w in ipairs(widths) do
    sep = sep .. string.rep("-", w + 2) .. "+"
  end
  return sep
end

-- Adds a space before and after the content.
M.pad_cell = function(text_lines, width)
    local padded = {}
    for _, line in ipairs(text_lines) do
        line = line == "" and "" or (" " .. line .. string.rep(" ", width - #line + 1))
        table.insert(padded, line)
    end
    return padded
end

-- Wraps words in cell.
M.wrap_cell = function (text, width)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        if #line + #word + 1 > width then
            table.insert(lines, line)
            line = word
        else
            line = (#line > 0) and (line .. " " .. word) or word
        end
    end
    if #line > 0 then table.insert(lines, line) end
    return lines
end

-- Dynamically adjusts widths of the cell based on content.
M.adjust_widths = function(widths, max_total_width)
    local padding = (#widths * 3) + 1
    local total_width = 0
    for _, w in ipairs(widths) do total_width = total_width + w end
    total_width = total_width + padding

    if total_width <= max_total_width then
        return widths
    end

    local excess = total_width - max_total_width

    local indexed = {}
    for i, w in ipairs(widths) do
        table.insert(indexed, { i = i, w = w })
    end

    table.sort(indexed, function(a, b)
        return a.w > b.w
    end)

    local i = 1
    while excess > 0 do
        local idx = indexed[i].i
        if widths[idx] > 2 then
            widths[idx] = widths[idx] - 1
            excess = excess - 1
        end
        i = (i % #indexed) + 1
    end

    return widths
end


M.generate_ascii_table = function(rows, total_width)
    local widths = M.get_col_widths(rows)
    if total_width then
        widths = M.adjust_widths(widths, total_width)
    end

    local sep = M.make_separator(widths)
    local lines = { sep }

    for row_index, row in ipairs(rows) do
        local wrapped = {}
        local max_lines = 0

        for j, cell in ipairs(row) do
            local lines_cell = M.wrap_cell(cell, widths[j])
            wrapped[j] = lines_cell
            max_lines = math.max(max_lines, #lines_cell)
        end

        for j = 1, #widths do
            while #wrapped[j] < max_lines do
                table.insert(wrapped[j], "")
            end
        end

        for i = 1, max_lines do
            local line = "|"
            for j = 1, #widths do
                local text = wrapped[j][i] or ""
                line = line .. " " .. text .. string.rep(" ", widths[j] - #text + 1) .. "|"
            end
            table.insert(lines, line)
        end

        table.insert(lines, sep)
    end

    return lines
end

-- Save input to CSV file.
M.process_input = function()
    local width_line_index = 2
    local input_lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
    local width = tonumber(input_lines[width_line_index]:match("Width:%s*(%d+)"))

    local lines = vim.api.nvim_buf_get_lines(M.input_buf, width_line_index, -1, false)
    if #lines < 2 then
        print("No data to save.")
        return
    end

    vim.ui.input({ prompt = "Enter filename (without extension): " }, function(input)
        if input and input ~= "" then
            local path = vim.fn.getcwd() .. "/" .. input .. ".csv"
            local file = io.open(path, "w")

            if file then
                file:write(width .. "\n")
                for i = 1, #lines do
                    local fields = M.parse_csv_line(lines[i])
                    local quoted = {}
                    for _, field in ipairs(fields) do
                    table.insert(quoted, '"' .. field .. '"')
                end
                file:write(table.concat(quoted, ","), "\n")
            end
                file:close()
                print("CSV saved to: " .. path)

                -- Insert table
                local rows = M.read_csv(input .. ".csv")
                local table_lines = M.generate_ascii_table(rows, tonumber(width))

                vim.api.nvim_set_current_win(vim.fn.win_getid(vim.fn.bufwinnr(1)))
                vim.api.nvim_put(table_lines, 'l', true, true)
            else
                print("Failed to write file.")
            end
        else
            print("Save cancelled.")
        end

        vim.api.nvim_win_close(M.input_win, true)
    end)
end

M.insert_ascii_table = function(filename)
  local rows, total_width = M.read_csv(filename)
  local table_lines = M.generate_ascii_table(rows, total_width)
  vim.api.nvim_put(table_lines, 'l', true, true)
end

M.import_table_prompt = function()
    vim.ui.input({ prompt = "Enter filename (without extension): " }, function(input)
        if input and input ~= "" then
            local filename = input .. ".csv"
            local rows, total_width = M.read_csv(filename)
            local table_lines = M.generate_ascii_table(rows, total_width)
            vim.api.nvim_put(table_lines, 'l', true, true)
        else
            print("Import cancelled.")
        end
    end)
end

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
        local rows, _ = M.read_csv(file)
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
    local rows, total_width = M.read_csv(filename)
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

    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('table-generator')._finalize_edit('" .. filename .. "')<CR>", { noremap = true, silent = true })

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
    local rows = M.read_csv(filename)
    local table_lines = M.generate_ascii_table(rows, width)
    vim.api.nvim_put(table_lines, 'l', true, true)
end


-- Setup command
M.setup = function()
    vim.api.nvim_create_user_command("Table", function()
        M.open_table_input()
    end, {})
    vim.api.nvim_create_user_command("TableImport", function()
        M.import_table_prompt()
    end, {})
    vim.api.nvim_create_user_command("TableEdit", function()
        M.edit_table_at_cursor()
    end, {})
end

return M
