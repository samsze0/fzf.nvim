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

-- TODO: watch for changes in background

---@class FzfDockerImageOptions.hl_groups.border_text

---@class FzfDockerImageOptions.hl_groups
---@field border_text? FzfDockerImageOptions.hl_groups.border_text

---@class FzfDockerImageOptions
---@field git_dir? string
---@field hl_groups? FzfDockerImageOptions.hl_groups

-- Fzf docker images
--
---@param opts? FzfDockerImageOptions
---@return FzfDualPaneLuaObjectPreviewInstance
return function(opts)
  opts = opts_utils.extend({}, opts)
  ---@cast opts FzfDockerImageOptions

  local instance = FzfDualPaneLuaObjectPreviewInstance.new({
    name = "Docker-Images",
  })

  ---@alias FzfDockerImagesEntry { display: string[], image: DockerImage }
  ---@return FzfDockerImagesEntry[]
  local entries_getter = function()
    return tbl_utils.map(
      docker_utils.images({
        all = true,
      }),
      function(i, e)
        return {
          display = { terminal_utils.ansi.blue(e.Repository), e.Tag },
          image = e,
        }
      end
    )
  end

  instance:set_entries_getter(entries_getter)
  instance._accessor = function(entry) return entry.image end

  instance.layout.main_popup:map("<C-y>", "Copy image ID", function()
    local focus = instance.focus
    ---@cast focus FzfDockerImagesEntry?

    if not focus then return end

    vim.fn.setreg("+", focus.image.ID)
    _info(([[Copied %s to clipboard]]):format(focus.image.ID))
  end)

  instance.layout.main_popup:map("<C-x>", "Delete image", function()
    local focus = instance.focus
    ---@cast focus FzfDockerImagesEntry?

    if not focus then return end

    terminal_utils.system_unsafe(
      ([[docker image rm %s]]):format(focus.image.ID)
    )
    instance:refresh()
  end)

  return instance
end
