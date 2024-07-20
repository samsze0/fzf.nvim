local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfCodeDiffInstanceMixin = require("fzf.instance-mixin.code-diff")
local FzfController = require("fzf.core.controller")
local FzfLayout = require("fzf.layout")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local MainPopup = require("fzf.popup").MainPopup
local SidePopup = require("fzf.popup").SidePopup
local HelpPopup = require("fzf.popup").HelpPopup
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

  local a_win_hl, b_win_hl = FzfCodeDiffInstanceMixin.setup_diff_highlights(obj)

  local main_popup = MainPopup.new({})
  ---@type nui_popup_options
  local side_popup_opts = {
    win_options = {
      number = true,
      cursorline = true,
    },
  }
  local a_popup = SidePopup.new({
    config = obj._config,
    popup_opts = opts_utils.deep_extend({
      win_options = {
        winhighlight = winhighlight_utils.to_str(a_win_hl),
      },
    }, side_popup_opts),
  })
  local b_popup = SidePopup.new({
    config = obj._config,
    popup_opts = opts_utils.deep_extend({
      win_options = {
        winhighlight = winhighlight_utils.to_str(b_win_hl),
      },
    }, side_popup_opts),
  })
  local help_popup = HelpPopup.new({})

  main_popup.right = a_popup
  a_popup.right = b_popup
  b_popup.left = a_popup
  a_popup.left = main_popup

  local layout = FzfLayout.new({
    config = obj._config,
    main_popup = main_popup,
    side_popups = { a = a_popup, b = b_popup },
    help_popup = help_popup,
    layout_config = function(layout)
      ---@cast layout FzfCodeDiffLayout

      -- FIX: NuiPopup does not cater for removing popup from layout
      return NuiLayout.Box({
        NuiLayout.Box(
          main_popup,
          { grow = main_popup.should_show and 10 or 1 }
        ),
        NuiLayout.Box(a_popup, { grow = a_popup.should_show and 10 or 1 }),
        NuiLayout.Box(b_popup, { grow = b_popup.should_show and 10 or 1 }),
      }, { dir = "row" })
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
