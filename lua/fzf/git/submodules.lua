local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local fzf_git_commits = require("fzf.git.commits")
local fzf_utils = require("fzf.utils")
local config = require("fzf").config
local terminal_ft = require("terminal-filetype")
local fzf_files = require("fzf.files")
local fzf_git_status = require("fzf.git.status")
local fzf_git_commits = require("fzf.git.commits")
local fzf_git_branches = require("fzf.git.branch")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf git submodules
--
---@alias FzfGitSubmodulesOptions { }
---@param opts? FzfGitSubmodulesOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
  ---@cast opts FzfGitSubmodulesOptions

  local current_git_dir = git_utils.current_dir()

  local controller = Controller.new({
    name = "Git-Submodules",
  })

  local layout, popups = helpers.dual_pane_terminal_preview(controller)

  ---@alias FzfGitSubmoduleEntry { display: string, path: string, gitpath: string }
  ---@return FzfGitSubmoduleEntry[]
  local entries_getter = function()
    local submodules =
      utils.systemlist([[git submodule --quiet foreach 'echo $path']])

    return utils.map(submodules, function(i, e)
      local gitpath = vim.trim(e)

      return {
        display = gitpath,
        gitpath = gitpath,
        path = current_git_dir .. "/" .. gitpath,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfGitSubmoduleEntry?

    popups.side:set_lines({})

    if not focus then return end

    local git_log = utils.systemlist(
      ("git -C '%s' log --color --decorate"):format(focus.path)
    )
    popups.side:set_lines(git_log)
    terminal_ft.refresh_highlight(popups.side.bufnr)
  end)

  popups.main:map("<C-y>", "Copy path", function()
    if not controller.focus then return end

    local path = controller.focus.path
    vim.fn.setreg("+", path)
    _info(([[Copied %s to clipboard]]):format(path))
  end)

  popups.main:map("<C-l>", "List git files", function()
    if not controller.focus then return end

    local path = controller.focus.path
    local next = fzf_files({ git_dir = path })
    next:set_parent(controller)
    next:start()
  end)

  popups.main:map("<C-c>", "List git commits", function()
    if not controller.focus then return end

    local path = controller.focus.path
    local next = fzf_git_commits({ git_dir = path })
    next:set_parent(controller)
    next:start()
  end)

  popups.main:map("<C-s>", "Show git status", function()
    if not controller.focus then return end

    local path = controller.focus.path
    local next = fzf_git_status({ git_dir = path })
    next:set_parent(controller)
    next:start()
  end)

  popups.main:map("<C-b>", "List branches", function()
    if not controller.focus then return end

    local path = controller.focus.path
    local next = fzf_git_branches({ git_dir = path })
    next:set_parent(controller)
    next:start()
  end)

  return controller
end
