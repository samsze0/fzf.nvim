local TUIMainPopup = require("tui.popup").MainPopup
local TUISidePopup = require("tui.popup").SidePopup
local TUIHelpPopup = require("tui.popup").HelpPopup
local opts_utils = require("utils.opts")
local FzfConfig = require("fzf.core.config")
local oop_utils = require("utils.oop")

---@class FzfMainPopup: TUIMainPopup
---@field _config FzfConfig
local FzfMainPopup = oop_utils.new_class(TUIMainPopup)

---@param opts { popup_opts?: nui_popup_options }
---@return FzfMainPopup
function FzfMainPopup.new(opts)
  opts = opts or {}

  local obj = TUIMainPopup.new({
    popup_opts = opts.popup_opts,
    config = FzfConfig,
  })
  setmetatable(obj, FzfMainPopup)
  ---@cast obj FzfMainPopup

  return obj
end

---@class FzfSidePopup: TUISidePopup
---@field _config FzfConfig
local FzfSidePopup = oop_utils.new_class(TUISidePopup)

---@param opts { popup_opts?: nui_popup_options }
---@return FzfSidePopup
function FzfSidePopup.new(opts)
  opts = opts or {}

  local obj = TUISidePopup.new({
    popup_opts = opts.popup_opts,
    config = FzfConfig,
  })
  setmetatable(obj, FzfSidePopup)
  ---@cast obj FzfSidePopup

  return obj
end

---@class FzfHelpPopup: TUIHelpPopup
---@field _config FzfConfig
local FzfHelpPopup = oop_utils.new_class(TUIHelpPopup)

---@param opts { popup_opts?: nui_popup_options }
---@return FzfHelpPopup
function FzfHelpPopup.new(opts)
  opts = opts or {}

  local obj = TUIHelpPopup.new({
    popup_opts = opts.popup_opts,
    config = FzfConfig,
  })
  setmetatable(obj, FzfHelpPopup)
  ---@cast obj FzfHelpPopup

  return obj
end

return {
  MainPopup = FzfMainPopup,
  SidePopup = FzfSidePopup,
  HelpPopup = FzfHelpPopup,
}
