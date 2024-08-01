local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfCodePreviewInstanceMixin = require("fzf.instance-mixin.code-preview")
local FzfController = require("fzf.core.controller")
local FzfLayout = require("fzf.layout")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local FzfMainPopup = require("fzf.popup").MainPopup
local FzfSidePopup = require("fzf.popup").SidePopup
local FzfOverlayPopup = require("fzf.popup").OverlayPopup
local FzfHelpPopup = require("fzf.popup").HelpPopup
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")
local NuiLayout = require("nui.layout")
local NuiText = require("nui.text")
local oop_utils = require("utils.oop")
local NuiEvent = require("nui.utils.autocmd").event

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfGrepLayout : FzfCodePreviewLayout
---@field side_popups { preview: FzfSidePopup, replacement: FzfSidePopup }
---@field overlay_popups { files_to_include: FzfOverlayPopup, files_to_exclude: FzfOverlayPopup, rg_error: FzfOverlayPopup }

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

  -- TODO: move these to instance-level config
  local files_to_include_popup = FzfOverlayPopup.new({
    toggle_keymap = "<C-i>",
  })
  local files_to_exclude_popup = FzfOverlayPopup.new({
    toggle_keymap = "<C-o>",
  })
  local rg_error_popup = FzfOverlayPopup.new({
    toggle_keymap = "<C-p>",
  })

  local help_popup = FzfHelpPopup.new({})

  main_popup.right = preview_popup
  preview_popup.left = main_popup

  replacement_popup.down = preview_popup
  preview_popup.up = replacement_popup
  replacement_popup.left = main_popup

  local layout = FzfLayout.new({
    config = obj._config,
    main_popup = main_popup,
    side_popups = {
      preview = preview_popup,
      replacement = replacement_popup,
    },
    other_overlay_popups = {
      files_to_include = files_to_include_popup,
      files_to_exclude = files_to_exclude_popup,
      rg_error = rg_error_popup,
    },
    help_popup = help_popup,
    box_fn = function()
      -- FIX: NuiPopup does not cater for removing popup from layout
      -- FIX: size is weird
      return NuiLayout.Box({
        NuiLayout.Box({
          NuiLayout.Box(main_popup, { grow = 5 }),
        }, {
          dir = "col",
          grow = main_popup.visible and 10 or 1,
        }),
        NuiLayout.Box({
          NuiLayout.Box(replacement_popup, { grow = 1 }),
          NuiLayout.Box(preview_popup, { grow = 5 }),
        }, {
          dir = "col",
          grow = preview_popup.visible and 10 or 1,
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

  -- local rg_error_indicator = main_popup.top_border_text:prepend("right")

  -- rg_error_popup:on(NuiEvent.TextChanged, function()
  --   if #rg_error_popup:get_lines() == 0 then
  --     rg_error_indicator:render("")
  --   else
  --     rg_error_indicator:render(NuiText("Error"))
  --   end
  -- end)

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
