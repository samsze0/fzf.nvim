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

-- Fzf git stash
--
---@alias FzfGitStashOptions { git_dir?: string }
---@param opts? FzfGitStashOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({
    git_dir = git_utils.current_dir(),
  }, opts)
  ---@cast opts FzfGitStashOptions

  local controller = Controller.new({
    name = "Git-Stash",
  })

  local layout, popups = helpers.dual_pane_terminal_preview(controller)

  ---@alias FzfGitStashEntry { display: string, ref: string, branch: string, message: string, wip: boolean }
  ---@return FzfGitStashEntry[]
  local entries_getter = function()
    -- TODO: specific git format and use nbsp as delimiter

    local command = ([[git -C '%s' stash list]]):format(opts.git_dir)

    local entries = utils.systemlist(command, {
      keepempty = false,
    })

    return utils.map(entries, function(_, e)
      local parts = utils.split_string_n(e, 2, ":", { trim = true })

      local ref = parts[1]
      local wip
      local branch = (parts[2]):match("^WIP on (.*)$")
      if branch then
        wip = true
      else
        branch = (parts[2]):match("^On (.*)$")
        if not branch then error("Invalid stash entry: " .. e) end
      end
      local message = parts[3]

      print(ref)

      return {
        display = fzf_utils.join_by_nbsp(
          -- utils.ansi_codes.blue(ref), -- FIX: curly brackets are causing lines to fail to render because fzf will evaluate them
          utils.ansi_codes.white(message),
          utils.ansi_codes.grey("| " .. branch)
        ),
        ref = ref,
        branch = branch,
        message = message,
        wip = wip,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfGitStashEntry?

    popups.side:set_lines({})

    if not focus then return end

    local git_show = utils.systemlist(
      ([[git -C '%s' stash show --full-index --color '%s' | delta %s]]):format(
        opts.git_dir,
        focus.ref,
        "" -- TODO: move delta options to a config
      )
    )
    popups.side:set_lines(git_show)
    terminal_ft.refresh_highlight(popups.side.bufnr)
  end)

  popups.main:map("<C-y>", "Copy ref", function()
    if not controller.focus then return end

    local ref = controller.focus.ref
    vim.fn.setreg("+", ref)
    vim.info(([[Copied %s to clipboard]]):format(ref))
  end)

  popups.main:map("<C-l>", "List file changes", function()
    if not controller.focus then return end

    local focus = controller.focus
    ---@cast focus FzfGitStashEntry

    local next = fzf_git_file_changes(focus.ref, {
      git_dir = opts.git_dir,
    })
    next:set_parent(controller)
    next:start()
  end)

  return controller
end
