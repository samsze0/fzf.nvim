local FzfDualPaneNvimPreviewInstance =
  require("fzf.instance.dual-pane-nvim-preview")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf.core.config").value
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local dbg = require("utils").debug

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfLspDefinitionsOptions.hl_groups.border_text

---@class FzfLspDefinitionsOptions.hl_groups
---@field border_text? FzfLspDefinitionsOptions.hl_groups.border_text

---@class FzfLspDefinitionsOptions
---@field git_dir? string
---@field hl_groups? FzfLspDefinitionsOptions.hl_groups

-- Fzf definitions of symbol under cursor
--
---@param opts? FzfLspDefinitionsOptions
---@return FzfDualPaneNvimPreviewInstance
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfLspDefinitionsOptions

  local instance = FzfDualPaneNvimPreviewInstance.new({
    name = "LSP-Definitions",
  })

  ---@alias FzfLspDefinitionEntry { display: string[], filepath: string, relative_path: string, row: number, col: number, text: string }
  vim.lsp.buf.definition({
    on_list = function(list)
      if instance:exited() then return end

      local defs = list.items
      local context = list.context
      local title = list.title

      local entries = tbl_utils.map(defs, function(_, e)
        local relative_path = vim.fn.fnamemodify(e.filename, ":~:.")

        return {
          display = {
            terminal_utils.ansi.grey(relative_path),
            vim.trim(e.text),
          },
          filepath = e.filename,
          relative_path = relative_path,
          row = e.lnum,
          col = e.col,
          text = e.text,
        }
      end)

      instance:set_entries_getter(function() return entries end)
    end,
  })

  instance._accessor = function(entry)
    return {
      filepath = entry.filepath,
    }
  end
  instance._row_accessor = function(entry) return entry.row end
  instance._col_accessor = function(entry) return entry.col end

  return instance
end