local jumplist = require("jumplist")
local FzfDualPaneNvimPreviewInstance =
  require("fzf.instance.dual-pane-nvim-preview")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local notifier = require("notifier")
local time_utils = require("utils.time")
local config = require("fzf.core.config").value
local lang_utils = require("utils.lang")
local match = lang_utils.match
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local dbg = require("utils").debug

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfJumpsOptions.hl_groups.border_text

---@class FzfJumpsOptions.hl_groups
---@field border_text? FzfJumpsOptions.hl_groups.border_text

---@class FzfJumpsOptions
---@field git_dir? string
---@field hl_groups? FzfJumpsOptions.hl_groups

-- Fzf jumps
--
---@param opts? FzfJumpsOptions
---@return FzfDualPaneNvimPreviewInstance
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfJumpsOptions

  local instance = FzfDualPaneNvimPreviewInstance.new({
    name = "Jumps",
  })

  ---@alias FzfJumpEntry { display: string[], jump: Jump, initial_focus: boolean }
  ---@return FzfJumpEntry[]
  local entries_getter = function()
    local jumps, current_pos = jumplist.get_jumps_as_list(instance:prev_win())

    return tbl_utils.map(
      jumps,
      function(i, e)
        return {
          display = { terminal_utils.ansi.grey(e.filename) },
          jump = e,
          initial_focus = current_pos == i,
        }
      end
    )
  end

  instance:set_entries_getter(entries_getter)
  instance:set_accessor(
    function(entry)
      return {
        filepath = entry.jump.filename,
      }
    end
  )
  instance:set_row_accessor(function(entry) return entry.jump.line end)
  instance:set_col_accessor(function(entry) return entry.jump.col end)

  return instance
end
