local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local timeago = require("utils.timeago")
local noti = require("noti")
local fzf_utils = require("fzf.utils")
local config = require("fzf").config

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf notifications
--
---@alias FzfNotificationsOptions { }
---@param opts? FzfNotificationsOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
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

  ---@alias FzfNotificationEntry { display: string, notification: Notification, unread: boolean }
  ---@return FzfNotificationEntry[]
  local entries_getter = function()
    -- Caution: don't call vim.notify here

    local notifications = noti.all()
    local num_unread = noti.num_unread()
    noti.clear_unread()

    return utils.map(notifications, function(i, e)
      local unread = i <= num_unread

      local icon = utils.switch(e.level, {
        [vim.log.levels.INFO] = unread and utils.ansi_codes.blue("󰋼 ")
          or "󰋼 ",
        [vim.log.levels.WARN] = unread and utils.ansi_codes.yellow(" ")
          or " ",
        [vim.log.levels.ERROR] = unread and utils.ansi_codes.red(" ")
          or " ",
        [vim.log.levels.DEBUG] = unread and utils.ansi_codes.grey(" ")
          or " ",
        [vim.log.levels.TRACE] = unread and utils.ansi_codes.grey(" ")
          or " ",
      }, unread and utils.ansi_codes.grey(" ") or " ")

      local parts = vim.split(e.message, "\n")
      local brief
      if #parts > 1 then
        brief = parts[1]
      else
        brief = e.message
      end

      return {
        display = ([[%s %s %s]]):format(
          icon,
          timeago(e.time),
          unread and utils.ansi_codes.white(brief) or brief
        ),
        notification = e,
        unread = unread,
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
