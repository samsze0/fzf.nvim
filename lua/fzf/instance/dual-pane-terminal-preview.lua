local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfController = require("fzf.core.controller")
local Layout = require("fzf.layout")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local MainPopup = require("fzf.popup").MainPopup
local SidePopup = require("fzf.popup").SidePopup
local HelpPopup = require("fzf.popup").HelpPopup
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
---@field side_popups { preview: FzfSidePopup }

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
  local preview_popup = SidePopup.new({
    popup_opts = {
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
  local help_popup = HelpPopup.new({})

  main_popup.right = preview_popup
  preview_popup.left = main_popup

  local layout = Layout.new({
    config = obj._config,
    main_popup = main_popup,
    side_popups = { preview = preview_popup },
    help_popup = help_popup,
    box_fn = function()
      -- FIX: NuiPopup does not cater for removing popup from layout
      return NuiLayout.Box({
        NuiLayout.Box(main_popup, { grow = main_popup.visible and 10 or 1 }),
        NuiLayout.Box(
          preview_popup,
          { grow = preview_popup.visible and 10 or 1 }
        ),
      }, { dir = "row" })
    end,
  })
  ---@cast layout FzfTerminalPreviewLayout
  obj.layout = layout

  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_scroll_keymaps(obj, obj.layout.side_popups.preview) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_close_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceMixin.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

return DualPaneTerminalPreviewInstance
