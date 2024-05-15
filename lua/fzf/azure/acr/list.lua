local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")
local repositories = require("fzf.azure.acr.repositories")
local cache_rules = require("fzf.azure.acr.cache_rules")
local scope_maps = require("fzf.azure.acr.scope_maps")
local tokens = require("fzf.azure.acr.tokens")
local geo_replications = require("fzf.azure.acr.geo_replications")
local network_rules = require("fzf.azure.acr.network_rules")
local tasks = require("fzf.azure.acr.tasks")
local webhooks = require("fzf.azure.acr.webhooks")

local manual = {
  adminUserEnabled = "Indicates whether the admin user is enabled.",
  anonymousPullEnabled = "Indicates whether anonymous pull access is enabled.",
  creationDate = "The date and time when the ACR was created.",
  dataEndpointEnabled = "Indicates whether the data endpoint is enabled.",
  dataEndpointHostNames = "List of data endpoint host names.",
  encryption = {
    keyVaultProperties = "Properties of the KeyVault used for encryption.",
    status = "The status of encryption.",
  },
  id = "The unique identifier for the ACR resource.",
  identity = "The identity associated with the ACR, if any.",
  location = "The location of the ACR.",
  loginServer = "The login server URL of the ACR.",
  name = "The name of the ACR.",
  networkRuleBypassOptions = "Options to bypass network rules.",
  networkRuleSet = "The network rule set applied to the ACR.",
  policies = {
    azureAdAuthenticationAsArmPolicy = {
      status = "The status of Azure AD authentication as ARM policy.",
    },
    exportPolicy = {
      status = "The status of the export policy.",
    },
    quarantinePolicy = {
      status = "The status of the quarantine policy.",
    },
    retentionPolicy = {
      days = "The number of days to retain images for the retention policy.",
      lastUpdatedTime = "The last update time of the retention policy.",
      status = "The status of the retention policy.",
    },
    softDeletePolicy = {
      lastUpdatedTime = "The last update time of the soft delete policy.",
      retentionDays = "The number of days to retain deleted images for the soft delete policy.",
      status = "The status of the soft delete policy.",
    },
    trustPolicy = {
      status = "The status of the trust policy.",
      type = "The type of trust policy.",
    },
  },
  privateEndpointConnections = "List of private endpoint connections associated with the ACR.",
  provisioningState = "The provisioning state of the ACR.",
  publicNetworkAccess = "Indicates whether the ACR is accessible over the public network.",
  resourceGroup = "The resource group in which the ACR is located.",
  sku = {
    name = "The name of the SKU.",
    tier = "The tier of the SKU.",
  },
  status = "The status of the ACR.",
  systemData = {
    createdAt = "The creation date and time of the ACR.",
    createdBy = "The email of the user who created the ACR.",
    createdByType = "The type of the creator.",
    lastModifiedAt = "The last modification date and time of the ACR.",
    lastModifiedBy = "The email of the user who last modified the ACR.",
    lastModifiedByType = "The type of the last modifier.",
  },
  tags = "The tags associated with the ACR.",
  type = "The resource type of the ACR.",
  zoneRedundancy = "The zone redundancy status of the ACR.",
}

-- Fzf all azure container registries under the current subscription,
-- or resource group if `resource_group` option is provided
--
---@param opts? { resource_group?: string, parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azure_container_registry { adminUserEnabled: string, anonymousPullEnabled: string, creationDate: string, dataEndpointEnabled: string, dataEndpointHostNames: string[], encryption: { keyVaultProperties: string, status: string }, id: string, identity: string, location: string, loginServer: string, name: string, networkRuleBypassOptions: string, networkRuleSet: string, policies: { azureAdAuthenticationAsArmPolicy: { status: string }, exportPolicy: { status: string }, quarantinePolicy: { status: string }, retentionPolicy: { days: string, lastUpdatedTime: string, status: string }, softDeletePolicy: { lastUpdatedTime: string, retentionDays: string, status: string }, trustPolicy: { status: string, type: string } }, privateEndpointConnections: string[], provisioningState: string, publicNetworkAccess: string, resourceGroup: string, sku: { name: string, tier: string }, status: string, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, tags: string, type: string, zoneRedundancy: string }
  ---@type azure_container_registry[]
  local registries

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = "az acr list"
    if opts.resource_group then
      command = command .. " --resource-group " .. opts.resource_group
    end
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error("Fail to retrieve azure container registries", result)
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    registries = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast registries azure_container_registry[]

    return utils.map(
      registries,
      function(i, registry)
        return fzf_utils.join_by_delim(
          utils.ansi_codes.grey(string.format("[%s]", registry.resourceGroup)),
          registry.name,
          utils.ansi_codes.grey(registry.location)
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-Container-Registries",
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
        local registry = registries[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. registry.name .. " ")

        set_preview_content(vim.split(vim.inspect(registry), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local registry = registries[state.focused_entry_index]
        vim.fn.setreg("+", registry.id)
        vim.notify(string.format([[Copied %s to clipboard]], registry.id))
      end,
      ["ctrl-l"] = function(state)
        local registry = registries[state.focused_entry_index]

        local command = string.format("az acr login --name %s", registry.name)
        if true then
          vim.fn.setreg("+", command)
          vim.notify(string.format([[Copied %s to clipboard]], command))
          return
        end

        local output = vim.fn.system(command)
        if vim.v.shell_error ~= 0 then
          _error("Fail to login to azure container registry", output)
          return
        end
        _info("Logged in to azure container registry", registry.name)
      end,
      ["ctrl-r"] = function(state)
        local registry = registries[state.focused_entry_index]
        geo_replications(registry.name, { parent_state = state.id })
      end,
      ["ctrl-h"] = function(state)
        local registry = registries[state.focused_entry_index]
        webhooks(registry, { parent_state = state.id })
      end,
      ["ctrl-n"] = function(state)
        local registry = registries[state.focused_entry_index]
        network_rules(registry.name, { parent_state = state.id })
      end,
      ["ctrl-i"] = function(state)
        local registry = registries[state.focused_entry_index]
        repositories(registry.name, { parent_state = state.id })
      end,
      ["ctrl-c"] = function(state)
        local registry = registries[state.focused_entry_index]
        cache_rules(registry, { parent_state = state.id })
      end,
      ["ctrl-m"] = function(state)
        local registry = registries[state.focused_entry_index]
        scope_maps(registry.name, { parent_state = state.id })
      end,
      ["ctrl-t"] = function(state)
        local registry = registries[state.focused_entry_index]
        tasks(registry, { parent_state = state.id })
      end,
      ["ctrl-g"] = function(state)
        local registry = registries[state.focused_entry_index]
        tokens(registry, { parent_state = state.id })
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
