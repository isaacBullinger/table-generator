local M = {}

M.setup = function ()
    require("table-generator.commands.table").setup()
    require("table-generator.commands.import").setup()
    require("table-generator.commands.edit").setup()
end

return M