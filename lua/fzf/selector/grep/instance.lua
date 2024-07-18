local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfCodePreviewInstanceMixin = require("fzf.instance-mixin.code-preview")
local FzfController = require("fzf.core.controller")
local FzfLayout = require("fzf.layout")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local FzfMainPopup = require("fzf.popup").MainPopup
local FzfSidePopup = require("fzf.popup").SidePopup
local FzfHelpPopup = require("fzf.popup").HelpPopup
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
---@field side_popups { preview: FzfSidePopup, rg_error: FzfSidePopup, replacement: FzfSidePopup, files_to_include: FzfSidePopup, files_to_exclude: FzfSidePopup }

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

  local main_popup = FzfMainPopup.new({})
  local preview_popup = FzfSidePopup.new({
    popup_opts = {
      win_options = {
        number = true,
        cursorline = true,
      },
    },
  })
  local replacement_popup = FzfSidePopup.new({})
  local files_to_include_popup = FzfSidePopup.new({})
  local files_to_exclude_popup = FzfSidePopup.new({})
  local rg_error_popup = FzfSidePopup.new({})
  local help_popup = FzfHelpPopup.new({})

  main_popup.right = preview_popup
  preview_popup.left = main_popup

  main_popup.down = files_to_include_popup
  files_to_include_popup.up = main_popup
  files_to_include_popup.right = preview_popup

  files_to_include_popup.down = files_to_exclude_popup
  files_to_exclude_popup.up = files_to_include_popup
  files_to_exclude_popup.right = preview_popup

  files_to_exclude_popup.down = rg_error_popup
  rg_error_popup.up = files_to_exclude_popup
  rg_error_popup.right = preview_popup

  replacement_popup.down = preview_popup
  preview_popup.up = replacement_popup
  replacement_popup.left = main_popup

  local layout = FzfLayout.new({
    config = obj._config,
    main_popup = main_popup,
    side_popups = {
      preview = preview_popup,
      rg_error = rg_error_popup,
      replacement = replacement_popup,
      files_to_include = files_to_include_popup,
      files_to_exclude = files_to_exclude_popup,
    },
    help_popup = help_popup,
    layout_config = function(layout)
      ---@cast layout FzfGrepLayout

      -- FIX: NuiPopup does not cater for removing popup from layout
      -- FIX: size is weird
      return NuiLayout.Box({
        NuiLayout.Box({
          NuiLayout.Box(main_popup, { grow = 5 }),
          NuiLayout.Box(files_to_include_popup, { grow = 1 }),
          NuiLayout.Box(files_to_exclude_popup, { grow = 1 }),
          NuiLayout.Box(rg_error_popup, { grow = 1 }),
        }, {
          dir = "col",
          grow = main_popup.should_show and 10 or 1,
        }),
        NuiLayout.Box({
          NuiLayout.Box(replacement_popup, { grow = 1 }),
          NuiLayout.Box(preview_popup, { grow = 5 }),
        }, {
          dir = "col",
          grow = preview_popup.should_show and 10 or 1,
        }),
      }, { dir = "row" })
    end,
  })
  ---@cast layout FzfGrepLayout
  obj.layout = layout

  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) ---@diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_scroll_keymaps(obj, obj.layout.side_popups.preview) ---@diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_close_keymaps(obj) ---@diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceMixin.setup_main_popup_top_border(obj) ---@diagnostic disable-line: param-type-mismatch

  FzfCodePreviewInstanceMixin.setup_fileopen_keymaps(obj) ---@diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_filepreview(obj) ---@diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_copy_filepath_keymap(obj) ---@diagnostic disable-line: param-type-mismatch
  FzfCodePreviewInstanceMixin.setup_filetype_border_component(obj) ---@diagnostic disable-line: param-type-mismatch

  local rg_error_popup_title = rg_error_popup.top_border_text:prepend("left")
  rg_error_popup_title:render(NuiText("Rg output"))

  local files_to_include_popup_title =
    files_to_include_popup.top_border_text:prepend("left")
  files_to_include_popup_title:render(NuiText("Files to include"))

  local files_to_exclude_popup_title =
    files_to_exclude_popup.top_border_text:prepend("left")
  files_to_exclude_popup_title:render(NuiText("Files to exclude"))

  local replacement_popup_title =
    replacement_popup.top_border_text:prepend("left")
  replacement_popup_title:render(NuiText("Replacement"))

  return obj
end

return GrepInstance
