local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  id = "The full resource ID for the replication.",
  location = "The location of the replication.",
  name = "The name of the replication.",
  provisioningState = "The provisioning state of the replication.",
  regionEndpointEnabled = "Indicates if the regional endpoint is enabled.",
  resourceGroup = "The name of the resource group the replication belongs to.",
  status = {
    displayStatus = "The display status of the replication.",
    message = "Additional details about the replication status.",
    timestamp = "The timestamp of the current status.",
  },
  systemData = {
    createdAt = "The time at which the replication was created.",
    createdBy = "The identifier of the creator.",
    createdByType = "The type of the creator (e.g., User, Application).",
    lastModifiedAt = "The time at which the replication was last modified.",
    lastModifiedBy = "The identifier of the last user or application that modified the replication.",
    lastModifiedByType = "The type of the last modifier (e.g., User, Application).",
  },
  tags = "A collection of tags associated with the replication.",
  type = "The type of the Azure resource.",
  zoneRedundancy = "Indicates if zone redundancy is enabled for the replication.",
}

-- Fzf all geo-replications under the acr.
--
---@param acr string
---@param opts? { parent_state?: string }
return function(acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_georeplication { id: string, location: string, name: string, provisioningState: string, regionEndpointEnabled: boolean, resourceGroup: string, status: { displayStatus: string, message: string, timestamp: string }, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, tags: table<string, string>, type: string, zoneRedundancy: string }
  ---@type acr_georeplication[]
  local replications

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az acr replication list -r %s", acr)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve geo-replications under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)
    replications = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast replications acr_georeplication[]

    return utils.map(
      replications,
      function(i, r) return fzf_utils.join_by_delim(r.name) end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Geo-Replications",
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
        local r = replications[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. r.name .. " ")

        set_preview_content(vim.split(vim.inspect(r), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local r = replications[state.focused_entry_index]
        vim.fn.setreg("+", r.id)
        vim.notify(string.format([[Copied %s to clipboard]], r.id))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
