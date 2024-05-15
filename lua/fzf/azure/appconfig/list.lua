local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")
local keyvalue_pairs = require("fzf.azure.appconfig.key-value-pairs")
local features = require("fzf.azure.appconfig.features")
local snapshots = require("fzf.azure.appconfig.snapshots")
local credentials = require("fzf.azure.appconfig.credentials")

local manual = {
  createMode = "Specifies how the configuration store was created.",
  creationDate = "The date and time the configuration store was created.",
  disableLocalAuth = "Indicates whether local authentication methods are disabled.",
  enablePurgeProtection = "Indicates whether purge protection is enabled for the configuration store.",
  encryption = {
    keyVaultProperties = "Properties for Key Vault encryption of the configuration store.",
  },
  endpoint = "The endpoint URL of the configuration store.",
  id = "The unique identifier of the configuration store resource.",
  identity = "The identity of the configuration store, for use with Azure resources.",
  location = "The Azure region where the configuration store is located.",
  name = "The name of the configuration store.",
  privateEndpointConnections = "Private endpoint connections to the configuration store.",
  provisioningState = "The provisioning state of the configuration store.",
  publicNetworkAccess = "Specifies if the configuration store is accessible from the public network.",
  resourceGroup = "The name of the resource group the configuration store belongs to.",
  sku = {
    name = "The SKU name of the configuration store (e.g., free, standard).",
  },
  softDeleteRetentionInDays = "The number of days to retain a deleted configuration store before permanently deleting it.",
  systemData = {
    createdAt = "The date and time the resource was created.",
    createdBy = "The identity that created the resource.",
    createdByType = "The type of identity that created the resource (e.g., User, Application).",
    lastModifiedAt = "The date and time the resource was last modified.",
    lastModifiedBy = "The identity that last modified the resource.",
    lastModifiedByType = "The type of identity that last modified the resource (e.g., User, Application).",
  },
  tags = "The tags applied to the configuration store.",
  type = "The type of the Azure resource (Microsoft.AppConfiguration/configurationStores).",
}

-- Fzf all azure app-configs under the current subscription,
-- or resource group if `resource_group` option is provided
--
---@param opts? { resource_group?: string, parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azure_appconfig { createMode: string, creationDate: string, disableLocalAuth: boolean, enablePurgeProtection: boolean, encryption: { keyVaultProperties: string }, endpoint: string, id: string, identity: string, location: string, name: string, privateEndpointConnections: string, provisioningState: string, publicNetworkAccess: string, resourceGroup: string, sku: { name: string }, softDeleteRetentionInDays: number, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, tags: string, type: string }
  ---@type azure_appconfig[]
  local appconfigs

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = "az appconfig list"
    if opts.resource_group then
      command = command .. " --resource-group " .. opts.resource_group
    end
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error("Fail to retrieve azure app-configs", result)
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    appconfigs = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast appconfigs azure_appconfig[]

    return utils.map(
      appconfigs,
      function(i, conf) return fzf_utils.join_by_delim(conf.name) end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-App-Configs",
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
        local conf = appconfigs[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. conf.name .. " ")

        set_preview_content(vim.split(vim.inspect(conf), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        vim.fn.setreg("+", conf.id)
        vim.notify(string.format([[Copied %s to clipboard]], conf.id))
      end,
      ["ctrl-k"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        keyvalue_pairs(conf, { parent_state = state.id })
      end,
      ["ctrl-g"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        -- Geo-replications
      end,
      ["ctrl-r"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        -- Revisions
      end,
      ["ctrl-x"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        -- Delete
      end,
      ["ctrl-d"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        -- Purge
      end,
      ["ctrl-v"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        -- Recover
      end,
      ["ctrl-p"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        features(conf, { parent_state = state.id })
      end,
      ["ctrl-o"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        snapshots(conf, { parent_state = state.id })
      end,
      ["ctrl-c"] = function(state)
        local conf = appconfigs[state.focused_entry_index]
        credentials(conf, { parent_state = state.id })
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
