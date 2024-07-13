local Config = require("tui.config")
local opts_utils = require("utils.opts")

---@class FzfHighlightGroupsConfig.border_text
---@field selector_breadcrumbs? string

---@class FzfHighlightGroupsConfig : TUIHighlightGroupsConfig
---@field border_text FzfHighlightGroupsConfig.border_text

---@class FzfConfig.config : TUIConfig.config
---@field ipc_client_type? FzfIpcClientType
---@field default_rg_args? ShellOpts
---@field highlight_groups? FzfHighlightGroupsConfig

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

    obj.value = opts_utils.deep_extend(obj.value, {
        ipc_client_type = 1,
        default_extra_args = {
            -- TODO: move to private usage
            ["--scroll-off"] = "2",
        },
        default_rg_args = {
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
        },
        highlight_groups = {
            border_text = {
                selector_breadcrumbs = "FzfSelectorBreadcrumbs",
            },
        },

    })

    return obj
end

---@param config? FzfConfig.config
function FzfConfig:setup(config)
    self.value = opts_utils.deep_extend(self.value, config)
end

return FzfConfig.new()
