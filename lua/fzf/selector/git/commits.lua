local FzfDualPaneTerminalPreviewInstance =
  require("fzf.instance.dual-pane-terminal-preview")
local git_utils = require("utils.git")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local match = lang_utils.match
local str_utils = require("utils.string")
local terminal_utils = require("utils.terminal")
local config = require("fzf.core.config").value
local files_utils = require("utils.files")
local fzf_utils = require("fzf.utils")
local NuiText = require("nui.text")
local file_changes_selector = require("fzf.selector.git.file-changes")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfGitCommitsOptions.hl_groups.border_text
---@field diff_stat? string

---@class FzfGitCommitsOptions.hl_groups
---@field border_text? FzfGitCommitsOptions.hl_groups.border_text

---@class FzfGitCommitsOptions
---@field git_dir? string
---@field filepaths? string[]
---@field ref? string
---@field hl_groups? FzfGitCommitsOptions.hl_groups
---@field limit? number

-- Fzf git commits (i.e. `git log`)
--
---@param opts? FzfGitCommitsOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({
    git_dir = git_utils.current_dir(),
    hl_groups = {
      border_text = {
        diff_stat = "FzfGitCommitsBorderDiffStat",
      },
    },
    -- FIX: if the limit is set too high, then it might hit luajit's table size limit?
    limit = 200, -- For performance reasons
  }, opts)
  ---@cast opts FzfGitCommitsOptions

  local instance = FzfDualPaneTerminalPreviewInstance.new({
    name = "Git-Commits",
  })

  ---@class FzfGitCommitEntry : GitCommit
  ---@field display string[]

  ---@return FzfGitStatusEntry[]
  local entries_getter = function()
    local commits = git_utils.list_commits({
      git_dir = opts.git_dir,
      ref = opts.ref,
      filepaths = opts.filepaths,
      limit = opts.limit,
    })

    return tbl_utils.map(commits, function(_, e)
      ---@cast e FzfGitCommitEntry
      e.display = {
        terminal_utils.ansi.blue(e.hash),
        terminal_utils.ansi.white(e.subject),
        terminal_utils.ansi.grey("| " .. e.author),
        terminal_utils.ansi.grey("| " .. e.commit_date),
        "| " .. e.ref_names,
      }
      return e
    end)
  end

  instance:set_entries_getter(entries_getter)

  local border_component =
    instance.layout.side_popup.bottom_border_text:append("left")

  instance:on_focus(function(payload)
    instance.layout.side_popup:set_lines({})

    local focus = instance.focus
    if not focus then return end

    ---@cast focus FzfGitCommitEntry

    -- Because there can be more than 1 file changes in a commit, we need to show the diff with delta
    local output = git_utils.show_diff_with_delta({
      git_dir = opts.git_dir,
      ref = focus.hash,
      delta_args = config.default_delta_args,
      filepaths = opts.filepaths,
    })
    instance.layout.side_popup:set_lines(output, { filetype = "terminal" })

    -- FIX: diff stat
    local diff_stat = git_utils.diff_stat({
      git_dir = opts.git_dir,
      ref = focus.hash,
    })
    border_component:render(
      NuiText(diff_stat, opts.hl_groups.border_text.diff_stat)
    )
  end)

  instance.layout.main_popup:map("<C-y>", "Copy hash", function()
    local focus = instance.focus
    if not focus then return end

    ---@cast focus FzfGitCommitEntry

    local ref = focus.hash
    vim.fn.setreg("+", ref)
    _info(([[Copied %s to clipboard]]):format(ref))
  end)

  instance.layout.main_popup:map("<C-l>", "List file changes", function()
    local focus = instance.focus
    if not focus then return end

    ---@cast focus FzfGitCommitEntry

    local selector = file_changes_selector({
      git_dir = opts.git_dir,
      ref = focus.hash,
    })
    selector._parent_id = instance._id
    selector:start()
  end)

  return instance
end
