local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local git_utils = require("utils.git")
local fzf_utils = require("fzf.utils")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local str_utils = require("utils.string")
local vimdiff_utils = require("utils.vimdiff")
local terminal_utils = require("utils.terminal")
local jumplist = require("jumplist")
local config = require("fzf").config

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf git status
--
---@alias FzfGitStatusOptions { git_dir?: string }
---@param opts? FzfGitStatusOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({
    git_dir = git_utils.current_dir(),
  }, opts)
  ---@cast opts FzfGitStatusOptions

  local controller = Controller.new({
    name = "Git-Status",
  })

  local current_gitpath =
    git_utils.convert_filepath_to_gitpath(controller:prev_filepath())

  local layout, popups = helpers.triple_pane_code_diff(controller)

  ---@alias FzfGitStatusEntry { display: string, initial_focus: boolean, gitpath: string, filepath: string, status: string, status_x: string, status_y: string, is_fully_staged: boolean, is_partially_staged: boolean, is_untracked: boolean, unstaged: boolean, has_merge_conflicts: boolean, worktree_clean: boolean, added: boolean, deleted: boolean, renamed: boolean, copied: boolean, type_changed: boolean, ignored: boolean }
  ---@return FzfGitStatusEntry[]
  local entries_getter = function()
    local entries = terminal_utils.systemlist_unsafe(
      ([[git -C '%s' -c color.status=false status -su]]):format(opts.git_dir), -- Show in short format and show all untracked files
      {
        keepempty = false,
        trim = false, -- Can mess up status
      }
    )

    -- entries = file_utils.sort(entries, function(e) return e:sub(4) end)

    return tbl_utils.map(entries, function(i, e)
      local status = e:sub(1, 2)
      local gitpath = e:sub(4)
      local filepath = opts.git_dir .. "/" .. gitpath

      -- TODO: cater if git status entry is "rename" i.e. xxx -> xxx

      if status == "??" then status = " ?" end

      local status_x = status:sub(1, 1)
      local status_y = status:sub(2, 2)

      local display = ([[%s %s]]):format(
        terminal_utils.ansi.blue(status_x),
        lang_utils.match(status_y, {
          ["D"] = terminal_utils.ansi.red,
        }, terminal_utils.ansi.yellow)(status_y)
      )

      display = fzf_utils.join_by_nbsp(display, gitpath)

      local is_fully_staged = status_x == "M" and status_y == " "
      local is_partially_staged = status_x == "M" and status_y == "M"
      local is_untracked = status_y == "?"
      local unstaged = status_x == " " and not is_untracked
      local has_merge_conflicts = status_x == "U"
      local worktree_clean = status_y == " "

      local added = status_x == "A" and worktree_clean
      local deleted = status_x == "D" or status_y == "D"
      local renamed = status_x == "R" and worktree_clean
      local copied = status_x == "C" and worktree_clean
      local type_changed = status_x == "T" and worktree_clean

      local ignored = status_x == "!" and status_y == "!"

      return {
        display = display,
        initial_focus = current_gitpath == gitpath,
        gitpath = gitpath,
        filepath = filepath,
        status = status,
        status_x = status_x,
        status_y = status_y,
        is_fully_staged = is_fully_staged,
        is_partially_staged = is_partially_staged,
        is_untracked = is_untracked,
        unstaged = unstaged,
        worktree_clean = worktree_clean,
        has_merge_conflicts = has_merge_conflicts,
        added = added,
        deleted = deleted,
        renamed = renamed,
        copied = copied,
        type_changed = type_changed,
        ignored = ignored,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfGitStatusEntry?

    -- Reset the side panes
    popups.side.left:set_lines({})
    popups.side.right:set_lines({})

    if not focus then return end

    local filepath = focus.filepath
    local gitpath = focus.gitpath

    local get_last_commit = function()
      return terminal_utils.systemlist_unsafe(
        ("git -C '%s' show HEAD:'%s'"):format(opts.git_dir, gitpath)
      )
    end

    local get_staged = function()
      return terminal_utils.systemlist_unsafe(
        ("git -C '%s' show :'%s'"):format(opts.git_dir, gitpath)
      )
    end

    if focus.renamed then
      popups.side.right:show_file_content(filepath)
    elseif focus.added or focus.is_untracked then
      popups.side.right:show_file_content(filepath)
    elseif focus.deleted then
      local last_commit = get_last_commit()

      popups.side.left:set_lines(last_commit)

      local filename = vim.fn.fnamemodify(filepath, ":t")
      local ft = vim.filetype.match({
        filename = filename,
        contents = last_commit,
      })
      vim.bo[popups.side.left.bufnr].filetype = ft or ""
    elseif focus.is_fully_staged then
      local last_commit = get_last_commit()

      popups.side.right:show_file_content(filepath)

      popups.side.left:set_lines(last_commit)
      local filename = vim.fn.fnamemodify(filepath, ":t")
      local ft = vim.filetype.match({
        filename = filename,
        contents = last_commit,
      })
      vim.bo[popups.side.left.bufnr].filetype = ft or ""
    else -- Not fully staged
      local staged = get_staged()

      popups.side.left:set_lines(staged)
      local filename = vim.fn.fnamemodify(filepath, ":t")
      local ft = vim.filetype.match({
        filename = filename,
        contents = staged,
      })
      vim.bo[popups.side.left.bufnr].filetype = ft or ""

      popups.side.right:show_file_content(filepath)
    end

    vimdiff_utils.diff_bufs(popups.side.left.bufnr, popups.side.right.bufnr)
  end)

  popups.main:map("<C-y>", "Copy filepath", function()
    if not controller.focus then return end

    local path = controller.focus.filepath
    vim.fn.setreg("+", path)
    _info(([[Copied %s to clipboard]]):format(path))
  end)

  popups.main:map("<C-r>", "Refresh", function() controller:refresh() end)

  popups.main:map("<Left>", "Stage", function()
    if not controller.focus then return end

    local filepath = controller.focus.filepath
    terminal_utils.system_unsafe(([[git -C '%s' add '%s']]):format(opts.git_dir, filepath))
    controller:refresh()
  end)

  popups.main:map("<Right>", "Unstage", function()
    if not controller.focus then return end

    local filepath = controller.focus.filepath
    terminal_utils.system_unsafe(
      ([[git -C '%s' restore --staged '%s']]):format(opts.git_dir, filepath)
    )
    controller:refresh()
  end)

  popups.main:map("<C-x>", "Restore", function()
    if not controller.focus then return end

    local filepath = controller.focus.filepath
    local focus = controller.focus
    ---@cast focus FzfGitStatusEntry

    if focus.has_merge_conflicts then
      _error("Cannot restore/delete file with merge conflicts", filepath)
      return
    end

    local _, status, _ = terminal_utils.system(
      ([[git -C '%s' restore '%s']]):format(opts.git_dir, filepath)
    )
    if status ~= 0 then
      terminal_utils.system_unsafe(([[rm '%s']]):format(filepath))
    end

    controller:refresh()
  end)

  popups.main:map("<C-s>", "Stash selected", function()
    controller:selections(function(entries)
      if not entries then return end

      local paths = str_utils.join(entries, function(_, e)
        ---@cast e FzfGitStatusEntry
        return "'" .. e.gitpath .. "'"
      end)
      -- TODO: make stash message customizable
      terminal_utils.system_unsafe(
        ([[git -C '%s' stash push -m %s -- %s]]):format(
          opts.git_dir,
          "TODO",
          paths
        )
      )
      controller:refresh()
    end)
  end)

  popups.main:map("<C-d>", "Stash staged", function()
    -- TODO: make stash message customizable
    terminal_utils.system_unsafe(
      ([[git -C '%s' stash push -m %s --staged]]):format(opts.git_dir, "TODO")
    )
    controller:refresh()
  end)

  popups.main:map("<CR>", "Goto file", function()
    if not controller.focus then return end

    local focus = controller.focus
    ---@cast focus FzfGitStatusEntry

    local path = focus.filepath

    -- TODO: Add a check for merge conflicts. And open a window for diffing

    controller:hide()
    jumplist.save()
    vim.cmd(([[e %s]]):format(path))
  end)

  return controller
end
