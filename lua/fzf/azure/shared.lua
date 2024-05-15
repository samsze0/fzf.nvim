local M = {}

-- Check if the Azure CLI is available
--
---@return boolean
M.is_azurecli_available = function() return vim.fn.executable("az") == 1 end

return M
