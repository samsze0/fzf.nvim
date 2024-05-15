local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local fzf_utils = require("fzf.utils")
local uv_utils = require("utils.uv")
local jumplist = require("jumplist")
local config = require("fzf").config

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf git file changes incurred by a git commit, or stash, or any git object
--
---@alias FzfGitFileChangesOptions { git_dir?: string }
---@param ref string
---@param opts? FzfGitFileChangesOptions
---@return FzfController
return function(ref, opts)
  opts = utils.opts_extend({
    git_dir = git_utils.current_dir(),
  }, opts)
  ---@cast opts FzfGitFileChangesOptions

  local controller = Controller.new({
    name = "Git-File-Changes",
  })

  local layout, popups = helpers.triple_pane_code_diff(controller)

  ---@alias FzfGitFileChangeEntry { display: string, gitpath: string, filepath: string }
  ---@return FzfGitFileChangeEntry[]
  local entries_getter = function()
    local command = ([[git -C '%s' show --pretty=format: --name-only '%s']]):format(
      opts.git_dir,
      ref
    )

    local entries = utils.systemlist(command, {
      keepempty = false,
    })

    return utils.map(entries, function(_, e)
      local gitpath = e
      return {
        display = gitpath,
        gitpath = gitpath,
        filepath = opts.git_dir .. "/" .. gitpath,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfGitFileChangeEntry?

    popups.side.left:set_lines({})
    popups.side.right:set_lines({})

    if not focus then return end

    local before = utils.systemlist_safe(
      ([[git -C '%s' cat-file blob '%s'~1:'%s']]):format(
        opts.git_dir,
        ref,
        focus.gitpath
      )
    )
    local after = utils.systemlist_safe(
      ([[git -C '%s' cat-file blob '%s':'%s']]):format(
        opts.git_dir,
        ref,
        focus.gitpath
      )
    )

    if not before and not after then
      error("Failed to fetch file change details")
    end

    local filename = vim.fn.fnamemodify(focus.filepath, ":t")
    local ft = vim.filetype.match({
      filename = filename,
      contents = before or after,
    })
    vim.bo[popups.side.left.bufnr].filetype = ft or ""
    vim.bo[popups.side.right.bufnr].filetype = ft or ""

    popups.side.left:set_lines(before or {})
    popups.side.right:set_lines(after or {})

    utils.diff_bufs(popups.side.left.bufnr, popups.side.right.bufnr)
  end)

  popups.main:map("<C-y>", "Copy filepath", function()
    if not controller.focus then return end

    local path = controller.focus.filepath
    vim.fn.setreg("+", path)
    _info(([[Copied %s to clipboard]]):format(path))
  end)

  popups.main:map("<CR>", "Goto file", function()
    if not controller.focus then return end

    local focus = controller.focus
    ---@cast focus FzfGitStatusEntry

    local path = focus.filepath

    -- TODO: Add a check for merge conflicts. And open a window for diffing

    controller:hide()
    jumplist.save()
    vim.cmd(([[e %s]]):format(path))
  end)

  return controller
end
