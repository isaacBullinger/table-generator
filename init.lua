local M = {}

-- Floating window function
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

-- Function that reads the CSV file and returns the data
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

M.get_col_widths = function(rows)
    local widths = {}
    for _, row in ipairs(rows) do
        for i, cell in ipairs(row) do
            widths[i] = math.max(widths[i] or 0, #cell)
        end
    end
    return widths
end

M.make_separator = function(widths)
  local sep = "+"
  for _, w in ipairs(widths) do
    sep = sep .. string.rep("-", w + 2) .. "+"
  end
  return sep
end

M.pad_cell = function(text, width)
  return " " .. text .. string.rep(" ", width - #text + 1)
end

M.generate_ascii_table = function(rows, total_width)
    local widths = M.get_col_widths(rows)
    if total_width then
        local sum = 0
        for _, w in ipairs(widths) do sum = sum + w end
        local padding = total_width - sum - (#widths * 3) - 1
        if padding > 0 then
            local extra = math.floor(padding / #widths)
            for i = 1, #widths do
                widths[i] = widths[i] + extra
            end
        end
    end
    local sep = M.make_separator(widths)
    local lines = { sep }

    for _, row in ipairs(rows) do
        local line = "|"
        for j, cell in ipairs(row) do
            line = line .. M.pad_cell(cell, widths[j]) .. "|"
        end
        table.insert(lines, line)
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
                local table_lines = M.generate_ascii_table(rows, width)

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
    vim.api.nvim_create_user_command("Tables", function()
        M.open_table_input()
    end, {})
end

return M
