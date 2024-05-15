local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf jumps
--
---@alias FzfJumpOptions { }
---@param opts? { }
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
  ---@cast opts FzfJumpOptions

  local controller = Controller.new({
    name = "Jumps",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = true,
    filepath_accessor = function(focus) return focus.jump.filename end,
    row_accessor = function(focus) return focus.jump.line end,
    col_accessor = function(focus) return focus.jump.col end,
  })

  ---@alias FzfJumpEntry { display: string, jump: Jump, initial_focus: boolean }
  ---@return FzfJumpEntry[]
  local entries_getter = function()
    local jumps, current_pos = jumplist.get_jumps_as_list(controller:prev_win())

    return utils.map(
      jumps,
      function(i, e)
        return {
          display = ([[%s]]):format(utils.ansi_codes.grey(e.filename)),
          jump = e,
          initial_focus = current_pos == i,
        }
      end
    )
  end

  controller:set_entries_getter(entries_getter)

  return controller
end
