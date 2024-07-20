local FzfDualPaneLuaObjectPreviewInstance =
  require("fzf.instance.dual-pane-lua-object-preview")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local git_utils = require("utils.git")
local config = require("fzf.core.config").value
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local dbg = require("utils").debug
local docker_utils = require("utils.docker")
local lang_utils = require("utils.lang")
local match = lang_utils.match

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfDockerContainerOptions.hl_groups.border_text

---@class FzfDockerContainerOptions.hl_groups
---@field border_text? FzfDockerContainerOptions.hl_groups.border_text

---@class FzfDockerContainerOptions
---@field git_dir? string
---@field hl_groups? FzfDockerContainerOptions.hl_groups

-- TODO: watch for changes in background

-- Fzf docker containers
--
---@param opts? FzfDockerContainerOptions
---@return FzfDualPaneLuaObjectPreviewInstance
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfDockerContainerOptions

  local instance = FzfDualPaneLuaObjectPreviewInstance.new({
    name = "Docker-Containers",
  })

  ---@alias FzfDockerContainersEntry { display: string[], container: DockerContainer }
  ---@return FzfDockerContainersEntry[]
  local entries_getter = function()
    return tbl_utils.map(
      docker_utils.containers({
        all = true,
      }),
      function(i, e)
        return {
          display = {
            match(e.State, {
              ["exited"] = terminal_utils.ansi.grey(" "),
              ["running"] = terminal_utils.ansi.blue(" "),
            }, terminal_utils.ansi.red("??")),
            terminal_utils.ansi.blue(e.Image),
            e.Names,
          },
          container = e,
        }
      end
    )
  end

  instance:set_entries_getter(entries_getter)
  instance._accessor = function(entry) return entry.container end

  instance.layout.main_popup:map("<C-y>", "Copy container ID", function()
    local focus = instance.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    vim.fn.setreg("+", focus.container.ID)
    _info(([[Copied %s to clipboard]]):format(focus.container.ID))
  end)

  instance.layout.main_popup:map("<C-x>", "Delete container", function()
    local focus = instance.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    if focus.container.State == "running" then
      _error("Cannot delete running container")
      return
    end

    terminal_utils.system_unsafe(
      ([[docker container rm %s]]):format(focus.container.ID)
    )
    instance:refresh({ force_fetch = true })
  end)

  instance.layout.main_popup:map("<Left>", "Start container", function()
    local focus = instance.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    if focus.container.State == "running" then
      _warn("Container is already running")
      return
    end

    terminal_utils.system_unsafe(
      ([[docker container start %s]]):format(focus.container.ID)
    )
    instance:refresh({ force_fetch = true })
  end)

  instance.layout.main_popup:map("<Right>", "Stop container", function()
    local focus = instance.focus
    ---@cast focus FzfDockerContainersEntry?

    if not focus then return end

    if focus.container.State == "exited" then
      _error("Container is already stopped")
      return
    end

    terminal_utils.system_unsafe(
      ([[docker container stop %s]]):format(focus.container.ID)
    )
    instance:refresh({ force_fetch = true })
  end)

  return instance
end
