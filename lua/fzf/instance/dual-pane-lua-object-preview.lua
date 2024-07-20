local TUIBaseInstanceMixin = require("tui.instance-mixin")
local FzfBaseInstanceMixin = require("fzf.instance-mixin.base")
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
  local preview_popup = SidePopup.new({
    popup_opts = {
      buf_options = {
        filetype = "lua",
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

  obj:_setup_lua_object_preview()

  return obj
end

function DualPaneLuaObjectPreviewInstance:_setup_lua_object_preview()
  self:on_focus(function(payload)
    self.layout.side_popups.preview:set_lines({})

    local focus = self.focus

    if not focus then return end

    local lua_obj = self._accessor(focus)
    self.layout.side_popups.preview:set_lines(
      vim.split(vim.inspect(lua_obj), "\n")
    )
  end)
end

return DualPaneLuaObjectPreviewInstance
