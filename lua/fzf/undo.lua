local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local fzf_utils = require("fzf.utils")
local uv_utils = require("utils.uv")
local jumplist = require("jumplist")
local config = require("fzf").config
local timeago = require("utils.timeago")
local undo_utils = require("utils.undo")

-- Fzf current file's undos
--
---@alias FzfUndoOptions { }
---@param opts? FzfUndoOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
  ---@cast opts FzfUndoOptions

  local controller = Controller.new({
    name = "Undo",
  })

  local layout, popups = helpers.triple_pane_code_diff(controller)

  ---@alias FzfUndoEntry { display: string, initial_focus: boolean, undo: VimUndo }
  ---@return FzfUndoEntry[]
  local entries_getter = function()
    local undotree = vim.api.nvim_buf_call(
      controller:prev_buf(),
      function() return vim.fn.undotree() end ---@diagnostic disable-line: redundant-return-value
    )
    ---@cast undotree VimUndoTree

    ---@type FzfUndoEntry[]
    local entries = {}

    local function process_undos(undos, alt_level)
      alt_level = alt_level or 0

      for i = #undos, 1, -1 do
        local undo = undos[i]
        ---@cast undo VimUndo

        table.insert(entries, {
          display = fzf_utils.join_by_nbsp(
            ("⋅"):rep(alt_level + 1),
            timeago(undo.time)
          ),
          undo = undo,
          initial_focus = undo.seq == undotree.seq_cur,
        })

        if undo.alt then process_undos(undo.alt, alt_level + 1) end
      end
    end

    process_undos(undotree.entries)

    return entries
  end

  controller:set_entries_getter(entries_getter)

  vim.bo[popups.side.left.bufnr].filetype = vim.bo[controller:prev_buf()].filetype
    or ""
  vim.bo[popups.side.right.bufnr].filetype = vim.bo[controller:prev_buf()].filetype
    or ""

  controller:subscribe("focus", nil, function(payload)
    popups.side.left:set_lines({})
    popups.side.right:set_lines({})

    local focus = controller.focus
    ---@cast focus FzfUndoEntry?

    if not focus then return end

    local before, after = undo_utils.get_undo_before_and_after(
      controller:prev_buf(),
      focus.undo.seq
    )
    popups.side.left:set_lines(before)
    popups.side.right:set_lines(after)

    utils.diff_bufs(popups.side.left.bufnr, popups.side.right.bufnr)
  end)

  popups.main:map("<C-y>", "Copy undo nr", function()
    if not controller.focus then return end

    local undo_nr = controller.focus.undo.seq_nr
    vim.fn.setreg("+", undo_nr)
    vim.info(([[Copied %s to clipboard]]):format(undo_nr))
  end)

  popups.main:map("<C-o>", "Open diff", function()
    local focus = controller.focus
    ---@cast focus FzfUndoEntry?

    if not focus then return end

    local before, after = undo_utils.get_undo_before_and_after(
      controller:prev_buf(),
      focus.undo.seq
    )

    utils.show_diff(
      {
        filetype = vim.bo[controller:prev_buf()].filetype,
      },
      { filepath_or_content = before, readonly = true },
      { filepath_or_content = after, readonly = false }
    )
  end)

  popups.main:map("<CR>", "Undo", function()
    local focus = controller.focus
    ---@cast focus FzfUndoEntry?

    if not focus then return end

    local undo_nr = focus.undo.seq
    vim.cmd(("redo %s"):format(undo_nr))
    vim.info("Redone to %s", undo_nr)
  end)

  return controller
end
