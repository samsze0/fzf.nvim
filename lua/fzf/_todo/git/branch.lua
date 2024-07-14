local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local fzf_git_commits = require("fzf.git.commits")
local fzf_utils = require("fzf.utils")
local config = require("fzf").config
local terminal_ft = require("terminal-filetype")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- TODO: initial pos

-- Fzf git branches
--
---@alias FzfGitBranchOptions { git_dir?: string }
---@param opts? FzfGitBranchOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({
    git_dir = git_utils.current_dir(),
  }, opts)
  ---@cast opts FzfGitBranchOptions

  -- if opts.fetch_in_advance then
  --   utils.system(("git -C '%s' fetch"):format(opts.git_dir))
  -- end

  local controller = Controller.new({
    name = "Git-Branch",
  })

  local layout, popups = helpers.dual_pane_terminal_preview(controller)

  ---@alias FzfGitBranchEntry { display: string, branch?: string, is_current_branch?: boolean, is_remote_branch?: boolean, detached_commit?: string }
  ---@return FzfFileEntry[]
  local entries_getter = function()
    local output = terminal_utils.systemlist_unsafe(
      ("git -C '%s' branch --all"):format(opts.git_dir)
    )

    return tbl_utils.map(output, function(i, b)
      local branch = vim.trim(b:sub(3))

      local deteched_commit = branch:match([[^%(HEAD detached at (.*)%)$]])
      if deteched_commit then
        return {
          display = terminal_utils.ansi.yellow(
            ("Detached commit %s"):format(deteched_commit)
          ),
          detached_commit = deteched_commit,
        }
      end

      -- TODO: handle tracking information
      local parts = vim.split(branch, "->")
      if #parts > 1 then branch = vim.trim(parts[1]) end

      local is_current_branch = b:sub(1, 2) == "* "

      local is_remote_branch = b:sub(1, 2) == "  "
        and b:sub(3, 10) == "remotes/"

      return {
        display = fzf_utils.join_by_nbsp(
          is_current_branch and terminal_utils.ansi.blue("") or " ",
          branch
        ),
        branch = branch,
        is_current_branch = is_current_branch,
        is_remote_branch = is_remote_branch,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfGitBranchEntry?

    popups.side:set_lines({})

    if not focus then return end

    local git_log = terminal_utils.systemlist_unsafe(
      ("git -C '%s' log --color --decorate '%s'"):format(
        opts.git_dir,
        focus.branch or focus.detached_commit
      )
    )
    popups.side:set_lines(git_log)
    terminal_ft.refresh_highlight(popups.side.bufnr)
  end)

  popups.main:map("<C-y>", "Copy branch name or commit hash", function()
    if not controller.focus then return end

    local branch_or_commit_hash = controller.focus.branch
      or controller.focus.detached_commit
    vim.fn.setreg("+", branch_or_commit_hash)
    _info(([[Copied %s to clipboard]]):format(branch_or_commit_hash))
  end)

  popups.main:map("<C-x>", "Delete branch", function()
    if not controller.focus then return end

    local focus = controller.focus
    ---@cast focus FzfGitBranchEntry

    if focus.detached_commit then
      _error("Cannot delete detached commit")
      return
    end

    if focus.is_current_branch then
      _error("Cannot delete current branch")
      return
    end

    if focus.is_remote_branch then
      _error("Cannot delete remote branch")
      return
    end

    local branch = focus.branch
    terminal_utils.system_unsafe(
      ("git -C '%s' branch -D '%s'"):format(opts.git_dir, branch)
    )
    controller:refresh()
  end)

  popups.main:map("<C-l>", "List commits", function()
    if not controller.focus then return end

    local branch_or_commit_hash = controller.focus.branch
      or controller.focus.detached_commit
    local next = fzf_git_commits({
      git_dir = opts.git_dir,
      ref = branch_or_commit_hash,
    })
    next:set_parent(controller)
    next:start()
  end)

  popups.main:map("<CR>", "Checkout", function()
    if not controller.focus then return end

    local branch_or_commit_hash = controller.focus.branch
      or controller.focus.detached_commit
    terminal_utils.system_unsafe(
      ("git -C '%s' checkout '%s'"):format(opts.git_dir, branch_or_commit_hash)
    )
    _info(([[Checked out: %s]]):format(branch_or_commit_hash))
    controller:refresh()
  end)

  return controller
end
