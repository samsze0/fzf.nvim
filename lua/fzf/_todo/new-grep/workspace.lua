local FzfGrepInstance = require("fzf.selector.grep.instance")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf.core.config").value
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local uv_utils = require("utils.uv")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

-- TODO: cater git-less using fd

---@class FzfGrepWorkspaceOptions.hl_groups.border_text
---@field filetype? string

---@class FzfGrepWorkspaceOptions.hl_groups
---@field border_text? FzfGrepWorkspaceOptions.hl_groups.border_text

---@class FzfGrepWorkspaceOptions
---@field git_dir? string
---@field initial_query? string
---@field hl_groups? FzfGrepWorkspaceOptions.hl_groups
---@field debounce_ms? number Debounce time in ms

-- Fzf all lines in current workspace
--
---@param opts? FzfGrepWorkspaceOptions
---@return FzfGrepInstance
return function(opts)
  opts = opts_utils.extend({
    git_dir = git_utils.current_dir(),
    initial_query = "",
    hl_groups = {
      border_text = {},
    },
    debounce = 200,
  }, opts)
  ---@cast opts FzfGrepWorkspaceOptions

  local instance = FzfGrepInstance.new({
    name = "Grep-Workspace",
    extra_args = {
      ["--disabled"] = true,
      ["--multi"] = true,
      ["--query"] = ([['%s']]):format(opts.initial_query),
    },
  })

  ---@alias FzfGrepWorkspaceEntry { display: string[], line: number, full_path: string, relative_path: string }
  ---@return FzfGrepWorkspaceEntry[]
  local entries_getter = function()
    if instance.query:len() == 0 then return {} end

    local command = ([[rg %s '%s' -- $(%s)]]):format(
      terminal_utils.shell_opts_tostring(config.default_rg_args),
      instance.query,
      git_utils.files_cmd(opts.git_dir)
    )

    local lines, status, err = terminal_utils.systemlist(command, {
      keepempty = false,
      trim_endline = true,
    })
    if status ~= 0 then
      if status == 1 then
        instance.layout.overlay_popups.rg_error:set_lines({})
        return {}
      else
        if type(err) == "string" then
          instance.layout.overlay_popups.rg_error:set_lines(
            vim.split(err, "\n")
          )
        end
        return {}
      end
    end

    instance.layout.overlay_popups.rg_error:set_lines({})

    ---@cast lines -nil

    return tbl_utils.map(lines, function(i, e)
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

  instance:set_entries_getter(entries_getter)
  instance._accessor = function(entry)
    ---@cast entry FzfGrepWorkspaceEntry
    return {
      filepath = entry.full_path,
    }
  end
  instance._row_accessor = function(entry)
    ---@cast entry FzfGrepWorkspaceEntry
    return entry.line
  end

  -- Change event is muted when --disabled flag is passed
  -- TODO: kill ongoing rg/fd process when query is modified
  instance:on_change(
    function(payload) instance:refresh() end,
    { debounce_ms = opts.debounce_ms }
  )

  return instance
end
