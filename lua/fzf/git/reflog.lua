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

-- Fzf git ref log
--
---@alias FzfGitReflogOptions { git_dir?: string }
---@param opts? FzfGitReflogOptions
return function(opts)
  opts = utils.opts_extend({
    git_dir = git_utils.current_dir(),
  }, opts)
  ---@cast opts FzfGitReflogOptions

  local controller = Controller.new({
    name = "Git-Reflog",
  })

  local layout, popups = helpers.dual_pane_terminal_preview(controller)

  ---@alias FzfGitReflogEntry { display: string, sha: string, ref: string, action: string, description: string }
  ---@return FzfGitStashEntry[]
  local entries_getter = function()
    return utils.map(
      utils.systemlist(("git -C '%s' reflog"):format(opts.git_dir)),
      function(i, e)
        local sha, ref, action, description =
          e:match("(%w+) (%w+@{%d+}): ([^:]+): (.+)")

        if not sha or not ref or not action or not description then
          error("Failed to parse git reflog entry: " .. e)
        end

        return {
          display = fzf_utils.join_by_nbsp(
            -- ref, -- FIX: curly bracket causing line to not render
            utils.ansi_codes.blue("[" .. action .. "]"),
            description
          ),
          sha = sha,
          ref = ref,
          action = action,
          description = description,
        }
      end
    )
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfGitStashEntry?

    popups.side:set_lines({})

    if not focus then return end

    local reflog = utils.systemlist(
      ([[git -C '%s' diff '%s' | delta %s]]):format(opts.git_dir, focus.ref, "")
    ) -- TODO: share delta config
    popups.side:set_lines(reflog)
    terminal_ft.refresh_highlight(popups.side.bufnr)
  end)

  popups.main:map("<C-y>", "Copy ref", function()
    if not controller.focus then return end

    local ref = controller.focus.ref
    vim.fn.setreg("+", ref)
    vim.info(([[Copied %s to clipboard]]):format(ref))
  end)

  return controller
end
