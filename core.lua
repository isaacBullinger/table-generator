local M = {}

-- Parses CSV lines and returns them as a table of fields.
M.parse_csv_line = function(line)
    local fields = {}
    local field = ""
    local in_quotes = false

    for i = 1, #line do
        local char = line:sub(i, i)
        if char == '"' then
            in_quotes = not in_quotes
        elseif char == ',' and not in_quotes then
            table.insert(fields, field)
            field = ""
        else
            field = field .. char
        end
    end
    table.insert(fields, field)

    -- Remove outer quotes and trim whitespace
    for i = 1, #fields do
        fields[i] = fields[i]:gsub('^%s*"(.-)"%s*$', "%1")
    end
    return fields
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

-- Computes the max widths of columns based on headers.
M.get_col_widths = function(rows)
    local widths = {}
    for i = 1, #rows[1] do
        widths[i] = #rows[1][i]
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

-- Wraps words in cell breaking by whole words.
M.wrap_cell = function (text, width)
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
        if #line + #word + (line == "" and 0 or 1) > width then
            table.insert(lines, line)
            line = word
        else
            line = (#line > 0) and (line .. " " .. word) or word
        end
    end
    if #line > 0 then
        table.insert(lines, line)
    elseif #lines == 0 then
        table.insert(lines, "")
    end
    return lines
end

-- Dynamically adjusts widths of the cell based on content and maximum width.
M.adjust_widths = function(widths, max_total_width, header_row)
    local padding = (#widths * 3) + 1
    local total_width = 0
    for _, w in ipairs(widths) do total_width = total_width + w end
    total_width = total_width + padding

    if total_width <= max_total_width then
        return widths
    end

    local excess = total_width - max_total_width

    -- Sort columns by width in descending order.
    local indexed = {}
    for i, w in ipairs(widths) do
        table.insert(indexed, { i = i, w = w })
    end

    table.sort(indexed, function(a, b)
        return a.w > b.w
    end)

    -- Reduce widths of widest columns first, without going below the minumum header width.
    local i = 1
    while excess > 0 do
        local idx = indexed[i].i
        local min_width = #header_row[idx]
        if widths[idx] > min_width then
            widths[idx] = widths[idx] - 1
            excess = excess - 1
        end
        i = (i % #indexed) + 1
    end

    return widths
end

-- Generates ASCII table from parsed CSV rows.
M.generate_ascii_table = function(rows, total_width)
    local widths = M.get_col_widths(rows)
    if total_width then
        widths = M.adjust_widths(widths, total_width, rows[1])
    end

    local sep = M.make_separator(widths)
    local lines = { sep }

    -- Adds a row to the ASCII table, handling wrapping and alignment
    local function add_wrapped_row(row)
        local wrapped, max_lines = {}, 0

        -- Wrap each cell and find the tallest cell.
        for i, cell in ipairs(row) do
            local wrapped_lines = M.wrap_cell(cell, widths[i])
            wrapped[i] = wrapped_lines
            max_lines = math.max(max_lines, #wrapped_lines)
        end

        -- Pad all cells to have the same number of lines (bottom padding)
        for i = 1, #wrapped do
            while #wrapped[i] < max_lines do
                table.insert(wrapped[i], "")
            end
        end

        -- build each physical line
        for line_num = 1, max_lines do
            local line = "|"
            for i = 1, #widths do
                local content = wrapped[i][line_num]
                line = line .. " " .. content .. string.rep(" ", widths[i] - #content + 1) .. "|"
            end
            table.insert(lines, line)
        end

        table.insert(lines, sep)
    end

    -- Add header row
    add_wrapped_row(rows[1])

    -- Add data rows
    for i = 2, #rows do
        add_wrapped_row(rows[i])
    end

    return lines
end

return M