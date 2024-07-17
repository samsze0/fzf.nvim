local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfCodePreviewInstanceTrait = require("fzf.instance-trait.code-preview")
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
local NuiText = require("nui.text")
local oop_utils = require("utils.oop")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfGrepLayout : FzfCodePreviewLayout
---@field side_popups { preview: FzfSidePopup, rg_error: FzfSidePopup }

---@class FzfGrepInstance : FzfController
---@field layout FzfGrepLayout
---@field _accessor? fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field _row_accessor? fun(entry: FzfEntry): number
---@field _col_accessor? fun(entry: FzfEntry): number
local GrepInstance = oop_utils.new_class(FzfController)

---@class FzfCreateGrepInstanceOptions : FzfCreateControllerOptions
---@field accessor? fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field row_accessor? fun(entry: FzfEntry): number
---@field col_accessor? fun(entry: FzfEntry): number

---@param opts? FzfCreateGrepInstanceOptions
---@return FzfGrepInstance
function GrepInstance.new(opts)
  opts = opts_utils.extend({
    accessor = function(entry) return {} end,
  }, opts)
  ---@cast opts FzfCreateGrepInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, GrepInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfGrepInstance

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
  })
  local rg_error_popup = SidePopup.new({})
  local help_popup = HelpPopup.new({})

  main_popup.right = preview_popup
  preview_popup.left = main_popup
  main_popup.down = rg_error_popup
  rg_error_popup.up = main_popup
  rg_error_popup.right = preview_popup

  local layout = Layout.new({
    config = obj._config,
    main_popup = main_popup,
    side_popups = { preview = preview_popup, rg_error = rg_error_popup },
    help_popup = help_popup,
    layout_config = function(layout)
      ---@cast layout FzfGrepLayout

      -- FIX: NuiPopup does not cater for removing popup from layout
      -- TODO: redesign this to make it more intuitive to configure
      -- FIX: rg error popup title not being shown, and size is weird
      return NuiLayout.Box({
        NuiLayout.Box({
          main_popup.should_show and NuiLayout.Box(main_popup, { grow = 50 })
            or NuiLayout.Box(main_popup, { grow = 5 }),
          rg_error_popup.should_show
              and NuiLayout.Box(rg_error_popup, { grow = 10 })
            or NuiLayout.Box(rg_error_popup, { grow = 1 }),
        }, {
          dir = "col",
          grow = (main_popup.should_show or rg_error_popup.should_show) and 10
            or 1,
        }),
        preview_popup.should_show
            and NuiLayout.Box(preview_popup, { grow = 10 })
          or NuiLayout.Box(preview_popup, { grow = 1 }),
      }, { dir = "row" })
    end,
  })
  ---@cast layout FzfGrepLayout
  obj.layout = layout

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj)

  FzfBaseInstanceTrait.setup_scroll_keymaps(obj, obj.layout.side_popups.preview)
  FzfBaseInstanceTrait.setup_main_popup_top_border(obj)

  FzfCodePreviewInstanceTrait.setup_fileopen_keymaps(obj)
  FzfCodePreviewInstanceTrait.setup_filepreview(obj)
  FzfCodePreviewInstanceTrait.setup_copy_filepath_keymap(obj)
  FzfCodePreviewInstanceTrait.setup_filetype_border_component(obj)

  local rg_error_popup_title = rg_error_popup.top_border_text:prepend("left")
  rg_error_popup_title:render(NuiText("Rg output"))

  return obj
end

return GrepInstance
