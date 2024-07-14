local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local timeago = require("utils.timeago")
local notifier = require("notifier")
local fzf_utils = require("fzf.utils")
local config = require("fzf").config
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local lang_utils = require("utils.lang")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf notifications
--
---@alias FzfNotificationsOptions { }
---@param opts? FzfNotificationsOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfNotificationsOptions

  local controller = Controller.new({
    name = "Notifications",
  })

  local layout, popups = helpers.dual_pane_terminal_preview(controller, {
    side_popup = {
      extra_options = {
        win_options = {
          number = true,
          wrap = true,
        },
      },
    },
  })

  ---@alias FzfNotificationEntry { display: string, notification: Notification }
  ---@return FzfNotificationEntry[]
  local entries_getter = function()
    -- Caution: don't call vim.notify here

    local notifications = notifier.all()

    return tbl_utils.map(notifications, function(i, e)
      local icon = lang_utils.match(e.level, {
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
        display = ([[%s %s %s]]):format(icon, timeago(e.time), brief),
        notification = e,
      }
    end)
  end

  controller:set_entries_getter(entries_getter)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus
    ---@cast focus FzfNotificationEntry?

    popups.side:set_lines({})

    if not focus then return end

    popups.side:show_file_content(
      fzf_utils.write_to_tmpfile(focus.notification.message)
    )
  end)

  return controller
end
