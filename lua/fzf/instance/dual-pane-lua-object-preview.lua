local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
local FzfController = require("fzf.core.controller")
local FzfLayout = require("fzf.layout")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local MainPopup = require("fzf.popup").TUI
local UnderlayPopup = require("fzf.popup").Underlay
local UnderlayPopupSettings = require("tui.layout").UnderlayPopupSettings
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

---@alias FzfDualPaneLuaObjectPreviewInstance.accessor fun(focus: FzfEntry): any

---@class FzfDualPaneLuaObjectPreviewInstance : FzfController
---@field layout FzfCodePreviewLayout
---@field _accessor FzfDualPaneLuaObjectPreviewInstance.accessor
local DualPaneLuaObjectPreviewInstance = oop_utils.new_class(FzfController)

---@class FzfCreateDualPaneLuaObjectPreviewInstanceOptions : FzfCreateControllerOptions
---@field accessor? FzfDualPaneLuaObjectPreviewInstance.accessor

---@param opts? FzfCreateDualPaneLuaObjectPreviewInstanceOptions
---@return FzfDualPaneLuaObjectPreviewInstance
function DualPaneLuaObjectPreviewInstance.new(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfCreateDualPaneLuaObjectPreviewInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, DualPaneLuaObjectPreviewInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfDualPaneLuaObjectPreviewInstance

  obj._accessor = opts.accessor

  local main_popup = MainPopup.new({})
  local preview_popup = UnderlayPopup.new({
    nui_popup_opts = {
      buf_options = {
        filetype = "lua",
      },
    },
    config = obj._config,
  })

  local main_popup_settings = UnderlayPopupSettings.new({
    right = preview_popup,
  })
  local preview_popup_settings = UnderlayPopupSettings.new({
    left = main_popup,
  })

  local layout = FzfLayout.new({
    config = obj._config,
    underlay_popups = { main = main_popup, preview = preview_popup },
    underlay_popups_settings = {
      main = main_popup_settings,
      preview = preview_popup_settings,
    },
    box_fn = function()
      -- FIX: NuiPopup does not cater for removing popup from layout
      return NuiLayout.Box(
        tbl_utils.non_false({
          main_popup_settings.visible
              and NuiLayout.Box(main_popup:get_nui_popup(), { grow = 1 })
            or false,
          preview_popup_settings.visible
              and NuiLayout.Box(preview_popup:get_nui_popup(), { grow = 1 })
            or false,
        }),
        { dir = "row" }
      )
    end,
  })
  ---@cast layout FzfCodePreviewLayout
  obj.layout = layout

  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_scroll_keymaps(obj, preview_popup) --- @diagnostic disable-line: param-type-mismatch
  TUIBaseInstanceMixin.setup_close_keymaps(obj) --- @diagnostic disable-line: param-type-mismatch

  FzfBaseInstanceMixin.setup_main_popup_top_border(obj) --- @diagnostic disable-line: param-type-mismatch

  obj:_setup_lua_object_preview()

  return obj
end

function DualPaneLuaObjectPreviewInstance:_setup_lua_object_preview()
  local preview_popup = self.layout.underlay_popups.preview

  self:on_focus(function(payload)
    preview_popup:set_lines({})

    local focus = self.focus

    if not focus then return end

    local lua_obj = self._accessor(focus)
    preview_popup:set_lines(vim.split(vim.inspect(lua_obj), "\n"))
  end)
end

return DualPaneLuaObjectPreviewInstance
