local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf").config

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- TODO: remove delete files and submodules from git files
-- TODO: use git ls-tree and display as tree?

-- Fzf all files in the given git directory.
-- If git_dir is nil, then fzf all files in the current directory.
--
---@alias FzfFilesOptions { git_dir?: string }
---@param opts? FzfFilesOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({
    git_dir = git_utils.current_dir(),
  }, opts)
  ---@cast opts FzfFilesOptions

  local controller = Controller.new({
    name = "Files",
  })

  local layout, popups = helpers.dual_pane_code_preview(controller, {
    highlight_pos = false,
    filepath_accessor = function(focus) return focus.path end,
  })

  ---@alias FzfFileEntry { display: string, path: string, git_path?: string }
  ---@return FzfFileEntry[]
  local entries_getter = function()
    local files
    if opts.git_dir then
      files = git_utils.files(opts.git_dir)
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

  controller:set_entries_getter(entries_getter)

  return controller
end
