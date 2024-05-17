local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local config = require("fzf").config

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf all lines in current file
--
---@alias FzfGrepFileOptions { initial_query?: string }
---@param opts? FzfGrepFileOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({
    initial_query = "",
  }, opts)
  ---@cast opts FzfGrepFileOptions

  local controller = Controller.new({
    name = "Grep-File",
    extra_args = {
      ["--disabled"] = true,
      ["--multi"] = true,
      ["--query"] = ([['%s']]):format(opts.initial_query),
    },
  })

  local current_filepath = controller:prev_filepath()
  if vim.fn.filereadable(current_filepath) ~= 1 then
    error("File not found: " .. current_filepath)
  end
  local current_line = vim.fn.line(".", controller:prev_win())

  local layout, popups = helpers.triple_pane_2_column_grep(controller, {
    filepath_accessor = function(focus) return current_filepath end,
    row_accessor = function(focus) return focus.line end,
    col_accessor = function(focus) return 0 end,
  })

  ---@alias FzfGrepFileEntry { display: string, line: number, initial_focus: boolean }

  ---@return FzfGrepFileEntry[]
  local entries_getter = function()
    local entries, exit_status, err_msg = utils.systemlist_safe(
      ([[rg %s "%s" %s]]):format(
        utils.shell_opts_tostring(config.default_rg_args),
        controller.query,
        current_filepath
      )
    )

    if exit_status == 1 then
      return {}
    end

    if exit_status ~= 0 then
      error(("rg exits with status %d\n%s"):format(exit_status, err_msg))
    end

    return utils.map(entries, function(i, e)
      local parts = utils.split_string_n(e, 1, ":", {
        discard_empty = false,
      })

      local line = tonumber(utils.strip_ansi_codes(parts[1]))
      assert(line ~= nil)

      return {
        display = e,
        line = line,
        initial_focus = current_line == line,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  return controller
end
