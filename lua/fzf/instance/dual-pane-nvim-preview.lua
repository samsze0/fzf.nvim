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
---@field main_popup FzfTUIPopup
---@field preview_popup FzfUnderlayPopup
---@field main_popup_settings TUIUnderlayPopupInfo
---@field preview_popup_settings TUIUnderlayPopupInfo
local DualPaneNvimPreviewInstance = oop_utils.new_class(FzfController)

---@class FzfCreateDualPaneNvimPreviewInstanceOptions : FzfCreateControllerOptions
---@field accessor? FzfCodePreviewInstanceMixin.accessor
---@field row_accessor? FzfCodePreviewInstanceMixin.row_accessor
---@field col_accessor? FzfCodePreviewInstanceMixin.col_accessor
---@field main_popup_opts? FzfTUIPopup.constructor.opts
---@field preview_popup_opts? FzfUnderlayPopup.constructor.opts
---@field main_popup_settings? TUIUnderlayPopupInfo
---@field preview_popup_settings? TUIUnderlayPopupInfo
---@field extra_underlay_popups? table<string, FzfTUIPopup | FzfUnderlayPopup>
---@field extra_underlay_popups_settings? table<string, TUIUnderlayPopupInfo>
---@field extra_overlay_popups? table<string, FzfOverlayPopup>
---@field extra_overlay_popups_settings? table<string, TUIOverlayPopupInfo>
---@field box_fn? fun(): NuiLayout.Box

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

  local main_popup = MainPopup.new(opts_utils.deep_extend({
    nui_popup_opts = {
      win_options = {
        number = true,
        cursorline = true,
      },
    },
  }, opts.main_popup_opts))
  obj.main_popup = main_popup

  local preview_popup = UnderlayPopup.new(opts_utils.deep_extend({
    nui_popup_opts = {
      win_options = {
        number = true,
        cursorline = true,
      },
    },
    config = obj._config,
  }, opts.preview_popup_opts))
  obj.preview_popup = preview_popup

  local main_popup_settings = UnderlayPopupSettings.new(opts_utils.deep_extend({
    right = preview_popup,
  }, opts.main_popup_settings))
  obj.main_popup_settings = main_popup_settings

  local preview_popup_settings = UnderlayPopupSettings.new(opts_utils.deep_extend({
    left = main_popup,
  }, opts.preview_popup_settings))
  obj.preview_popup_settings = preview_popup_settings

  local layout = FzfLayout.new({
    config = obj._config,
    underlay_popups = opts_utils.extend({
      main = main_popup,
      preview = preview_popup,
    }, opts.extra_underlay_popups),
    underlay_popups_settings = opts_utils.extend({
      main = main_popup_settings,
      preview = preview_popup_settings,
    }, opts.extra_underlay_popups_settings),
    overlay_popups = opts.extra_overlay_popups,
    overlay_popups_settings = opts.extra_overlay_popups_settings,
    box_fn = opts.box_fn or function()
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

---@param accessor FzfCodePreviewInstanceMixin.accessor
function DualPaneNvimPreviewInstance:set_accessor(accessor)
  self._accessor = accessor
end

---@param row_accessor FzfCodePreviewInstanceMixin.row_accessor
function DualPaneNvimPreviewInstance:set_row_accessor(row_accessor)
  self._row_accessor = row_accessor
end

---@param col_accessor FzfCodePreviewInstanceMixin.col_accessor
function DualPaneNvimPreviewInstance:set_col_accessor(col_accessor)
  self._col_accessor = col_accessor
end

return DualPaneNvimPreviewInstance
