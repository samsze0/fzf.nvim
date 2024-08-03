local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfController = require("fzf.core.controller")
local Layout = require("fzf.layout")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local MainPopup = require("fzf.popup").TUI
local UnderlayPopup = require("fzf.popup").Underlay
local UnderlayPopupSettings = require("tui.layout").UnderlayPopupSettings
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")
local NuiLayout = require("nui.layout")
local oop_utils = require("utils.oop")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfTerminalPreviewLayout : FzfLayout
---@field underlay_popups { main: FzfTUIPopup, preview: FzfUnderlayPopup }

---@class FzfDualPaneTerminalPreviewInstance : FzfController
---@field layout FzfTerminalPreviewLayout
local DualPaneTerminalPreviewInstance = oop_utils.new_class(FzfController)

---@class FzfCreateDualPaneTerminalPreviewInstanceOptions : FzfCreateControllerOptions

---@param opts? FzfCreateDualPaneTerminalPreviewInstanceOptions
---@return FzfDualPaneTerminalPreviewInstance
function DualPaneTerminalPreviewInstance.new(opts)
  opts = opts_utils.extend({
    filepath_accessor = function(entry) return entry.url end,
  }, opts)
  ---@cast opts FzfCreateDualPaneTerminalPreviewInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, DualPaneTerminalPreviewInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfDualPaneTerminalPreviewInstance

  local main_popup = MainPopup.new({})
  local preview_popup = UnderlayPopup.new({
    nui_popup_opts = {
      buf_options = {
        filetype = "terminal",
        synmaxcol = 0,
      },
      win_options = {
        number = false,
        conceallevel = 3,
        concealcursor = "nvic",
      },
    },
    config = obj._config,
  })

  local main_popup_settings = UnderlayPopupSettings.new({
    right = preview_popup,
  })
  local preview_popup_settings = UnderlayPopupSettings.new({
    left = main_popup,
  })

  local layout = Layout.new({
    config = obj._config,
    underlay_popups = { main = main_popup, preview = preview_popup },
    underlay_popups_settings = {
      main = main_popup_settings,
      preview = preview_popup_settings,
    },
    box_fn = function()
      -- FIX: NuiPopup does not cater for removing popup from layout
      return NuiLayout.Box(
        tbl_utils.non_false({
          main_popup_settings.visible
              and NuiLayout.Box(main_popup:get_nui_popup(), { grow = 1 })
            or false,
          preview_popup_settings.visible
              and NuiLayout.Box(preview_popup:get_nui_popup(), { grow = 1 })
            or false,
        }),
        { dir = "row" }
      )
    end,
  })
  ---@cast layout FzfTerminalPreviewLayout
  obj.layout = layout

  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_scroll_keymaps(obj, preview_popup) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_close_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceMixin.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

return DualPaneTerminalPreviewInstance
