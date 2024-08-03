local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfCodeDiffInstanceMixin = require("fzf.instance-mixin.code-diff")
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
local winhighlight_utils = require("utils.winhighlight")
local NuiLayout = require("nui.layout")
local oop_utils = require("utils.oop")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfTriplePaneCodeDiffInstance : FzfController
---@field layout FzfCodeDiffLayout
---@field _a_accessor FzfCodeDiffInstanceMixin.accessor
---@field _b_accessor FzfCodeDiffInstanceMixin.accessor
---@field _picker FzfCodeDiffInstanceMixin.picker
local TriplePaneCodeDiffInstance = oop_utils.new_class(FzfController)

---@class FzfCreateTriplePaneCodeDiffInstanceOptions : FzfCreateControllerOptions
---@field a_accessor? FzfCodeDiffInstanceMixin.accessor
---@field b_accessor? FzfCodeDiffInstanceMixin.accessor
---@field picker? FzfCodeDiffInstanceMixin.picker

---@param opts? FzfCreateTriplePaneCodeDiffInstanceOptions
---@return FzfTriplePaneCodeDiffInstance
function TriplePaneCodeDiffInstance.new(opts)
  opts = opts_utils.extend({
    picker = function(entry) return "a" end,
    a_accessor = function(entry) return {} end,
    b_accessor = function(entry) return {} end,
  }, opts)
  ---@cast opts FzfCreateTriplePaneCodeDiffInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, TriplePaneCodeDiffInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfTriplePaneCodeDiffInstance

  obj._a_accessor = opts.a_accessor
  obj._b_accessor = opts.b_accessor
  obj._picker = opts.picker

  local a_win_hl, b_win_hl = FzfCodeDiffInstanceMixin.setup_diff_highlights(obj) ---@diagnostic disable-line: param-type-mismatch

  local main_popup = MainPopup.new({})
  ---@type nui_popup_options
  local side_popup_opts = {
    win_options = {
      number = true,
      cursorline = true,
    },
  }
  local a_popup = UnderlayPopup.new({
    config = obj._config,
    nui_popup_opts = opts_utils.deep_extend({
      win_options = {
        winhighlight = winhighlight_utils.to_str(a_win_hl),
      },
    }, side_popup_opts),
  })
  local b_popup = UnderlayPopup.new({
    config = obj._config,
    nui_popup_opts = opts_utils.deep_extend({
      win_options = {
        winhighlight = winhighlight_utils.to_str(b_win_hl),
      },
    }, side_popup_opts),
  })

  local main_popup_settings = UnderlayPopupSettings.new({
    right = a_popup,
  })
  local a_popup_settings = UnderlayPopupSettings.new({
    left = main_popup,
    right = b_popup,
  })
  local b_popup_settings = UnderlayPopupSettings.new({
    left = a_popup,
  })

  local layout = FzfLayout.new({
    config = obj._config,
    underlay_popups = { main = main_popup, a = a_popup, b = b_popup },
    underlay_popups_settings = {
      main = main_popup_settings,
      a = a_popup_settings,
      b = b_popup_settings,
    },
    box_fn = function()
      -- FIX: NuiPopup does not cater for removing popup from layout
      return NuiLayout.Box(
        tbl_utils.non_false({
          main_popup_settings.visible
              and NuiLayout.Box(main_popup:get_nui_popup(), { grow = 1 })
            or false,
          a_popup_settings.visible
              and NuiLayout.Box(a_popup:get_nui_popup(), { grow = 1 })
            or false,
          b_popup_settings.visible
              and NuiLayout.Box(b_popup:get_nui_popup(), { grow = 1 })
            or false,
        }),
        { dir = "row" }
      )
    end,
  })
  ---@cast layout FzfCodeDiffLayout
  obj.layout = layout

  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_close_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceMixin.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfCodeDiffInstanceMixin.setup_fileopen_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodeDiffInstanceMixin.setup_filepreview(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodeDiffInstanceMixin.setup_copy_filepath_keymap(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

return TriplePaneCodeDiffInstance
