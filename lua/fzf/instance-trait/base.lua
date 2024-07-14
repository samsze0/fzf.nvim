local config = require("fzf.core.config").value
local FzfController = require("fzf.core.controller")
local tbl_utils = require("utils.table")
local NuiText = require("nui.text")

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
---@param opts? { force?: boolean }
function FzfBaseInstanceTrait:setup_scroll_keymaps(preview_popup, opts)
  opts = opts or {}

  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview up",
    "<S-Up>",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview left",
    "<S-Left>",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview down",
    "<S-Down>",
    { force = opts.force }
  )
  self.layout.main_popup:map_remote(
    preview_popup,
    "Scroll preview right",
    "<S-Right>",
    { force = opts.force }
  )
end

function FzfBaseInstanceTrait:setup_maximise_popup_keymaps()
  self.layout.main_popup:map(
    "<C-z>",
    "Maximise",
    function() self.layout:maximise_popup("main") end
  )
end

function FzfBaseInstanceTrait:setup_main_popup_top_border()
  local border_component =
    self.layout.main_popup.top_border_text:prepend("left")

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

    local border_text = selector_breadcrumbs
    if #icons > 0 then
      border_text = border_text .. " " .. table.concat(icons, " ")
    end

    border_component:render(
      NuiText(
        border_text,
        config.highlight_groups.border_text.selector_breadcrumbs
      )
    )
  end

  self:on_fetching_entries_change(refresh)
  self:on_is_entries_stale_change(refresh)

  refresh()
end

return FzfBaseInstanceTrait
