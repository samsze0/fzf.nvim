local TUILayout = require("tui.layout").Layout
local opts_utils = require("utils.opts")
local FzfConfig = require("fzf.core.config")
local oop_utils = require("utils.oop")

---@class FzfLayout: TUILayout
---@field _config FzfConfig
---@field underlay_popups { main: FzfTUIPopup }
local FzfLayout = oop_utils.new_class(TUILayout)

---@class FzfLayout.constructor.opts : TUILayout.constructor.opts

---@param opts FzfLayout.constructor.opts
---@return FzfLayout
function FzfLayout.new(opts)
  opts = opts_utils.extend({
    config = FzfConfig,
  }, opts)

  local obj = TUILayout.new(opts)
  setmetatable(obj, FzfLayout)
  ---@cast obj FzfLayout

  return obj
end

return FzfLayout
