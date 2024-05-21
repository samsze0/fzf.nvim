local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local lang_utils = require("utils.lang")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf diagnostics
--
---@alias FzfDiagnosticsOptions { severity?: { min?: DiagnosticSeverity }, current_buffer_only?: boolean }
---@param opts? FzfDiagnosticsOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({
    severity = { min = vim.diagnostic.severity.WARN },
    current_buffer_only = false,
  }, opts)
  ---@cast opts FzfDiagnosticsOptions

  local controller = Controller.new({
    name = "Diagnostics",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = true,
    row_accessor = function(focus) return focus.diagnostic.lnum end,
    col_accessor = function(focus) return focus.diagnostic.col end,
  })

  ---@alias FzfDiagnosticsEntry { display: string, initial_focus: boolean, diagnostic: Diagnostic, filepath: string }
  ---@return FzfFileEntry[]
  local entries_getter = function()
    local entries = vim.diagnostic.get(
      opts.current_buffer_only and controller:prev_buf() or nil,
      { severity = opts.severity }
    )

    return tbl_utils.map(entries, function(i, e)
      local filepath = opts.current_buffer_only and controller:prev_filepath()
        or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(e.bufnr), ":.") ---@diagnostic disable-line: undefined-field

      return {
        display = fzf_utils.join_by_nbsp(
          lang_utils.match(e.severity, {
            [vim.diagnostic.severity.HINT] = terminal_utils.ansi.blue("H"),
            [vim.diagnostic.severity.INFO] = terminal_utils.ansi.blue("I"),
            [vim.diagnostic.severity.WARN] = terminal_utils.ansi.yellow("W"),
            [vim.diagnostic.severity.ERROR] = terminal_utils.ansi.red("E"),
          }, "?"),
          terminal_utils.ansi.grey(e.source),
          vim.split(e.message, "\n")[1]
        ),
        filepath = filepath,
        diagnostic = e,
        initial_focus = e.lnum + 1 == vim.fn.line(".", controller:prev_win()),
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  return controller
end
