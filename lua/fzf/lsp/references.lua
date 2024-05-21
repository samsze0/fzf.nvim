local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf references of symbol under cursor
--
---@alias FzfLspReferencesOptions { }
---@param opts? FzfLspReferencesOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfLspReferencesOptions

  local controller = Controller.new({
    name = "LSP-References",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = true,
  })

  controller:set_entries_getter(function() return {} end)

  ---@alias FzfLspReferencesEntry { display: string, filepath: string, relative_path: string, row: number, col: number, text: string }
  vim.lsp.buf.references({
    includeDeclaration = false,
  }, {
    on_list = function(list)
      if controller:exited() then return end

      local refs = list.items
      local context = list.context
      local title = list.title

      local entries = tbl_utils.map(refs, function(_, e)
        local relative_path = vim.fn.fnamemodify(e.filename, ":~:.")

        return {
          display = fzf_utils.join_by_nbsp(
            terminal_utils.ansi.grey(relative_path),
            vim.trim(e.text)
          ),
          filepath = e.filename,
          relative_path = relative_path,
          row = e.lnum,
          col = e.col,
          text = e.text,
        }
      end)

      controller:set_entries_getter(function() return entries end)
    end,
  })

  return controller
end
