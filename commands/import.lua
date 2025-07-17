local core = require("table-generator.core")
local M = {}

-- Inserts an ASCII table from filename.
M.insert_ascii_table = function(filename)
  local rows, total_width = core.read_csv(filename)
  local table_lines = core.generate_ascii_table(rows, total_width)
  vim.api.nvim_put(table_lines, 'l', true, true)
end

-- Prompts user for filename, then reads and inserts ASCII table, if file is not found gives error message.
M.import_table_prompt = function()
    vim.ui.input({ prompt = "Enter filename (without extension): " }, function(input)
        if input and input ~= "" then
            local filename = input .. ".csv"
            local rows, total_width = core.read_csv(filename)
            local table_lines = core.generate_ascii_table(rows, total_width)
            vim.api.nvim_put(table_lines, 'l', true, true)
        else
            print("File not found.")
        end
    end)
end

-- Binds the :TableImport command to prompt and insert a table that the user determines.
M.setup = function()
    vim.api.nvim_create_user_command("TableImport", function()
        M.import_table_prompt()
    end, {})
end

return M