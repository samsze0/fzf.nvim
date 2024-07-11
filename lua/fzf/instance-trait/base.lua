local config = require("fzf.core.config").value
local FzfController = require("fzf.core.controller")
local tbl_utils = require("utils.table")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfBaseInstanceTrait : FzfController
---@field layout TUILayout
local FzfBaseInstanceTrait = {}
FzfBaseInstanceTrait.__index = FzfBaseInstanceTrait
FzfBaseInstanceTrait.__is_class = true
setmetatable(FzfBaseInstanceTrait, { __index = FzfController })

---@class FzfCreateInstanceOptions : FzfCreateControllerOptions

-- TODO: move to private config
---@param preview_popup TUISidePopup
function FzfBaseInstanceTrait:setup_scroll_keymaps(preview_popup)
  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview up",
    "<S-Up>"
  )
  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview left",
    "<S-Left>"
  )
  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview down",
    "<S-Down>"
  )
  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview right",
    "<S-Right>"
  )
end

function FzfBaseInstanceTrait:setup_main_popup_top_border()
  local refresh = function()
    ---@type FzfController[]
    local controller_stack = {}

    ---@type FzfController?
    local c = self
    while c do
      table.insert(controller_stack, 1, c)
      c = c:parent()
    end

    local selector_breadcrumbs = table.concat(
      tbl_utils.map(controller_stack, function(_, e) return e.name end),
      " > "
    )

    local icons = {}
    if self:fetching_entries() then table.insert(icons, "󱥸") end
    if self:is_entries_stale() then table.insert(icons, "") end
    self.layout.main_popup.border:set_text(
      "top",
      ([[ %s %s ]]):format(selector_breadcrumbs, table.concat(icons, " "))
    )
  end

  self:on_fetching_entries_change(refresh)
  self:on_is_entries_stale_change(refresh)

  refresh()
end

return FzfBaseInstanceTrait