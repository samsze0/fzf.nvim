local TUIBaseInstanceTrait = require("tui.instance-trait")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
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

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfDualPaneLuaObjectPreviewInstance : FzfController
---@field layout FzfCodePreviewLayout
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
    filepath_accessor = function(entry) return entry.url end,
  }, opts)
  ---@cast opts FzfCreateDualPaneLuaObjectPreviewInstanceOptions

  local obj = FzfController.new(opts)
  setmetatable(obj, DualPaneLuaObjectPreviewInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj FzfDualPaneLuaObjectPreviewInstance

  obj._lua_object_accessor = opts.lua_object_accessor

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

  local layout = Layout.new({
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

  TUIBaseInstanceTrait.setup_controller_ui_hooks(obj)

  FzfBaseInstanceTrait.setup_scroll_keymaps(obj, obj.layout.side_popups.preview)
  FzfBaseInstanceTrait.setup_main_popup_top_border(obj)

  obj:_setup_lua_object_preview()

  return obj
end

function DualPaneLuaObjectPreviewInstance:_setup_lua_object_preview()
  self:on_focus(function(payload)
    self.layout.side_popups.preview:set_lines({})

    local focus = self.focus

    if not focus then return end

    local lua_obj = self._lua_object_accessor(focus)
    self.layout.side_popups.preview:set_lines(
      vim.split(vim.inspect(lua_obj), "\n")
    )
  end)
end

return DualPaneLuaObjectPreviewInstance
