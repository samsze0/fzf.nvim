local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfCodePreviewInstanceTrait = require("fzf.instance-trait.code-preview")
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
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfDualPaneNvimPreviewInstance : FzfController
---@field layout FzfCodePreviewLayout
---@field _accessor? FzfCodePreviewInstanceTrait.accessor
---@field _row_accessor? FzfCodePreviewInstanceTrait.row_accessor
---@field _col_accessor? FzfCodePreviewInstanceTrait.col_accessor
local DualPaneNvimPreviewInstance = oop_utils.new_class(FzfController)

---@class FzfCreateDualPaneNvimPreviewInstanceOptions : FzfCreateControllerOptions
---@field accessor? FzfCodePreviewInstanceTrait.accessor
---@field row_accessor? FzfCodePreviewInstanceTrait.row_accessor
---@field col_accessor? FzfCodePreviewInstanceTrait.col_accessor

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
  ---@cast layout FzfCodePreviewLayout
  obj.layout = layout

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceTrait.setup_scroll_keymaps(obj, obj.layout.side_popups.preview) --- @diagnostic disable-line: param-type-mismatch
  FzfBaseInstanceTrait.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfCodePreviewInstanceTrait.setup_fileopen_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceTrait.setup_filepreview(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceTrait.setup_copy_filepath_keymap(obj) --- @diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceTrait.setup_filetype_border_component(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

return DualPaneNvimPreviewInstance
