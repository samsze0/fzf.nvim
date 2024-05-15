local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  actions = "List of actions allowed under this scope map. Actions typically include permissions to read, write, delete, etc., on repositories.",
  creationDate = "The date and time when the scope map was created.",
  description = "A brief description of what this scope map allows.",
  id = "The unique identifier for this scope map within Azure resources.",
  name = "The name of the scope map.",
  provisioningState = "The state of provisioning for this scope map, indicating whether it's succeeded, failed, etc.",
  resourceGroup = "The name of the Azure resource group where this scope map is located.",
  systemData = {
    createdAt = "The date and time when the scope map was initially created.",
    createdBy = "The email or identifier of the user who created the scope map.",
    createdByType = "Indicates the type of user who created the scope map (e.g., User, Application, ManagedIdentity).",
    lastModifiedAt = "The date and time when the scope map was last modified.",
    lastModifiedBy = "The email or identifier of the user who last modified the scope map.",
    lastModifiedByType = "Indicates the type of user who last modified the scope map (e.g., User, Application, ManagedIdentity).",
  },
  type = "The resource type of the scope map within Azure.",
  typePropertiesType = "Indicates the type of the properties for the scope map. 'UserDefined' means the scope map properties are defined by the user.",
}

-- Fzf all scope maps under the acr.
--
---@param acr string
---@param opts? { parent_state?: string }
return function(acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_scope_map { actions: string[], creationDate: string, description: string, id: string, name: string, provisioningState: string, resourceGroup: string, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, type: string, typePropertiesType: string }
  ---@type acr_scope_map[]
  local scope_maps

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az acr scope-map list -r %s", acr)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve scope maps under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)
    scope_maps = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast scope_maps acr_scope_map[]

    return utils.map(
      scope_maps,
      function(i, scope_map) return fzf_utils.join_by_delim(scope_map.name) end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Scope-Maps",
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
        local scope_map = scope_maps[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. scope_map.name .. " ")

        set_preview_content(vim.split(vim.inspect(scope_map), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local scope_map = scope_maps[state.focused_entry_index]
        vim.fn.setreg("+", scope_map.id)
        vim.notify(string.format([[Copied %s to clipboard]], scope_map.id))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
