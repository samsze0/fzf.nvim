local MainPopup = require("tui.popup").MainPopup
local SidePopup = require("tui.popup").SidePopup
local HelpPopup = require("tui.popup").HelpPopup
local opts_utils = require("utils.opts")
local Config = require("fzf.core.config")

---@class FzfMainPopup: TUIMainPopup
---@field _config FzfConfig
local FzfMainPopup = {}
FzfMainPopup.__index = FzfMainPopup
FzfMainPopup.__is_class = true
setmetatable(FzfMainPopup, { __index = MainPopup })

---@param opts { popup_opts?: nui_popup_options }
---@return FzfMainPopup
function FzfMainPopup.new(opts)
  opts = opts or {}

  local obj = MainPopup.new({
    popup_opts = opts.popup_opts,
    config = Config,
  })
  setmetatable(obj, FzfMainPopup)
  ---@cast obj FzfMainPopup

  return obj
end

---@class FzfSidePopup: TUISidePopup
---@field _config FzfConfig
local FzfSidePopup = {}
FzfSidePopup.__index = FzfSidePopup
FzfSidePopup.__is_class = true
setmetatable(FzfSidePopup, { __index = SidePopup })

---@param opts { popup_opts?: nui_popup_options }
---@return FzfSidePopup
function FzfSidePopup.new(opts)
  opts = opts or {}

  local obj = SidePopup.new({
    popup_opts = opts.popup_opts,
    config = Config,
  })
  setmetatable(obj, FzfSidePopup)
  ---@cast obj FzfSidePopup

  return obj
end

---@class FzfHelpPopup: TUIHelpPopup
---@field _config FzfConfig
local FzfHelpPopup = {}
FzfHelpPopup.__index = FzfHelpPopup
FzfHelpPopup.__is_class = true
setmetatable(FzfHelpPopup, { __index = HelpPopup })

---@param opts { popup_opts?: nui_popup_options }
---@return FzfHelpPopup
function FzfHelpPopup.new(opts)
  opts = opts or {}

  local obj = HelpPopup.new({
    popup_opts = opts.popup_opts,
    config = Config,
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
