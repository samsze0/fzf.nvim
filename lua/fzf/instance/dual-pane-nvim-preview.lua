local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfCodePreviewInstanceMixin = require("fzf.instance-mixin.code-preview")
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
  local preview_popup = SidePopup.new({
    popup_opts = {
      win_options = {
        number = true,
        cursorline = true,
      },
    },
    config = obj._config,
  })
  local help_popup = HelpPopup.new({})

  main_popup.right = preview_popup
  preview_popup.left = main_popup

  local layout = FzfLayout.new({
    config = obj._config,
    main_popup = main_popup,
    side_popups = { preview = preview_popup },
    help_popup = help_popup,
    layout_config = function(layout)
      ---@cast layout FzfCodePreviewLayout

      -- FIX: NuiPopup does not cater for removing popup from layout
      return NuiLayout.Box({
        NuiLayout.Box(
          main_popup,
          { grow = main_popup.should_show and 10 or 1 }
        ),
        NuiLayout.Box(
          preview_popup,
          { grow = preview_popup.should_show and 10 or 1 }
        ),
      }, { dir = "row" })
    end,
  })
  ---@cast layout FzfCodePreviewLayout
  obj.layout = layout

  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_scroll_keymaps(obj, obj.layout.side_popups.preview) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_close_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceMixin.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfCodePreviewInstanceMixin.setup_fileopen_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_filepreview(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_copy_filepath_keymap(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_filetype_border_component(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

return DualPaneNvimPreviewInstance
