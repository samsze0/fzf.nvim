local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfCodeDiffInstanceTrait = require("fzf.instance-trait.code-diff")
local FzfController = require("fzf.core.controller")
local DualPaneLayout = require("tui.layout").DualPaneLayout
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local SidePopup = require("tui.popup").SidePopup
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfTriplePaneCodeDiffInstance : FzfController
---@field layout TUIDualPaneLayout
---@field _a_filepath_accessor? fun(entry: FzfEntry): string
---@field _b_filepath_accessor? fun(entry: FzfEntry): string
---@field _a_content_accessor? fun(entry: FzfEntry): string[]
---@field _b_content_accessor? fun(entry: FzfEntry): string[]
---@field _picker fun(entry: FzfEntry): ("a" | "b")
local TriplePaneCodeDiffInstance = {}
TriplePaneCodeDiffInstance.__index = TriplePaneCodeDiffInstance
TriplePaneCodeDiffInstance.__is_class = true
setmetatable(TriplePaneCodeDiffInstance, { __index = FzfController })

---@class FzfCreateTriplePaneCodeDiffInstanceOptions : FzfCreateControllerOptions
---@field a_filepath_accessor? fun(entry: FzfEntry): string
---@field b_filepath_accessor? fun(entry: FzfEntry): string
---@field a_content_accessor? fun(entry: FzfEntry): string[]
---@field b_content_accessor? fun(entry: FzfEntry): string[]
---@field picker fun(entry: FzfEntry): ("a" | "b")

---@param opts? FzfCreateTriplePaneCodeDiffInstanceOptions
---@return FzfTriplePaneCodeDiffInstance
function TriplePaneCodeDiffInstance.new(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfCreateTriplePaneCodeDiffInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, TriplePaneCodeDiffInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfTriplePaneCodeDiffInstance

  obj._a_filepath_accessor = opts.a_filepath_accessor
  obj._b_filepath_accessor = opts.b_filepath_accessor
  obj._a_content_accessor = opts.a_content_accessor
  obj._b_content_accessor = opts.b_content_accessor

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

  FzfCodeDiffInstanceTrait.setup_fileopen_keymaps(obj)
  FzfCodeDiffInstanceTrait.setup_filepreview(obj)
  FzfCodeDiffInstanceTrait.setup_copy_filepath_keymap(obj)
  FzfCodeDiffInstanceTrait.setup_vimdiff(obj)

  return obj
end

return TriplePaneCodeDiffInstance
