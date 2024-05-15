local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  actions = "The actions that trigger the webhook, such as 'push' and 'delete'.",
  id = "The fully qualified ID of the webhook.",
  location = "The location of the Azure resource, e.g., 'eastus'.",
  name = "The name of the webhook.",
  provisioningState = "The provisioning state of the webhook, e.g., 'Succeeded'.",
  resourceGroup = "The name of the resource group within which the webhook is located.",
  scope = "The scope of repositories for which the webhook gets triggered.",
  status = "The status of the webhook, e.g., 'enabled'.",
  systemData = {
    createdAt = "The timestamp when the webhook was created.",
    createdBy = "The identifier of the creator of the webhook.",
    createdByType = "The type of the creator, e.g., 'User'.",
    lastModifiedAt = "The timestamp when the webhook was last modified.",
    lastModifiedBy = "The identifier of the last user or system that modified the webhook.",
    lastModifiedByType = "The type of the last modifier, e.g., 'User'.",
  },
  tags = "A collection of tags associated with the webhook.",
  type = "The type of the Azure resource, e.g., 'Microsoft.ContainerRegistry/registries/webhooks'.",
  config = {
    customHeaders = "The custom headers that will be added to the webhook notifications.",
    serviceUri = "The service URI for the webhook.",
  },
}

-- Fzf all webhooks under the acr.
--
---@param acr azure_container_registry
---@param opts? { parent_state?: string }
return function(acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_webhook { actions: string[], id: string, location: string, name: string, provisioningState: string, resourceGroup: string, scope: string, status: string, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, tags: table<string, string>, type: string, config: { customHeaders: table<string, string>, serviceUri: string } }
  ---@type acr_webhook[]
  local webhooks

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az acr webhook list -r %s", acr.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve webhooks under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)

    webhooks = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast webhooks acr_webhook[]

    -- TODO: fetch details for each webhook in parallel
    webhooks = utils.map(webhooks, function(i, hook)
      local command = string.format(
        [[az acr webhook get-config -n %s -r %s]],
        hook.name,
        acr.name
      )
      local result = vim.fn.system(command)
      if vim.v.shell_error ~= 0 then
        _error(
          "Fail to retrieve webhook details for webhook",
          hook.name,
          result
        )
        return hook
      end

      hook["config"] = json.parse(result) ---@diagnostic disable-line: assign-type-mismatch
      return hook
    end)

    return utils.map(
      webhooks,
      function(i, hook)
        return fzf_utils.join_by_delim(
          hook.status == "enabled" and hook.name
            or utils.ansi_codes.grey(hook.name)
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Webhooks",
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
        local hook = webhooks[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. hook.name .. " ")

        set_preview_content(vim.split(vim.inspect(hook), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local hook = webhooks[state.focused_entry_index]
        vim.fn.setreg("+", hook.id)
        vim.notify(string.format([[Copied %s to clipboard]], hook.id))
      end,
      ["ctrl-l"] = function(state)
        local hook = webhooks[state.focused_entry_index]
        -- List recent triggers
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
