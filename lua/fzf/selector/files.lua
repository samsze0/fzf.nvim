local FzfDualPaneNvimPreviewInstance =
  require("fzf.instance.dual-pane-nvim-preview")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf.core.config").value
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local dbg = require("utils").debug

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- TODO: remove delete files and submodules from git files

---@class FzfFilesOptions.hl_groups.border_text

---@class FzfFilesOptions.hl_groups
---@field border_text? FzfFilesOptions.hl_groups.border_text

---@class FzfFilesOptions
---@field git_dir? string
---@field hl_groups? FzfFilesOptions.hl_groups

-- Fzf all files in the given git directory.
-- If git_dir is nil, then fzf all files in the current directory.
--
---@param opts? FzfFilesOptions
---@return FzfDualPaneNvimPreviewInstance
return function(opts)
  opts = opts_utils.deep_extend({
    git_dir = git_utils.current_dir(),
    hl_groups = {
      border_text = {},
    },
  }, opts)
  ---@cast opts FzfFilesOptions

  local instance = FzfDualPaneNvimPreviewInstance.new({
    name = "Files",
  })

  ---@alias FzfFileEntry { display: string, path: string, git_path?: string }
  ---@return FzfFileEntry[]
  local entries_getter = function()
    local files
    if opts.git_dir then
      files = git_utils.files(opts.git_dir, {
        filter_unreadable = true,
      })
    else
      if vim.fn.executable("fd") ~= 1 then error("fd is not installed") end
      files = terminal_utils.systemlist_unsafe(
        "fd --type f --no-ignore --hidden --follow --exclude .git"
      )
    end
    ---@cast files string[]
    -- files = utils.sort_by_files(files)

    return tbl_utils.map(files, function(i, file)
      local path, git_path
      if opts.git_dir then
        path = vim.fn.fnamemodify(opts.git_dir .. "/" .. file, ":.")
        git_path = file
      else
        path = file
      end

      return {
        display = file,
        path = path,
        git_path = git_path,
      }
    end)
  end

  instance:set_entries_getter(entries_getter)
  instance._accessor = function(entry)
    return {
      filepath = entry.path,
    }
  end

  return instance
end
