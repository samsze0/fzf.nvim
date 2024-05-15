local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local tab_utils = require("utils.tab")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf tabs
--
---@alias FzfTabsOptions { }
---@param opts? FzfTabsOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
  ---@cast opts FzfTabsOptions

  local controller = Controller.new({
    name = "Tabs",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = false,
    filepath_accessor = function(focus) return focus.buf.name end,
  })

  ---@alias FzfTabsEntry { display: string, initial_focus: boolean, tab: VimTab }
  ---@return FzfTabsEntry[]
  local entries_getter = function()
    local prev_tab = controller:prev_tab()

    return utils.map(
      tab_utils.gettabsinfo(),
      function(i, tab)
        return {
          display = "",
          tab = tab,
          initial_focus = tab.tabnr == prev_tab,
        }
      end
    )
  end

  controller:set_entries_getter(entries_getter)

  popups.main:map("<C-x>", "Close", function()
    local focus = controller.focus
    ---@cast focus FzfTabsEntry?

    if not focus then return end

    local tabnr = focus.tab.tabnr

    vim.cmd(([[tabclose %s]]):format(tabnr))
    controller:refresh()
  end)

  popups.main:map("<CR>", nil, function()
    local focus = controller.focus
    ---@cast focus FzfTabsEntry?

    if not focus then return end

    local tabnr = focus.tab.tabnr

    controller:hide()
    vim.cmd(([[tabnext %s]]):format(tabnr))
  end)

  return controller
end
