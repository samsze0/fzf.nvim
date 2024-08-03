local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfCodePreviewInstanceMixin = require("fzf.instance-mixin.code-preview")
local FzfController = require("fzf.core.controller")
local FzfLayout = require("fzf.layout")
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

---@class FzfDualPaneNvimPreviewInstance : FzfController
---@field layout FzfCodePreviewLayout
---@field _accessor? FzfCodePreviewInstanceMixin.accessor
---@field _row_accessor? FzfCodePreviewInstanceMixin.row_accessor
---@field _col_accessor? FzfCodePreviewInstanceMixin.col_accessor
local DualPaneNvimPreviewInstance = oop_utils.new_class(FzfController)

---@class FzfCreateDualPaneNvimPreviewInstanceOptions : FzfCreateControllerOptions
---@field accessor? FzfCodePreviewInstanceMixin.accessor
---@field row_accessor? FzfCodePreviewInstanceMixin.row_accessor
---@field col_accessor? FzfCodePreviewInstanceMixin.col_accessor

---@param opts? FzfCreateDualPaneNvimPreviewInstanceOptions
---@return FzfDualPaneNvimPreviewInstance
function DualPaneNvimPreviewInstance.new(opts)
  opts = opts_utils.extend({
    accessor = function(entry) return {} end,
  }, opts)
  ---@cast opts FzfCreateDualPaneNvimPreviewInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, DualPaneNvimPreviewInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfDualPaneNvimPreviewInstance

  obj._accessor = opts.accessor
  obj._row_accessor = opts.row_accessor
  obj._col_accessor = opts.col_accessor

  local main_popup = MainPopup.new({})
  local preview_popup = UnderlayPopup.new({
    nui_popup_opts = {
      win_options = {
        number = true,
        cursorline = true,
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

  local layout = FzfLayout.new({
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
  ---@cast layout FzfCodePreviewLayout
  obj.layout = layout

  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_scroll_keymaps(obj, preview_popup) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_close_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceMixin.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfCodePreviewInstanceMixin.setup_fileopen_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_filepreview(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_copy_filepath_keymap(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_filetype_border_component(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

return DualPaneNvimPreviewInstance
