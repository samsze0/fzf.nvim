local FzfConfig = require("fzf.core.config")

local M = {}

---@param config? FzfConfig.config
M.setup = function(config) FzfConfig:setup(config) end

return M
