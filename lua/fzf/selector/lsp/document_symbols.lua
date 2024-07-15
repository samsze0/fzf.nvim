local FzfDualPaneNvimPreviewInstance =
  require("fzf.instance.dual-pane-nvim-preview")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf.core.config").value
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local shared = require("fzf.selector.lsp.shared")
local dbg = require("utils").debug

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- TODO: integration w/ treesitter to support initial pos

---@class FzfLspDocumentSymbolsOptions.hl_groups.border_text

---@class FzfLspDocumentSymbolsOptions.hl_groups
---@field border_text? FzfLspDocumentSymbolsOptions.hl_groups.border_text

---@class FzfLspDocumentSymbolsOptions
---@field git_dir? string
---@field hl_groups? FzfLspDocumentSymbolsOptions.hl_groups
---@field indent_char? string The character to use as indentation

-- Fzf document symbols
--
---@param opts? FzfLspDocumentSymbolsOptions
---@return FzfDualPaneNvimPreviewInstance
return function(opts)
  opts = opts_utils.extend({
    hl_groups = {
      border_text = {},
    },
    indent_char = "  ",
  }, opts)
  ---@cast opts FzfLspDocumentSymbolsOptions

  local instance = FzfDualPaneNvimPreviewInstance.new({
    name = "LSP-Document-Symbols",
  })

  local buf = instance:prev_buf()

  ---@alias FzfLspDocumentSymbolsEntry { display: string[], symbol: table }
  -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#documentSymbol
  local client_request_map, handle = vim.lsp.buf_request(
    buf,
    "textDocument/documentSymbol",
    {
      textDocument = shared.make_lsp_text_document_param(buf),
    },
    function(err, symbol_tree)
      assert(not err)

      if instance:exited() then return end

      ---@type FzfLspDocumentSymbolsEntry[]
      local entries = {}

      local function process_list(symbols, indent)
        indent = indent or 0

        for _, s in ipairs(symbols) do
          table.insert(entries, {
            display = {
              (opts.indent_char):rep(indent),
              terminal_utils.ansi.blue(
                vim.lsp.protocol.SymbolKind[s.kind] or "Unknown"
              ),
              s.name,
            },
            symbol = s,
          })
          if s.children then process_list(s.children, indent + 1) end
        end
      end

      process_list(symbol_tree)

      instance:set_entries_getter(function() return entries end)
    end
  )

  instance._accessor = function(entry)
    return {
      -- TODO: add option to stay at the same file
      filepath = instance:prev_filepath(),
    }
  end
  instance._row_accessor = function(entry)
    return entry.symbol.selectionRange.start.line + 1
  end
  instance._col_accessor = function(entry)
    return entry.symbol.selectionRange.start.character + 1
  end

  instance:on_exited(function() handle() end)

  return instance
end
