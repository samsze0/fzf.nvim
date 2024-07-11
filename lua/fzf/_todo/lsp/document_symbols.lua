local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local shared = require("fzf.lsp.shared")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- TODO: integration w/ treesitter to support initial pos

-- Fzf document symbols
--
---@alias FzfLspDocumentSymbolsOptions { }
---@param opts? FzfLspDocumentSymbolsOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfLspDocumentSymbolsOptions

  local controller = Controller.new({
    name = "LSP-Document-Symbols",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = true,
    filepath_accessor = function() return controller:prev_filepath() end,
    row_accessor = function(focus)
      return focus.symbol.selectionRange.start.line + 1
    end,
    col_accessor = function(focus)
      return focus.symbol.selectionRange.start.character + 1
    end,
  })

  local buf = controller:prev_buf()

  controller:set_entries_getter(function() return {} end)

  ---@alias FzfLspDocumentSymbolsEntry { display: string, symbol: table }
  -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#documentSymbol
  local client_request_map, handle = vim.lsp.buf_request(
    buf,
    "textDocument/documentSymbol",
    {
      textDocument = shared.make_lsp_text_document_param(buf),
    },
    function(err, symbol_tree)
      assert(not err)

      ---@type FzfLspDocumentSymbolsEntry[]
      local entries = {}

      local function process_list(symbols, indent)
        indent = indent or 0

        for _, s in ipairs(symbols) do
          table.insert(entries, {
            display = fzf_utils.join_by_nbsp(
              ("⋅"):rep(indent + 1),
              terminal_utils.ansi.blue(
                vim.lsp.protocol.SymbolKind[s.kind] or "Unknown"
              ),
              s.name
            ),
            symbol = s,
          })
          if s.children then process_list(s.children, indent + 1) end
        end
      end

      process_list(symbol_tree)

      controller:set_entries_getter(function() return entries end)
    end
  )

  controller:on_exited(function() handle() end)

  return controller
end
