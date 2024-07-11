local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
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

---@class FzfDualPaneLuaObjectPreviewInstance : FzfController
---@field layout TUIDualPaneLayout
---@field _lua_object_accessor fun(focus: FzfEntry): string
local DualPaneLuaObjectPreviewInstance = {}
DualPaneLuaObjectPreviewInstance.__index = DualPaneLuaObjectPreviewInstance
DualPaneLuaObjectPreviewInstance.__is_class = true
setmetatable(DualPaneLuaObjectPreviewInstance, { __index = FzfController })

---@class FzfCreateDualPaneLuaObjectPreviewInstanceOptions : FzfCreateControllerOptions
---@field lua_object_accessor fun(focus: FzfEntry): string

---@param opts? FzfCreateDualPaneLuaObjectPreviewInstanceOptions
---@return FzfDualPaneLuaObjectPreviewInstance
function DualPaneLuaObjectPreviewInstance.new(opts)
  opts = opts_utils.extend({
    filepath_accessor = function(entry)
      return entry.url
    end,
  }, opts)
  ---@cast opts FzfCreateDualPaneLuaObjectPreviewInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, DualPaneLuaObjectPreviewInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfDualPaneLuaObjectPreviewInstance

  obj._lua_object_accessor = opts.lua_object_accessor

  obj.layout = DualPaneLayout.new({
    config = obj._config,
    side_popup = SidePopup.new({
      buf_options = {
        filetype = "lua"
      }
    })
  })

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj)

  FzfBaseInstanceTrait.setup_scroll_keymaps(obj, obj.layout.side_popup)
  FzfBaseInstanceTrait.setup_main_popup_top_border(obj)

  obj:_setup_lua_object_preview()

  return obj
end

function DualPaneLuaObjectPreviewInstance:_setup_lua_object_preview()
  self:on_focus(function(payload)
    self.layout.side_popup:set_lines({})

    local focus = self.focus

    if not focus then return end

    local lua_obj = self._lua_object_accessor(focus)
    self.layout.side_popup:set_lines(
      vim.split(vim.inspect(lua_obj), "\n")
    )
  end)
end

return DualPaneLuaObjectPreviewInstance
