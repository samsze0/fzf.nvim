local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local config = require("fzf").config
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local str_utils = require("utils.string")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf all lines in current file
--
---@alias FzfGrepFileOptions { initial_query?: string }
---@param opts? FzfGrepFileOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({
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
    local entries, exit_status, err_msg = terminal_utils.systemlist(
      ([[rg %s "%s" %s]]):format(
        terminal_utils.shell_opts_tostring(config.default_rg_args),
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

    return tbl_utils.map(entries, function(i, e)
      local parts = str_utils.split(e, {
        count = 1,
        sep = ":",
        discard_empty = false,
      })

      local line = tonumber(terminal_utils.strip_ansi_codes(parts[1]))
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
