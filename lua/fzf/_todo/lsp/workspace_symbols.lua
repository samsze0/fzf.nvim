local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local shared = require("fzf.lsp.shared")
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf workspace symbols
--
---@alias FzfLspWorkspaceSymbolsOptions { }
---@param opts? FzfLspWorkspaceSymbolsOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfLspWorkspaceSymbolsOptions

  local controller = Controller.new({
    name = "LSP-Workspace-Symbols",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = true,
    filepath_accessor = function() return controller:prev_filepath() end,
    row_accessor = function(focus)
      return focus.symbol.location.range.start.line + 1
    end,
    col_accessor = function(focus)
      return focus.symbol.location.range.start.character + 1
    end,
  })

  controller:set_entries_getter(function() return {} end)

  local handle

  ---@alias FzfLspWorkspaceSymbolsEntry { display: string, symbol: table, filepath: string }
  controller:subscribe("change", nil, function()
    if handle then
      handle() -- Cancel ongoing request
    end

    _, handle = vim.lsp.buf_request(controller:prev_buf(), "workspace/symbol", {
      query = controller.query,
    }, function(err, symbols)
      assert(not err)

      local entries = tbl_utils.map(symbols, function(i, s)
        local filepath = shared.uri_to_path(s.location.uri)

        return {
          display = fzf_utils.join_by_nbsp(
            terminal_utils.ansi.blue(
              terminal_utils.ansi.grey(filepath),
              vim.lsp.protocol.SymbolKind[s.kind] or "Unknown"
            ),
            s.name
          ),
          filepath = filepath,
          symbol = s,
        }
      end)

      controller:set_entries_getter(function() return entries end)
    end)
  end)

  controller:on_exited(function()
    if handle then
      handle() -- Cancel ongoing request
    end
  end)

  return controller
end
