local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local config = require("fzf").config

-- TODO: no-git mode

-- Fzf all lines of all files in current workspace
--
---@alias FzfGrepWorkspaceOptions { git_dir?: string, initial_query?: string }
---@param opts? FzfGrepWorkspaceOptions
return function(opts)
  opts = utils.opts_extend({
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
      utils.shell_opts_tostring(config.default_rg_args),
      controller.query,
      git_utils.files_cmd(opts.git_dir)
    )

    local entries = utils.systemlist(command)
    return utils.map(entries, function(i, e)
      local parts = utils.split_string_n(e, 2, ":", {
        discard_empty = false,
      })
      local full_path = utils.strip_ansi_codes(parts[1])
      local relative_path = vim.fn.fnamemodify(full_path, ":.")
      local line = tonumber(utils.strip_ansi_codes(parts[2]))
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
