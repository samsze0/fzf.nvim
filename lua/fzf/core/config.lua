local Config = require("tui.config")
local opts_utils = require("utils.opts")

---@class FzfConfig.config : TUIConfig.config
---@field ipc_client_type FzfIpcClientType
---@field default_rg_args ShellOpts

---@class FzfConfig: TUIConfig
---@field value FzfConfig.config
local FzfConfig = {}
FzfConfig.__index = FzfConfig
FzfConfig.__is_class = true
setmetatable(FzfConfig, { __index = Config })

---@return FzfConfig
function FzfConfig.new()
    local obj = setmetatable(Config.new(), FzfConfig)
    ---@cast obj FzfConfig

    obj.value.ipc_client_type = 1
    -- TODO: move to private usage
    obj.value.default_extra_args = {
        ["--scroll-off"] = "2",
    }
    obj.value.default_rg_args = {
        ["--smart-case"] = true,
        ["--no-ignore"] = true,
        ["--hidden"] = true,
        ["--trim"] = true,
        ["--color"] = "always",
        ["--colors"] = {
        "'match:fg:blue'",
        "'path:none'",
        "'line:none'",
        },
        ["--no-column"] = true,
        ["--line-number"] = true,
        ["--no-heading"] = true,
    }

    return obj
end

---@param config? FzfConfig.config
function FzfConfig:setup(config)
    self.value = opts_utils.deep_extend(self.value, config)
end

return FzfConfig.new()
