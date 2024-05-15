local Controller = require("fzf.core.controllers").Controller
local helpers = require("fzf.helpers")
local utils = require("utils")
local git_utils = require("utils.git")
local jumplist = require("jumplist")
local config = require("fzf").config
local fzf_utils = require("fzf.utils")
local docker_utils = require("utils.docker")

-- TODO: watch for changes in background

-- Fzf docker images
--
---@alias FzfDockerImageOptions { }
---@param opts? FzfDockerImageOptions
---@return FzfController
return function(opts)
  opts = utils.opts_extend({}, opts)
  ---@cast opts FzfDockerImageOptions

  local controller = Controller.new({
    name = "Docker-Images",
  })

  local layout, popups = helpers.dual_pane_lua_object_preview(controller, {
    lua_object_accessor = function(focus) return focus.image end,
  })

  ---@alias FzfDockerImagesEntry { display: string, image: DockerImage }
  ---@return FzfDockerImagesEntry[]
  local entries_getter = function()
    return utils.map(
      docker_utils.docker_images({
        all = true,
      }),
      function(i, e)
        return {
          display = fzf_utils.join_by_nbsp(e.Repository, e.Tag),
          image = e,
        }
      end
    )
  end

  controller:set_entries_getter(entries_getter)

  popups.main:map("<C-y>", "Copy ID", function()
    local focus = controller.focus
    ---@cast focus FzfDockerImagesEntry?

    if not focus then return end

    vim.fn.setreg("+", focus.image.ID)
    vim.info(([[Copied %s to clipboard]]):format(focus.image.ID))
  end)

  popups.main:map("<C-x>", "Delete", function()
    local focus = controller.focus
    ---@cast focus FzfDockerImagesEntry?

    if not focus then return end

    utils.system(([[docker image rm %s]]):format(focus.image.ID))
    controller:refresh()
  end)

  return controller
end
