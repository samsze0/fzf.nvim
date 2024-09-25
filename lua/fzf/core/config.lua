local TUIConfig = require("tui.config")
local opts_utils = require("utils.opts")
local oop_utils = require("utils.oop")

---@class FzfHighlightGroupsConfig.border_text
---@field selector_breadcrumbs? string
---@field filetype? string
---@field loading_indicator? string
---@field stale_indicator? string

---@class FzfHighlightGroupsConfig : TUIHighlightGroupsConfig
---@field border_text FzfHighlightGroupsConfig.border_text

---@class FzfConfig.config : TUIConfig.config
---@field ipc_client_type? FzfIpcClientType
---@field default_rg_args? ShellOpts
---@field default_delta_args? ShellOpts
---@field highlight_groups? FzfHighlightGroupsConfig
---@field focus_event_default_debounce_ms? number
---@field change_event_default_debounce_ms? number
---@field fzf_bin? string

---@class FzfConfig: TUIConfig
---@field value FzfConfig.config
local FzfConfig = oop_utils.new_class(TUIConfig)

---@return FzfConfig
function FzfConfig.new()
  local obj = setmetatable(TUIConfig.new(), FzfConfig)
  ---@cast obj FzfConfig

  obj.value = opts_utils.deep_extend(obj.value, {
    ipc_client_type = 1,
    default_extra_args = {},
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
    default_delta_args = {},
    highlight_groups = {
      border_text = {
        selector_breadcrumbs = "FzfBorderSelectorBreadcrumbs",
        filetype = "FzfBorderFiletype",
        loading_indicator = "FzfBorderLoadingIndicator",
        stale_indicator = "FzfBorderStaleIndicator",
      },
    },
    focus_event_default_debounce_ms = 100,
    change_event_default_debounce_ms = 100,
  })

  return obj
end

---@param config? FzfConfig.config
function FzfConfig:setup(config)
  self.value = opts_utils.deep_extend(self.value, config)
end

return FzfConfig.new()
