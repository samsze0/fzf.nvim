local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local timeago = require("utils.timeago")
local notifier = require("notifier")
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

  ---@alias FzfNotificationEntry { display: string, notification: Notification }
  ---@return FzfNotificationEntry[]
  local entries_getter = function()
    -- Caution: don't call vim.notify here

    local notifications = notifier.all()

    return utils.map(notifications, function(i, e)
      local icon = utils.switch(e.level, {
        [vim.log.levels.INFO] = utils.ansi_codes.blue("󰋼 "),
        [vim.log.levels.WARN] = utils.ansi_codes.yellow(" "),
        [vim.log.levels.ERROR] = utils.ansi_codes.red(" "),
        [vim.log.levels.DEBUG] = utils.ansi_codes.grey(" "),
        [vim.log.levels.TRACE] = utils.ansi_codes.grey(" "),
      }, utils.ansi_codes.grey(" "))

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
          brief
        ),
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
