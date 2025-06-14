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
    for _, row in ipairs(rows) do
        for i, cell in ipairs(row) do
            widths[i] = math.max(widths[i] or 0, #cell)
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
    while excess > 0 do
        local shrunk_any = false
        for i = 1, #widths do
            if widths[i] > 2 and excess > 0 then
                widths[i] = widths[i] - 1
                excess = excess - 1
                shrunk_any = true
            end
        end
        if not shrunk_any then break end
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
            local cell_lines = wrapped[j]
            while #wrapped[j] < max_lines do
                table.insert(wrapped[j], "")
            end
            wrapped[j] = cell_lines
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

-- Setup command
M.setup = function()
    vim.api.nvim_create_user_command("Table", function()
        M.open_table_input()
    end, {})
end

return M
