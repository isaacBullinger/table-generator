local core = require("table-generator.core")
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

    -- Instructional message and width prompt.
    local msg = {
        "Write values in double quotes separated by commas. For rows, use a new line. Use the first row for headers. Press enter to generate table.",
        "Width: "
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, msg)
    vim.api.nvim_win_set_cursor(win, { #msg, 9})

    -- Close window using Esc
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>bd!<CR>", { noremap = true, silent = true })

    -- Process input using Enter
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('table-generator.commands.table').process_input()<CR>", { noremap = true, silent = true })

    M.input_win = win
    M.input_buf = buf
end

-- Processes user input, saves to CSV file, generates the ASCII table and inserts it into the current buffer.
M.process_input = function()
    local width_line_index = 2
    local input_lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
    local width = tonumber(input_lines[width_line_index]:match("Width:%s*(%d+)"))

    -- Collect CSV content lines
    local all_lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
    local lines = {}
    for i = width_line_index + 1, #all_lines do
        -- Skip empty lines
        if all_lines[i]:match('%S') then
            table.insert(lines, all_lines[i])
        end
    end
    if #lines < 2 then
        print("No data to save.")
        return
    end

    -- Prompt user for file name
    vim.ui.input({ prompt = "Enter filename (without extension): " }, function(input)
        if input and input ~= "" then
            local path = vim.fn.getcwd() .. "/" .. input .. ".csv"
            local file = io.open(path, "w")

            if file then
                -- Set width in the first line
                file:write(width .. "\n")
                for i = 1, #lines do
                    local fields = core.parse_csv_line(lines[i])
                    local quoted = {}
                    for _, field in ipairs(fields) do
                    table.insert(quoted, '"' .. field .. '"')
                end
                file:write(table.concat(quoted, ","), "\n")
            end
                file:close()
                print("CSV saved to: " .. path)

                -- Generate ASCII table and insert into current buffer
                local rows = core.read_csv(input .. ".csv")
                local table_lines = core.generate_ascii_table(rows, tonumber(width))

                vim.api.nvim_set_current_win(vim.fn.win_getid(vim.fn.bufwinnr(1)))
                vim.api.nvim_put(table_lines, 'l', true, true)
            else
                print("Failed to write file.")
            end
        else
            print("Save cancelled.")
        end

        -- Close floating window
        vim.api.nvim_win_close(M.input_win, true)
    end)
end

-- Binds the :Table command to open the input UI.
M.setup = function()
    vim.api.nvim_create_user_command("Table", function()
        M.open_table_input()
    end, {})
end

return M