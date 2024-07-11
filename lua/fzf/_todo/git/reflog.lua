local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local opts_utils = require("utils.opts")
local fzf_utils = require("fzf.utils")
local git_utils = require("utils.git")
local config = require("fzf").config
local terminal_ft = require("terminal-filetype")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf git ref log
--
---@alias FzfGitReflogOptions { git_dir?: string }
---@param opts? FzfGitReflogOptions
return function(opts)
  opts = opts_utils.extend({
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
    return tbl_utils.map(
      terminal_utils.systemlist_unsafe(
        ("git -C '%s' reflog"):format(opts.git_dir)
      ),
      function(i, e)
        local sha, ref, action, description =
          e:match("(%w+) (%w+@{%d+}): ([^:]+): (.+)")

        if not sha or not ref or not action or not description then
          error("Failed to parse git reflog entry: " .. e)
        end

        return {
          display = fzf_utils.join_by_nbsp(
            -- ref, -- FIX: curly bracket causing line to not render
            terminal_utils.ansi.blue("[" .. action .. "]"),
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

    local reflog = terminal_utils.systemlist_unsafe(
      ([[git -C '%s' diff '%s' | delta %s]]):format(opts.git_dir, focus.ref, "")
    ) -- TODO: share delta config
    popups.side:set_lines(reflog)
    terminal_ft.refresh_highlight(popups.side.bufnr)
  end)

  popups.main:map("<C-y>", "Copy ref", function()
    if not controller.focus then return end

    local ref = controller.focus.ref
    vim.fn.setreg("+", ref)
    _info(([[Copied %s to clipboard]]):format(ref))
  end)

  return controller
end
