local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfController = require("fzf.core.controller")
local DualPaneLayout = require("tui.layout").DualPaneLayout
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local SidePopup = require("tui.popup").SidePopup
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfDualPaneTerminalPreviewInstance : FzfController
---@field layout TUIDualPaneLayout
local DualPaneTerminalPreviewInstance = {}
DualPaneTerminalPreviewInstance.__index = DualPaneTerminalPreviewInstance
DualPaneTerminalPreviewInstance.__is_class = true
setmetatable(DualPaneTerminalPreviewInstance, { __index = FzfController })

---@class FzfCreateDualPaneTerminalPreviewInstanceOptions : FzfCreateControllerOptions

---@param opts? FzfCreateDualPaneTerminalPreviewInstanceOptions
---@return FzfDualPaneTerminalPreviewInstance
function DualPaneTerminalPreviewInstance.new(opts)
  opts = opts_utils.extend({
    filepath_accessor = function(entry)
      return entry.url
    end,
  }, opts)
  ---@cast opts FzfCreateDualPaneTerminalPreviewInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, DualPaneTerminalPreviewInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfDualPaneTerminalPreviewInstance

  obj.layout = DualPaneLayout.new({
    config = obj._config,
    side_popup = SidePopup.new({
      buf_options = {
        filetype = "terminal",
        synmaxcol = 0,
      },
      win_options = {
        number = true,
        conceallevel = 3,
        concealcursor = "nvic",
      },
    })
  })

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj)

  FzfBaseInstanceTrait.setup_scroll_keymaps(obj, obj.layout.side_popup)
  FzfBaseInstanceTrait.setup_main_popup_top_border(obj)

  return obj
end

return DualPaneTerminalPreviewInstance
