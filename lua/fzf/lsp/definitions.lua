local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local shared = require("fzf.lsp.shared")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf definitions of symbol under cursor
--
---@alias FzfLspDefinitionsOptions { }
---@param opts? FzfLspDefinitionsOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
  ---@cast opts FzfLspDefinitionsOptions

  local controller = Controller.new({
    name = "LSP-Definitions",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = true,
  })

  controller:set_entries_getter(function() return {} end)

  ---@alias FzfLspDefinitionEntry { display: string, filepath: string, relative_path: string, row: number, col: number, text: string }
  vim.lsp.buf.definition({
    on_list = function(list)
      if controller:exited() then return end

      local defs = list.items
      local context = list.context
      local title = list.title

      local entries = utils.map(defs, function(_, e)
        local relative_path = vim.fn.fnamemodify(e.filename, ":~:.")

        return {
          display = fzf_utils.join_by_nbsp(
            utils.ansi_codes.grey(relative_path),
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
