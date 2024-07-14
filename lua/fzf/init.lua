local Config = require("fzf.core.config")

local M = {}

---@param config? FzfConfig.config
M.setup = function(config) Config:setup(config) end

return M
