local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local buffer_utils = require("utils.buffer")
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf buffers
--
---@alias FzfBuffersOptions { }
---@param opts? FzfBuffersOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfBuffersOptions

  local controller = Controller.new({
    name = "Buffers",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = false,
    filepath_accessor = function(focus) return focus.buf.name end,
  })

  ---@alias FzfBuffersEntry { display: string, initial_focus: boolean, buf: VimBuffer }
  ---@return FzfBuffersEntry[]
  local entries_getter = function()
    return tbl_utils.map(
      buffer_utils.getbufsinfo({
        buflisted = true,
      }),
      function(i, buf)
        local relative_filepath = vim.fn.fnamemodify(buf.name, ":~:.")
        local icons = {}

        if buf.changed then table.insert(icons, "") end

        if vim.bo[buf.bufnr].readonly then table.insert(icons, "") end

        return {
          display = fzf_utils.join_by_nbsp(
            relative_filepath,
            terminal_utils.ansi.blue(table.concat(icons, " "))
          ),
          buf = buf,
          initial_focus = buf.bufnr == controller:prev_buf(),
        }
      end
    )
  end

  controller:set_entries_getter(entries_getter)

  popups.main:map("<C-x>", "Delete", function()
    local focus = controller.focus
    ---@cast focus FzfBuffersEntry?

    if not focus then return end

    local bufnr = focus.buf.bufnr

    vim.cmd(([[bdelete %s]]):format(bufnr))
    controller:refresh()
  end)

  popups.main:map("<CR>", nil, function()
    local focus = controller.focus
    ---@cast focus FzfBuffersEntry?

    if not focus then return end

    local bufnr = focus.buf.bufnr

    controller:hide()
    vim.cmd(([[buffer %s]]):format(bufnr))
  end)

  return controller
end
