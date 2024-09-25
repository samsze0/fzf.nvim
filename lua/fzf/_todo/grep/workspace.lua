local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local git_utils = require("utils.git")
local config = require("fzf").config
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local str_utils = require("utils.string")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- TODO: no-git mode

-- Fzf all lines of all files in current workspace
--
---@alias FzfGrepWorkspaceOptions { git_dir?: string, initial_query?: string }
---@param opts? FzfGrepWorkspaceOptions
return function(opts)
  opts = opts_utils.extend({
    git_dir = git_utils.current_dir(),
    initial_query = "",
  }, opts)
  ---@cast opts FzfGrepWorkspaceOptions

  local controller = Controller.new({
    name = "Grep-Workspace",
    extra_args = {
      ["--disabled"] = true,
      ["--multi"] = true,
      ["--query"] = ([['%s']]):format(opts.initial_query),
    },
  })

  local layout, popups = helpers.triple_pane_2_column_grep(controller, {
    filepath_accessor = function(focus) return focus.full_path end,
    row_accessor = function(focus) return focus.line end,
    col_accessor = function(focus) return 0 end,
  })

  ---@alias FzfGrepWorkspaceEntry { display: string, line: number, full_path: string, relative_path: string }
  ---@return FzfGrepWorkspaceEntry[]
  local entries_getter = function()
    if controller.query:len() == 0 then return {} end

    local command = ([[rg %s "%s" $(%s)]]):format(
      terminal_utils.shell_opts_tostring(config.default_rg_args),
      controller.query,
      git_utils.files_cmd(opts.git_dir)
    )

    local entries, exit_status, err_msg = terminal_utils.systemlist(command)

    if exit_status == 1 then return {} end

    if exit_status ~= 0 then
      error(("rg exits with status %d\n%s"):format(exit_status, err_msg))
    end

    return tbl_utils.map(entries, function(i, e)
      local parts = str_utils.split(e, {
        count = 2,
        sep = ":",
        discard_empty = false,
      })
      local full_path = terminal_utils.strip_ansi_codes(parts[1])
      local relative_path = vim.fn.fnamemodify(full_path, ":.")
      local line = tonumber(terminal_utils.strip_ansi_codes(parts[2]))
      assert(line ~= nil)

      return {
        display = e,
        line = line,
        full_path = full_path,
        relative_path = relative_path,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  return controller
end
