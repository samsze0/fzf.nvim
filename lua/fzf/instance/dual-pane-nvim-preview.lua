local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfCodePreviewInstanceTrait = require("fzf.instance-trait.code-preview")
local FzfController = require("fzf.core.controller")
local DualPaneLayout = require("tui.layout").DualPaneLayout
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local MainPopup = require("tui.popup").MainPopup
local SidePopup = require("tui.popup").SidePopup
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfDualPaneNvimPreviewInstance : FzfController
---@field layout TUIDualPaneLayout
---@field _filepath_accessor? fun(entry: FzfEntry): string
---@field _content_accessor fun(entry: FzfEntry): string[]
---@field _row_accessor? fun(entry: FzfEntry): number
---@field _col_accessor? fun(entry: FzfEntry): number
local DualPaneNvimPreviewInstance = {}
DualPaneNvimPreviewInstance.__index = DualPaneNvimPreviewInstance
DualPaneNvimPreviewInstance.__is_class = true
setmetatable(DualPaneNvimPreviewInstance, { __index = FzfController })

---@class FzfCreateDualPaneNvimPreviewInstanceOptions : FzfCreateControllerOptions
---@field filepath_accessor? fun(entry: FzfEntry): string
---@field content_accessor? fun(entry: FzfEntry): string[]
---@field row_accessor? fun(entry: FzfEntry): number
---@field col_accessor? fun(entry: FzfEntry): number

---@param opts? FzfCreateDualPaneNvimPreviewInstanceOptions
---@return FzfDualPaneNvimPreviewInstance
function DualPaneNvimPreviewInstance.new(opts)
  opts = opts_utils.extend({
    filepath_accessor = function(entry)
      return entry.url
    end,
  }, opts)
  ---@cast opts FzfCreateDualPaneNvimPreviewInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, DualPaneNvimPreviewInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfDualPaneNvimPreviewInstance

  obj._filepath_accessor = opts.filepath_accessor
  obj._content_accessor = opts.content_accessor
  obj._row_accessor = opts.row_accessor
  obj._col_accessor = opts.col_accessor

  obj.layout = DualPaneLayout.new({
    config = obj._config,
    side_popup = SidePopup.new({
      win_options = {
        number = true,
        cursorline = true,
      },
    })
  })

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj)

  FzfBaseInstanceTrait.setup_scroll_keymaps(obj, obj.layout.side_popup)
  FzfBaseInstanceTrait.setup_main_popup_top_border(obj)

  FzfCodePreviewInstanceTrait.setup_fileopen_keymaps(obj)
  FzfCodePreviewInstanceTrait.setup_filepreview(obj)
  FzfCodePreviewInstanceTrait.setup_copy_filepath_keymap(obj)

  return obj
end

return DualPaneNvimPreviewInstance
