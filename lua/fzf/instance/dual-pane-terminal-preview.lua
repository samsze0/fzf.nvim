local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfController = require("fzf.core.controller")
local Layout = require("tui.layout")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local MainPopup = require("fzf.popup").MainPopup
local SidePopup = require("fzf.popup").SidePopup
local HelpPopup = require("fzf.popup").HelpPopup
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")
local NuiLayout = require("nui.layout")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfTerminalPreviewLayout : TUILayout
---@field side_popups { preview: TUISidePopup }

---@class FzfDualPaneTerminalPreviewInstance : FzfController
---@field layout FzfTerminalPreviewLayout
local DualPaneTerminalPreviewInstance = {}
DualPaneTerminalPreviewInstance.__index = DualPaneTerminalPreviewInstance
DualPaneTerminalPreviewInstance.__is_class = true
setmetatable(DualPaneTerminalPreviewInstance, { __index = FzfController })

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
    layout_config = function(layout)
      ---@cast layout FzfTerminalPreviewLayout

      return NuiLayout.Box(
        tbl_utils.non_falsey({
          main_popup.should_show and NuiLayout.Box(main_popup, { grow = 10 })
            or NuiLayout.Box(main_popup, { grow = 1 }),
          preview_popup.should_show
              and NuiLayout.Box(preview_popup, { grow = 10 })
            or NuiLayout.Box(preview_popup, { grow = 1 }),
        }),
        { dir = "row" }
      )
    end,
  })
  ---@cast layout FzfTerminalPreviewLayout
  obj.layout = layout

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj)

  FzfBaseInstanceTrait.setup_scroll_keymaps(obj, obj.layout.side_popups.preview)
  FzfBaseInstanceTrait.setup_main_popup_top_border(obj)

  return obj
end

return DualPaneTerminalPreviewInstance
