local M = {}

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

return M