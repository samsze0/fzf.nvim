local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  changeableAttributes = {
    deleteEnabled = "Indicates if delete operation is enabled for the repository.",
    listEnabled = "Indicates if listing operation is enabled for the repository.",
    readEnabled = "Indicates if read operation is enabled for the repository.",
    writeEnabled = "Indicates if write operation is enabled for the repository.",
  },
  createdTime = "The timestamp when the repository was created.",
  imageName = "The name of the image stored in the repository.",
  lastUpdateTime = "The timestamp when the repository was last updated.",
  manifestCount = "The number of manifests in the repository.",
  registry = "The registry URL where the repository is hosted.",
  tagCount = "The number of tags in the repository.",
}

-- Fzf all repositories (images) under the acr.
--
---@param acr string
---@param opts? { parent_state?: string }
return function(acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_repository { changeableAttributes: { deleteEnabled: string, listEnabled: string, readEnabled: string, writeEnabled: string }, createdTime: string, imageName: string, lastUpdateTime: string, manifestCount: number, registry: string, tagCount: number }
  ---@type acr_repository[]
  local repositories

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az acr repository list --name %s", acr)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve repositories under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)
    local repository_names = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast repository_names string[]

    repositories = utils.map(repository_names, function(_, repo_name)
      local result = vim.fn.system(
        string.format(
          "az acr repository show --name %s --repository %s",
          acr,
          repo_name
        )
      )
      if vim.v.shell_error ~= 0 then
        _error(
          "Fail to retrieve repository info for",
          repo_name,
          "under the azure container registry",
          result
        )
        return {}
      end
      return json.parse(result) ---@diagnostic disable-line: cast-local-type

      -- TODO: also fetch the tags with the `show-tags` subcommand?
      -- TODO: fetch info of all repositories in parallel
    end)

    ---@cast repositories acr_repository[]

    return utils.map(
      repositories,
      function(i, repo) return fzf_utils.join_by_delim(repo.imageName) end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Repositories",
    layout = layout,
    main_popup = popups.main,
    binds = {
      ["+before-start"] = function(state)
        helpers.set_keymaps_for_preview_remote_nav(
          popups.main,
          popups.nvim_preview
        )
        helpers.set_keymaps_for_popups_nav({
          { popup = popups.main, key = "<C-s>", is_terminal = true },
          { popup = popups.nvim_preview, key = "<C-f>", is_terminal = false },
        })
      end,
      ["focus"] = function(state)
        local repo = repositories[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. repo.imageName .. " ")

        set_preview_content(vim.split(vim.inspect(repo), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local repo = repositories[state.focused_entry_index]
        vim.fn.setreg("+", repo.imageName)
        vim.notify(string.format([[Copied %s to clipboard]], repo.imageName))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
