local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local buffer_utils = require("utils.buffer")

-- Fzf buffers
--
---@alias FzfBuffersOptions { }
---@param opts? FzfBuffersOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
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
    return utils.map(
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
            utils.ansi_codes.blue(table.concat(icons, " "))
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
