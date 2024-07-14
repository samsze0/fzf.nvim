local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local FzfCodeDiffInstanceTrait = require("fzf.instance-trait.code-diff")
local FzfController = require("fzf.core.controller")
local TriplePaneLayout = require("tui.layout").TriplePaneLayout
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local SidePopup = require("tui.popup").SidePopup
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")
local winhighlight_utils = require("utils.winhighlight")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfTriplePaneCodeDiffInstance : FzfController
---@field layout TUITriplePaneLayout
---@field _a_accessor fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field _b_accessor fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field _picker fun(entry: FzfEntry): ("a" | "b")
local TriplePaneCodeDiffInstance = {}
TriplePaneCodeDiffInstance.__index = TriplePaneCodeDiffInstance
TriplePaneCodeDiffInstance.__is_class = true
setmetatable(TriplePaneCodeDiffInstance, { __index = FzfController })

---@class FzfCreateTriplePaneCodeDiffInstanceOptions : FzfCreateControllerOptions
---@field a_accessor? fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field b_accessor? fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field picker? fun(entry: FzfEntry): ("a" | "b")

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

  ---@type nui_popup_opts
  local side_popup_opts = {
    win_options = {
      number = true,
      cursorline = true,
    },
  }

  obj.layout = TriplePaneLayout.new({
    config = obj._config,
    side_popups = {
      left = SidePopup.new({
        config = obj._config,
        popup_opts = opts_utils.deep_extend({
          win_options = {
            winhighlight = winhighlight_utils.to_str(a_win_hl),
          }
        }, side_popup_opts),
      }),
      right = SidePopup.new({
        config = obj._config,
        popup_opts = opts_utils.deep_extend({
          win_options = {
            winhighlight = winhighlight_utils.to_str(b_win_hl),
          }
        }, side_popup_opts),
      }),
    },
  })

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj)

  FzfBaseInstanceTrait.setup_main_popup_top_border(obj)
  FzfBaseInstanceTrait.setup_maximise_popup_keymaps(obj)

  FzfCodeDiffInstanceTrait.setup_fileopen_keymaps(obj)
  FzfCodeDiffInstanceTrait.setup_filepreview(obj)
  FzfCodeDiffInstanceTrait.setup_copy_filepath_keymap(obj)

  return obj
end

return TriplePaneCodeDiffInstance
