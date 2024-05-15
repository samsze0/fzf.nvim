local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local fzf_utils = require("fzf.utils")
local uv_utils = require("utils.uv")
local jumplist = require("jumplist")
local fzf_git_file_changes = require("fzf.git.file-changes")
local config = require("fzf").config
local terminal_ft = require("terminal-filetype")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf git commits (i.e. run `git log`)
--
-- If filepaths is nil, then all commits are shown, otherwise only those commits that
-- affect the given filepaths are shown.
-- Likewise for `ref`.
--
---@alias FzfGitCommitsOptions { git_dir?: string, filepaths?: string, ref?: string }
---@param opts? FzfGitCommitsOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({
    git_dir = git_utils.current_dir(),
  }, opts)
  ---@cast opts FzfGitCommitsOptions

  local controller = Controller.new({
    name = "Git-Commits",
  })

  local layout, popups = helpers.dual_pane_terminal_preview(controller)

  ---@alias FzfGitCommitEntry { display: string, hash: string, subject: string, ref_names: string, author: string, commit_date: string }
  ---@return FzfGitStatusEntry[]
  local entries_getter = function()
    local format = fzf_utils.join_by_nbsp(
      "%h", -- Hash
      "%s", -- Subject
      "%D", -- Ref names
      "%an", -- Author
      "%cr" -- Commit date (relative)
    )

    local command = ([[git -C '%s' log --oneline --color --pretty=format:'%s']]):format(
      opts.git_dir,
      format
    )

    if opts.ref then command = command .. ([[ '%s']]):format(opts.ref) end
    if opts.filepaths then
      command = command .. ([[ -- %s]]):format(opts.filepaths) -- Be careful special chars must be escaped
    end

    local entries = utils.systemlist(command, {
      keepempty = false,
    })

    return utils.map(entries, function(_, e)
      local parts = vim.split(e, utils.nbsp)
      if #parts ~= 5 then error("Invalid git log entry: " .. e) end

      return {
        display = fzf_utils.join_by_nbsp(
          utils.ansi_codes.blue(parts[1]),
          utils.ansi_codes.white(parts[2]),
          utils.ansi_codes.grey("| " .. parts[4]),
          utils.ansi_codes.grey("| " .. parts[5]),
          "| " .. parts[3]
        ),
        hash = parts[1],
        subject = parts[2],
        ref_names = parts[3],
        author = parts[4],
        commit_date = parts[5],
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfGitCommitEntry?

    popups.side:set_lines({})

    if not focus then return end

    local git_show =
      utils.systemlist(([[git -C '%s' show --color %s %s | delta %s]]):format(
        opts.git_dir,
        focus.hash,
        opts.filepaths and ("-- %s"):format(opts.filepaths) or "",
        "" -- TODO: move delta options to a config
      ))
    popups.side:set_lines(git_show)
    terminal_ft.refresh_highlight(popups.side.bufnr)
  end)

  popups.main:map("<C-l>", "List file changes", function()
    if not controller.focus then return end

    local focus = controller.focus
    ---@cast focus FzfGitCommitEntry

    local next = fzf_git_file_changes(focus.hash, {
      git_dir = opts.git_dir,
    })
    next:set_parent(controller)
    next:start()
  end)

  return controller
end
