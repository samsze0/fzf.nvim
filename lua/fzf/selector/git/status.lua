local FzfTriplePaneCodeDiffInstance =
  require("fzf.instance.triple-pane-code-diff")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local TUIBaseInstanceTrait = require("tui.instance-trait")
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

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfGitStatusOptions.hl_groups.border_text
---@field added? string
---@field changed? string
---@field deleted? string
---@field normal? string
---@field diff_stat? string

---@class FzfGitStatusOptions.hl_groups
---@field border_text? FzfGitStatusOptions.hl_groups.border_text

---@class FzfGitStatusOptions
---@field git_dir? string
---@field show_diff_between_head_and_staged_when_file_is_partially_staged? boolean
---@field hl_groups? FzfGitStatusOptions.hl_groups

-- Fzf git status
--
---@param opts? FzfGitStatusOptions
---@return FzfTriplePaneCodeDiffInstance
return function(opts)
  opts = opts_utils.deep_extend({
    git_dir = git_utils.current_dir(),
    hl_groups = {
      border_text = {
        added = "FzfGitStatusBorderAdded",
        changed = "FzfGitStatusBorderChanged",
        deleted = "FzfGitStatusBorderDeleted",
        normal = "FzfGitStatusBorderNormal",
        diff_stat = "FzfGitStatusBorderDiffStat",
      },
    },
  }, opts)
  ---@cast opts FzfGitStatusOptions

  local instance = FzfTriplePaneCodeDiffInstance.new({
    name = "Git-Status",
  })

  local current_gitpath =
    git_utils.convert_filepath_to_gitpath(instance:prev_filepath())

  ---@class FzfGitStatusEntry : GitStatus
  ---@field display string[]
  ---@field initial_focus boolean

  ---@return FzfGitStatusEntry[]
  local entries_getter = function()
    local status = git_utils.list_status({
      git_dir = opts.git_dir,
    })

    return tbl_utils.map(status, function(i, e)
      ---@cast e FzfGitStatusEntry

      local display = {
        ([[%s %s]]):format(
          terminal_utils.ansi.blue(e.status_x),
          match(e.status_y, {
            ["D"] = terminal_utils.ansi.red,
          }, terminal_utils.ansi.yellow)(e.status_y)
        ),
        e.gitpath,
      }

      e.display = display
      e.initial_focus = current_gitpath == e.gitpath

      return e
    end)
  end

  instance:set_entries_getter(entries_getter)

  local border_component_git_status =
    instance.layout.main_popup.bottom_border_text:append("left")
  local border_component_a =
    instance.layout.side_popups.a.top_border_text:prepend("left")
  local border_component_b =
    instance.layout.side_popups.b.top_border_text:prepend("left")

  local set_border = function(text, hl_group, popup, border_component)
    local hl_group = match(hl_group, {
      ["added"] = opts.hl_groups.border_text.added,
      ["changed"] = opts.hl_groups.border_text.changed,
      ["deleted"] = opts.hl_groups.border_text.deleted,
    }, opts.hl_groups.border_text.normal)
    local nui_text = NuiText(text, hl_group)
    border_component:render(nui_text)
  end

  ---@param text string
  ---@param hl_group? "added" | "changed" | "deleted"
  local set_a_border = function(text, hl_group)
    local a_popup = instance.layout.side_popups.a
    set_border(text, hl_group, a_popup, border_component_a)
  end

  ---@param text string
  ---@param hl_group? "added" | "changed" | "deleted"
  local set_b_border = function(text, hl_group)
    local b_popup = instance.layout.side_popups.b
    set_border(text, hl_group, b_popup, border_component_b)
  end

  instance._a_accessor = function(entry)
    ---@cast entry FzfGitStatusEntry

    if entry.added or entry.is_untracked then
      set_a_border("Staging")
      return {}
    end

    if entry.renamed then
      set_a_border("Staging")
      return {
        filepath = entry.filepath,
      }
    end

    if entry.deleted then
      set_a_border("HEAD")
      return {
        filetype = files_utils.get_filetype(entry.filepath),
        lines = git_utils.show_head(entry.gitpath, { git_dir = opts.git_dir }),
      }
    end

    if entry.is_fully_staged then
      set_a_border("HEAD")
      return {
        filetype = files_utils.get_filetype(entry.filepath),
        lines = git_utils.show_head(entry.gitpath, { git_dir = opts.git_dir }),
      }
    end

    -- Partially staged
    if opts.show_diff_between_head_and_staged_when_file_is_partially_staged then
      set_a_border("HEAD")
      return {
        filetype = files_utils.get_filetype(entry.filepath),
        lines = git_utils.show_head(entry.gitpath, { git_dir = opts.git_dir }),
      }
    else
      set_a_border("Staging")
      return {
        filetype = files_utils.get_filetype(entry.filepath),
        lines = git_utils.show_staged(
          entry.gitpath,
          { git_dir = opts.git_dir }
        ),
      }
    end
  end

  instance._b_accessor = function(entry)
    ---@cast entry FzfGitStatusEntry

    if entry.deleted then
      set_b_border("Worktree (deleted)", "deleted")
      return {}
    end

    if
      opts.show_diff_between_head_and_staged_when_file_is_partially_staged
      and entry.is_partially_staged
    then
      set_b_border("Staging")
      return {
        filetype = files_utils.get_filetype(entry.filepath),
        lines = git_utils.show_staged(
          entry.gitpath,
          { git_dir = opts.git_dir }
        ),
      }
    end

    if entry.added or entry.is_untracked then
      set_b_border("Worktree (added)", "added")
    else
      set_b_border("Worktree")
    end

    return {
      filepath = entry.filepath,
    }
  end

  instance._picker = function(entry)
    if entry.deleted then return "a" end

    return "b"
  end

  instance:on_focus(function(payload)
    local focus = instance.focus
    if not focus then return end
    ---@cast focus FzfGitStatusEntry

    if focus.deleted then
      TUIBaseInstanceTrait.setup_scroll_keymaps(
        instance, ---@diagnostic disable-line: param-type-mismatch
        instance.layout.side_popups.a,
        { force = true }
      )
    else
      TUIBaseInstanceTrait.setup_scroll_keymaps(
        instance,  ---@diagnostic disable-line: param-type-mismatch
        instance.layout.side_popups.b,
        { force = true }
      )
    end
  end)

  instance:on_reloaded(function(payload)
    local short_status = git_utils.diff_stat({
      git_dir = opts.git_dir,
    })
    border_component_git_status:render(
      NuiText(short_status, opts.hl_groups.border_text.diff_stat)
    )
  end)

  instance.layout.main_popup:map("<Left>", "Stage", function()
    local focus = instance.focus
    if not focus then return end
    ---@cast focus FzfGitStatusEntry

    local filepath = focus.filepath
    terminal_utils.system_unsafe(
      ([[git -C '%s' add '%s']]):format(opts.git_dir, filepath)
    )
    instance:refresh()
  end)

  instance.layout.main_popup:map("<Right>", "Unstage", function()
    local focus = instance.focus
    if not focus then return end
    ---@cast focus FzfGitStatusEntry

    local filepath = focus.filepath
    terminal_utils.system_unsafe(
      ([[git -C '%s' restore --staged '%s']]):format(opts.git_dir, filepath)
    )
    instance:refresh()
  end)

  instance.layout.main_popup:map("<C-x>", "Restore", function()
    local focus = instance.focus
    if not focus then return end
    ---@cast focus FzfGitStatusEntry

    local filepath = focus.filepath

    if focus.has_merge_conflicts then
      _error("Cannot restore/delete file with merge conflicts " .. filepath)
      return
    end

    local _, status, _ = terminal_utils.system(
      ([[git -C '%s' restore '%s']]):format(opts.git_dir, filepath)
    )
    if status ~= 0 then
      terminal_utils.system_unsafe(([[rm '%s']]):format(filepath))
    end

    instance:refresh()
  end)

  -- TODO: stash message customizability

  instance.layout.main_popup:map("<C-s>", "Stash selected", function()
    instance:selections(function(entries)
      ---@cast entries FzfGitStatusEntry[]
      git_utils.stash({
        git_dir = opts.git_dir,
        gitpaths = tbl_utils.map(entries, function(_, e) return e.gitpath end),
      })
      instance:refresh()
    end)
  end, { force = true })

  instance.layout.main_popup:map("<C-d>", "Stash staged", function()
    git_utils.stash({
      git_dir = opts.git_dir,
      stash_staged = true,
    })
    instance:refresh()
  end, { force = true })

  return instance
end
