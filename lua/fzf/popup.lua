local TUIPopup = require("tui.popup").TUI
local UnderlayPopup = require("tui.popup").Underlay
local OverlayPopup = require("tui.popup").Overlay
local HelpPopup = require("tui.popup").Help
local opts_utils = require("utils.opts")
local FzfConfig = require("fzf.core.config")
local oop_utils = require("utils.oop")

---@class FzfTUIPopup: TUITUIPopup
---@field _config FzfConfig
local FzfTUIPopup = oop_utils.new_class(TUIPopup)

---@class FzfTUIPopup.constructor.opts : TUIPopup.constructor.opts

---@param opts FzfTUIPopup.constructor.opts
---@return FzfTUIPopup
function FzfTUIPopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = TUIPopup.new(opts)
  setmetatable(obj, FzfTUIPopup)
  ---@cast obj FzfTUIPopup

  return obj
end

---@class FzfUnderlayPopup: TUIUnderlayPopup
---@field _config FzfConfig
local FzfUnderlayPopup = oop_utils.new_class(UnderlayPopup)

---@class FzfUnderlayPopup.constructor.opts : TUIUnderlayPopup.constructor.opts

---@param opts FzfUnderlayPopup.constructor.opts
---@return FzfUnderlayPopup
function FzfUnderlayPopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = UnderlayPopup.new(opts)
  setmetatable(obj, FzfUnderlayPopup)
  ---@cast obj FzfUnderlayPopup

  return obj
end

---@class FzfOverlayPopup: TUIOverlayPopup
---@field _config FzfConfig
local FzfOverlayPopup = oop_utils.new_class(OverlayPopup)

---@class FzfOverlayPopup.constructor.opts : TUIOverlayPopup.constructor.opts

---@param opts FzfOverlayPopup.constructor.opts
---@return FzfOverlayPopup
function FzfOverlayPopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = OverlayPopup.new(opts)
  setmetatable(obj, FzfOverlayPopup)
  ---@cast obj FzfOverlayPopup

  return obj
end

---@class FzfHelpPopup: TUIHelpPopup
---@field _config FzfConfig
local FzfHelpPopup = oop_utils.new_class(HelpPopup)

---@class FzfHelpPopup.constructor.opts : TUIHelpPopup.constructor.opts

---@param opts FzfHelpPopup.constructor.opts
---@return FzfHelpPopup
function FzfHelpPopup.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = HelpPopup.new(opts)
  setmetatable(obj, FzfHelpPopup)
  ---@cast obj FzfHelpPopup

  return obj
end

return {
  TUI = FzfTUIPopup,
  Underlay = FzfUnderlayPopup,
  Overlay = FzfOverlayPopup,
  Help = FzfHelpPopup,
}
