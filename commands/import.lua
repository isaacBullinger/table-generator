local core = require("table-generator.core")
local M = {}

M.insert_ascii_table = function(filename)
  local rows, total_width = core.read_csv(filename)
  local table_lines = core.generate_ascii_table(rows, total_width)
  vim.api.nvim_put(table_lines, 'l', true, true)
end

M.import_table_prompt = function()
    vim.ui.input({ prompt = "Enter filename (without extension): " }, function(input)
        if input and input ~= "" then
            local filename = input .. ".csv"
            local rows, total_width = core.read_csv(filename)
            local table_lines = core.generate_ascii_table(rows, total_width)
            vim.api.nvim_put(table_lines, 'l', true, true)
        else
            print("Import cancelled.")
        end
    end)
end

M.setup = function()
    vim.api.nvim_create_user_command("TableImport", function()
        M.import_table_prompt()
    end, {})
end

return M