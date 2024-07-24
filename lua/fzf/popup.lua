local TUIMainPopup = require("tui.popup").MainPopup
local TUISidePopup = require("tui.popup").SidePopup
local TUIHelpPopup = require("tui.popup").HelpPopup
local TUIOverlayPopup = require("tui.popup").OverlayPopup
local opts_utils = require("utils.opts")
local FzfConfig = require("fzf.core.config")
local oop_utils = require("utils.oop")

---@class FzfMainPopup: TUIMainPopup
---@field _config FzfConfig
local FzfMainPopup = oop_utils.new_class(TUIMainPopup)

---@class FzfMainPopup.constructor.opts : TUIMainPopup.constructor.opts

---@param opts FzfMainPopup.constructor.opts
---@return FzfMainPopup
function FzfMainPopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = TUIMainPopup.new(opts)
  setmetatable(obj, FzfMainPopup)
  ---@cast obj FzfMainPopup

  return obj
end

---@class FzfSidePopup: TUISidePopup
---@field _config FzfConfig
local FzfSidePopup = oop_utils.new_class(TUISidePopup)

---@class FzfSidePopup.constructor.opts : TUISidePopup.constructor.opts

---@param opts FzfSidePopup.constructor.opts
---@return FzfSidePopup
function FzfSidePopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = TUISidePopup.new(opts)
  setmetatable(obj, FzfSidePopup)
  ---@cast obj FzfSidePopup

  return obj
end

---@class FzfOverlayPopup: TUIOverlayPopup
---@field _config FzfConfig
local FzfOverlayPopup = oop_utils.new_class(TUIOverlayPopup)

---@class FzfOverlayPopup.constructor.opts : TUIOverlayPopup.constructor.opts

---@param opts FzfOverlayPopup.constructor.opts
---@return FzfOverlayPopup
function FzfOverlayPopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = TUIOverlayPopup.new(opts)
  setmetatable(obj, FzfOverlayPopup)
  ---@cast obj FzfOverlayPopup

  return obj
end

---@class FzfHelpPopup: TUIHelpPopup
---@field _config FzfConfig
local FzfHelpPopup = oop_utils.new_class(TUIHelpPopup)

---@class FzfHelpPopup.constructor.opts : TUIHelpPopup.constructor.opts

---@param opts FzfHelpPopup.constructor.opts
---@return FzfHelpPopup
function FzfHelpPopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = TUIHelpPopup.new(opts)
  setmetatable(obj, FzfHelpPopup)
  ---@cast obj FzfHelpPopup

  return obj
end

return {
  MainPopup = FzfMainPopup,
  SidePopup = FzfSidePopup,
  OverlayPopup = FzfOverlayPopup,
  HelpPopup = FzfHelpPopup,
}
