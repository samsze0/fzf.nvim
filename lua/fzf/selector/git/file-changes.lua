local FzfTriplePaneCodeDiffInstance =
  require("fzf.instance.triple-pane-code-diff")
local FzfBaseInstanceTrait = require("fzf.instance-trait.base")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf.core.config").value
local lang_utils = require("utils.lang")
local match = lang_utils.match
local files_utils = require("utils.files")
local NuiText = require("nui.text")
local str_utils = require("utils.string")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfGitFileChangesOptions.hl_groups.border_text
---@field added? string
---@field changed? string
---@field deleted? string
---@field normal? string
---@field diff_stat? string

---@class FzfGitFileChangesOptions.hl_groups
---@field border_text? FzfGitFileChangesOptions.hl_groups.border_text

---@class FzfGitFileChangesOptions
---@field git_dir? string
---@field ref string
---@field hl_groups? FzfGitFileChangesOptions.hl_groups

-- Fzf file changes incurred by a git commit, or stash, or any git object
--
---@param opts FzfGitFileChangesOptions
---@return FzfController
return function(opts)
  opts = opts_utils.deep_extend({
    git_dir = git_utils.current_dir(),
    hl_groups = {
      border_text = {
        added = "FzfGitFileChangesBorderAdded",
        changed = "FzfGitFileChangesBorderChanged",
        deleted = "FzfGitFileChangesBorderDeleted",
        normal = "FzfGitFileChangesBorderNormal",
        diff_stat = "FzfGitFileChangesBorderDiffStat",
      },
    },
  }, opts)
  ---@cast opts FzfGitFileChangesOptions

  local instance = FzfTriplePaneCodeDiffInstance.new({
    name = "Git-File-Changes",
  })

  ---@class FzfGitFileChangeEntry : GitChangedFile
  ---@field display string[]

  ---@return FzfGitFileChangeEntry[]
  local entries_getter = function()
    local status = git_utils.list_changed_files({
      git_dir = opts.git_dir,
      ref = opts.ref,
    })

    return tbl_utils.map(status, function(_, e)
      ---@cast e FzfGitFileChangeEntry

      local display = {
        match(e.status, {
          ["A"] = terminal_utils.ansi.blue,
          ["M"] = terminal_utils.ansi.yellow,
          ["D"] = terminal_utils.ansi.red,
        }, terminal_utils.ansi.yellow)(e.status),
        e.gitpath,
      }

      e.display = display

      return e
    end)
  end

  instance:set_entries_getter(entries_getter)

  local border_component_git_status =
    instance.layout.main_popup.bottom_border_text:append("left")
  local border_component_a =
    instance.layout.side_popups.left.top_border_text:prepend("left")
  local border_component_b =
    instance.layout.side_popups.right.top_border_text:prepend("left")

  -- TODO: Reuse this function from status.lua
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
    ---@cast entry FzfGitFileChangeEntry

    if entry.added then
      set_a_border("")
      return {}
    end

    if entry.modified then set_a_border("") end

    if entry.deleted then set_a_border("Deleted", "deleted") end

    local before = git_utils.show_file(entry.gitpath, {
      ref = opts.ref,
      before_ref = true,
      git_dir = opts.git_dir,
    })

    return {
      filetype = files_utils.get_filetype(entry.filepath),
      lines = before or {},
    }
  end

  instance._b_accessor = function(entry)
    ---@cast entry FzfGitFileChangeEntry

    if entry.deleted then
      set_b_border("")
      return {}
    end

    if entry.modified then set_b_border("") end

    if entry.added then set_b_border("Added", "added") end

    local after = git_utils.show_file(entry.gitpath, {
      ref = opts.ref,
      before_ref = false,
      git_dir = opts.git_dir,
    })

    return {
      filetype = files_utils.get_filetype(entry.filepath),
      lines = after or {},
    }
  end

  -- TODO: Reuse this function from status.lua
  instance._picker = function(entry)
    ---@cast entry FzfGitFileChangeEntry

    if entry.deleted then return "a" end

    return "b"
  end

  -- TODO: Reuse this function from status.lua
  instance:on_focus(function(payload)
    local focus = instance.focus
    if not focus then return end
    ---@cast focus FzfGitFileChangeEntry

    if focus.deleted then
      FzfBaseInstanceTrait.setup_scroll_keymaps(
        instance,
        instance.layout.side_popups.a,
        { force = true }
      )
    else
      FzfBaseInstanceTrait.setup_scroll_keymaps(
        instance,
        instance.layout.side_popups.b,
        { force = true }
      )
    end
  end)

  return instance
end
