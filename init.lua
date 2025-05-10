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
        "Write values in double quotes separated by commas.",
        "For rows, use a new line. Use the first row for headers.",
        ""
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, msg)
    vim.api.nvim_win_set_cursor(win, { #msg, 0})

    -- Close window using Esc
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>bd!<CR>", { noremap = true, silent = true })

    -- Keybinding to generate table
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('table-generator').process_input()<CR>", { noremap = true, silent = true })

    M.input_win = win
    M.input_buf = buf
end

-- Save user input to CSV
M.process_input = function()
    local start_line = 2 -- skip first 3 lines (0-based)
    local lines = vim.api.nvim_buf_get_lines(M.input_buf, start_line, -1, false)
    local csv_path = vim.fn.stdpath("data") .. "/table_output.csv"

    local file = io.open(csv_path, "w")
    if file then
        for _, line in ipairs(lines) do
            file:write(line, "\n")
        end
        file:close()
        print("CSV saved to: " .. csv_path)
    else
        print("Failed to write CSV file")
    end

    vim.api.nvim_win_close(M.input_win, true)
end

-- Setup command
M.setup = function()
    vim.api.nvim_create_user_command("Tables", function()
        M.open_table_input()
    end, {})
end

return M
