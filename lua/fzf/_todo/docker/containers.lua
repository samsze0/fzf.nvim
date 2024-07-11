local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local docker_utils = require("utils.docker")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- TODO: watch for changes in background

-- Fzf docker containers
--
---@alias FzfDockerContainerOptions { }
---@param opts? FzfDockerContainerOptions
---@return FzfController
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfDockerContainerOptions

  local controller = Controller.new({
    name = "Docker-Containers",
  })

  local layout, popups = helpers.dual_pane_lua_object_preview(controller, {
    lua_object_accessor = function(focus) return focus.container end,
  })

  ---@alias FzfDockerContainersEntry { display: string, container: DockerContainer }
  ---@return FzfDockerContainersEntry[]
  local entries_getter = function()
    return tbl_utils.map(
      docker_utils.docker_containers({
        all = true,
      }),
      function(i, e)
        return {
          display = fzf_utils.join_by_nbsp(
            lang_utils.match(e.Controller, {
              ["exited"] = terminal_utils.ansi.grey(" "),
              ["running"] = terminal_utils.ansi.blue(" "),
            }, terminal_utils.ansi.red("??")),
            terminal_utils.ansi.blue(e.Image),
            e.Names
          ),
          container = e,
        }
      end
    )
  end

  controller:set_entries_getter(entries_getter)

  popups.main:map("<C-y>", "Copy ID", function()
    local focus = controller.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    vim.fn.setreg("+", focus.container.ID)
    _info(([[Copied %s to clipboard]]):format(focus.container.ID))
  end)

  popups.main:map("<C-x>", "Delete", function()
    local focus = controller.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    if focus.container.Status == "running" then
      _error("Cannot delete running container")
      return
    end

    terminal_utils.system_unsafe(([[docker container rm %s]]):format(focus.container.ID))
    controller:refresh()
  end)

  popups.main:map("<Left>", "Start", function()
    local focus = controller.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    if focus.container.Status == "running" then
      _warn("Container is already running")
      return
    end

    terminal_utils.system_unsafe(([[docker container start %s]]):format(focus.container.ID))
    controller:refresh()
  end)

  popups.main:map("<Right>", "Stop", function()
    local focus = controller.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    if focus.container.Status == "exited" then
      _error("Container is already stopped")
      return
    end

    terminal_utils.system_unsafe(([[docker container stop %s]]):format(focus.container.ID))
    controller:refresh()
  end)

  return controller
end
