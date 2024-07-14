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
local NuiText = require("nui.text")
local terminal_filetype = require("terminal-filetype")
local file_changes_selector = require("fzf.selector.git.file-changes")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfGitStashOptions.hl_groups.border_text
---@field diff_stat? string

---@class FzfGitStashOptions.hl_groups
---@field border_text? FzfGitStashOptions.hl_groups.border_text

---@class FzfGitStashOptions
---@field git_dir? string
---@field hl_groups? FzfGitStashOptions.hl_groups

-- Fzf git stash
--
---@param opts? FzfGitStashOptions
---@return FzfDualPaneTerminalPreviewInstance
return function(opts)
  opts = opts_utils.deep_extend({
    git_dir = git_utils.current_dir(),
    hl_groups = {
      border_text = {
        diff_stat = "FzfGitStashBorderDiffStat",
      },
    },
  }, opts)
  ---@cast opts FzfGitStashOptions

  local instance = FzfDualPaneTerminalPreviewInstance.new({
    name = "Git-Stash",
  })

  -- From git-stash documentation:
  -- A stash is by default listed as "WIP on branchname …​", but you can give a more descriptive message on the command line when you create one.
  ---@alias FzfGitStashEntry { display: string[], ref: string, branch: string, message: string, wip: boolean }
  ---@return FzfGitStashEntry[]
  local entries_getter = function()
    local stash = git_utils.list_stash({
      git_dir = opts.git_dir,
    })

    -- Tried to use git pretty format with something like
    -- --format="%gd %gs" but it seems the stash message is tied directly to the branch name

    return tbl_utils.map(stash, function(_, e)
      local parts = str_utils.split(e, { count = 2, sep = ":", trim = true })

      local ref = parts[1]

      local wip = false
      local branch
      branch = (parts[2]):match("^WIP on (.*)$")
      if branch then
        wip = true
      else
        branch = (parts[2]):match("^On (.*)$")
        if not branch then error("Invalid stash entry: " .. e) end
      end

      local message = parts[3]

      return {
        display = {
          terminal_utils.ansi.blue(ref),
          terminal_utils.ansi.white(message),
          terminal_utils.ansi.grey(branch),
        },
        ref = ref,
        branch = branch,
        message = message,
        wip = wip,
      }
    end)
  end

  instance:set_entries_getter(entries_getter)

  local border_component =
    instance.layout.side_popup.bottom_border_text:append("left")

  instance:on_focus(function(payload)
    instance.layout.side_popup:set_lines({})

    local focus = instance.focus
    if not focus then return end

    ---@cast focus FzfGitStashEntry

    -- Because there can be more than 1 file changes in a stash, we need to show the diff with delta
    local output = git_utils.show_stash_with_delta(focus.ref, {
      git_dir = opts.git_dir,
      delta_args = config.default_delta_args,
    })
    instance.layout.side_popup:set_lines(output, { filetype = "terminal" })
    terminal_filetype.refresh_highlight(instance.layout.side_popup.bufnr)

    local diff_stat = git_utils.stash_diff_stat(focus.ref, {
      git_dir = opts.git_dir,
    })
    border_component:render(
      NuiText(diff_stat, opts.hl_groups.border_text.diff_stat)
    )
  end)

  instance.layout.main_popup:map("<C-y>", "Copy ref", function()
    local focus = instance.focus
    if not focus then return end

    ---@cast focus FzfGitStashEntry

    local ref = focus.ref
    vim.fn.setreg("+", ref)
    _info(([[Copied %s to clipboard]]):format(ref))
  end)

  instance.layout.main_popup:map("<C-l>", "List file changes", function()
    local focus = instance.focus
    if not focus then return end

    ---@cast focus FzfGitStashEntry

    local selector = file_changes_selector({
      git_dir = opts.git_dir,
      ref = focus.ref,
    })
    selector._parent_id = instance._id
    selector:start()
  end)

  return instance
end
