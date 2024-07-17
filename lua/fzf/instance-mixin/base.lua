local config = require("fzf.core.config").value
local FzfController = require("fzf.core.controller")
local tbl_utils = require("utils.table")
local NuiText = require("nui.text")
local uv_utils = require("utils.uv")
local oop_utils = require("utils.oop")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfBaseInstanceMixin : FzfController
---@field layout FzfLayout
local FzfBaseInstanceMixin = oop_utils.new_class(FzfController)

---@class FzfCreateInstanceOptions : FzfCreateControllerOptions

function FzfBaseInstanceMixin:setup_main_popup_top_border()
  local border_component_1 =
    self.layout.main_popup.top_border_text:prepend("left")

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

  border_component_1:render(
    NuiText(
      selector_breadcrumbs,
      config.highlight_groups.border_text.selector_breadcrumbs
    )
  )

  local border_component_2 =
    self.layout.main_popup.top_border_text:append("left")

  local loading_icon_animation = { "◴", "◷", "◶", "◵" }
  local loading_icon_animation_state = 1
  ---@type uv.uv_timer_t?
  local loading_icon_animation_timer

  local function render_loading_icon()
    local output

    if self:fetching_entries() then
      if not loading_icon_animation_timer then
        local timer, err = vim.loop.new_timer()
        assert(timer, err)

        loading_icon_animation_timer = timer
        loading_icon_animation_timer:start(
          0,
          100,
          vim.schedule_wrap(function()
            loading_icon_animation_state = loading_icon_animation_state + 1
            if loading_icon_animation_state > #loading_icon_animation then
              loading_icon_animation_state = 1
            end
            render_loading_icon()
          end)
        )
      end
      output = loading_icon_animation[loading_icon_animation_state]
    else
      if loading_icon_animation_timer then
        loading_icon_animation_timer:stop()
        loading_icon_animation_timer:close()
        loading_icon_animation_timer = nil
      end
      output = ""
    end

    border_component_2:render(
      NuiText(output, config.highlight_groups.border_text.loading_indicator)
    )
  end

  self:on_fetching_entries_change(render_loading_icon)

  local border_component_3 =
    self.layout.main_popup.top_border_text:append("left")

  self:on_is_entries_stale_change(
    function()
      border_component_3:render(
        NuiText(
          self:is_entries_stale() and "" or "",
          config.highlight_groups.border_text.stale_indicator
        )
      )
    end
  )
end

return FzfBaseInstanceMixin
