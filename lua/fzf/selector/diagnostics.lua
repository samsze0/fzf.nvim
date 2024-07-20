local FzfDualPaneNvimPreviewInstance =
  require("fzf.instance.dual-pane-nvim-preview")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf.core.config").value
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local lang_utils = require("utils.lang")
local match = lang_utils.match
local dbg = require("utils").debug

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfDiagnosticsOptions.hl_groups.border_text

---@class FzfDiagnosticsOptions.hl_groups
---@field border_text? FzfDiagnosticsOptions.hl_groups.border_text

---@class FzfDiagnosticsOptions
---@field severity? { min?: lsp.DiagnosticSeverity }
---@field current_buffer_only? boolean
---@field hl_groups? FzfDiagnosticsOptions.hl_groups

-- Fzf diagnostics
--
---@param opts? FzfDiagnosticsOptions
---@return FzfDualPaneNvimPreviewInstance
return function(opts)
  opts = opts_utils.extend({
    severity = { min = vim.diagnostic.severity.WARN },
    current_buffer_only = false,
  }, opts)
  ---@cast opts FzfDiagnosticsOptions

  local instance = FzfDualPaneNvimPreviewInstance.new({
    name = "Diagnostics",
  })

  ---@alias FzfDiagnosticsEntry { display: string[], initial_focus: boolean, diagnostic: lsp.Diagnostic, filepath: string }
  ---@return FzfFileEntry[]
  local entries_getter = function()
    local entries = vim.diagnostic.get(
      opts.current_buffer_only and instance:prev_buf() or nil,
      { severity = opts.severity }
    )

    return tbl_utils.map(entries, function(i, e)
      local filepath = opts.current_buffer_only and instance:prev_filepath()
        or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(e.bufnr), ":.") ---@diagnostic disable-line: undefined-field

      return {
        display = {
          match(e.severity, {
            [vim.diagnostic.severity.HINT] = terminal_utils.ansi.blue("H"),
            [vim.diagnostic.severity.INFO] = terminal_utils.ansi.blue("I"),
            [vim.diagnostic.severity.WARN] = terminal_utils.ansi.yellow("W"),
            [vim.diagnostic.severity.ERROR] = terminal_utils.ansi.red("E"),
          }, "?"),
          terminal_utils.ansi.grey(e.source),
          vim.split(e.message, "\n")[1],
        },
        filepath = filepath,
        diagnostic = e,
        initial_focus = e.lnum + 1 == vim.fn.line(".", instance:prev_win()),
      }
    end)
  end

  instance:set_entries_getter(entries_getter)

  instance._accessor = function(entry)
    -- TOOD: if current_buffer_only is true, then we should avoid loading up the same file again
    return {
      filepath = entry.filepath,
    }
  end
  instance._row_accessor = function(entry) return entry.diagnostic.lnum end
  instance._col_accessor = function(entry) return entry.diagnostic.col end

  return instance
end
