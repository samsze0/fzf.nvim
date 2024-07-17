local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfCodeDiffInstanceTrait = require("fzf.instance-trait.code-diff")
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
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfTriplePaneCodeDiffInstance : FzfController
---@field layout FzfCodeDiffLayout
---@field _a_accessor FzfCodeDiffInstanceTrait.accessor
---@field _b_accessor FzfCodeDiffInstanceTrait.accessor
---@field _picker FzfCodeDiffInstanceTrait.picker
local TriplePaneCodeDiffInstance = oop_utils.new_class(FzfController)

---@class FzfCreateTriplePaneCodeDiffInstanceOptions : FzfCreateControllerOptions
---@field a_accessor? FzfCodeDiffInstanceTrait.accessor
---@field b_accessor? FzfCodeDiffInstanceTrait.accessor
---@field picker? FzfCodeDiffInstanceTrait.picker

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

  local a_win_hl, b_win_hl = FzfCodeDiffInstanceTrait.setup_diff_highlights(obj)

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
      return NuiLayout.Box(
        tbl_utils.non_falsey({
          main_popup.should_show and NuiLayout.Box(main_popup, { grow = 10 })
            or NuiLayout.Box(main_popup, { grow = 1 }),
          a_popup.should_show and NuiLayout.Box(a_popup, { grow = 10 })
            or NuiLayout.Box(a_popup, { grow = 1 }),
          b_popup.should_show and NuiLayout.Box(b_popup, { grow = 10 })
            or NuiLayout.Box(b_popup, { grow = 1 }),
        }),
        { dir = "row" }
      )
    end,
  })
  ---@cast layout FzfCodeDiffLayout
  obj.layout = layout

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceTrait.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfCodeDiffInstanceTrait.setup_fileopen_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodeDiffInstanceTrait.setup_filepreview(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodeDiffInstanceTrait.setup_copy_filepath_keymap(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

return TriplePaneCodeDiffInstance
