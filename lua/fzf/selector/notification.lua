local FzfDualPaneNvimPreviewInstance =
  require("fzf.instance.dual-pane-nvim-preview")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local notifier = require("notifier")
local time_utils = require("utils.time")
local config = require("fzf.core.config").value
local lang_utils = require("utils.lang")
local match = lang_utils.match
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local dbg = require("utils").debug

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfNotificationsOptions.hl_groups.border_text

---@class FzfNotificationsOptions.hl_groups
---@field border_text? FzfNotificationsOptions.hl_groups.border_text

---@class FzfNotificationsOptions
---@field git_dir? string
---@field hl_groups? FzfNotificationsOptions.hl_groups

-- Fzf notifications
--
---@param opts? FzfNotificationsOptions
---@return FzfDualPaneNvimPreviewInstance
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfNotificationsOptions

  local instance = FzfDualPaneNvimPreviewInstance.new({
    name = "Notifications",
  })

  ---@alias FzfNotificationEntry { display: string[], notification: Notification }
  ---@return FzfNotificationEntry[]
  local entries_getter = function()
    -- Caution: don't call vim.notify here

    local notifications = notifier.all()

    return tbl_utils.map(notifications, function(i, e)
      local icon = match(e.level, {
        [vim.log.levels.INFO] = terminal_utils.ansi.blue("󰋼 "),
        [vim.log.levels.WARN] = terminal_utils.ansi.yellow(" "),
        [vim.log.levels.ERROR] = terminal_utils.ansi.red(" "),
        [vim.log.levels.DEBUG] = terminal_utils.ansi.grey(" "),
        [vim.log.levels.TRACE] = terminal_utils.ansi.grey(" "),
      }, terminal_utils.ansi.grey(" "))

      local parts = vim.split(e.message, "\n")
      local brief
      if #parts > 1 then
        brief = parts[1]
      else
        brief = e.message
      end

      return {
        display = {
          icon,
          time_utils.human_readable_diff(e.time),
          brief,
        },
        notification = e,
      }
    end)
  end

  instance:set_entries_getter(entries_getter)
  instance._accessor = function(entry)
    return {
      lines = vim.split(entry.notification.message, "\n"),
    }
  end

  return instance
end
