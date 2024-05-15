local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  creationDate = "The date and time the cache rule was created.",
  credentialSetResourceId = "The resource ID of the credential set used by the cache rule.",
  id = "The unique identifier for the cache rule within Azure resources.",
  name = "The name of the cache rule.",
  provisioningState = "The provisioning state of the cache rule, indicating whether it's succeeded, failed, or still in progress.",
  resourceGroup = "The name of the resource group within which the cache rule is located.",
  sourceRepository = "The source repository for the cache rule, indicating where the images are pulled from.",
  systemData = {
    createdAt = "The date and time when the cache rule was initially created.",
    createdBy = "The email address or identifier of the creator of the cache rule.",
    createdByType = "The type of the creator (e.g., User, Application, ManagedIdentity).",
    lastModifiedAt = "The date and time when the cache rule was last modified.",
    lastModifiedBy = "The email address or identifier of the person who last modified the cache rule.",
    lastModifiedByType = "The type of the individual or entity that last modified the cache rule.",
  },
  targetRepository = "The target repository within the ACR where images are cached.",
  type = "The type of the Azure resource, indicating it's an ACR cache rule.",
}

-- Fzf all cache rules under the acr.
--
---@param acr azure_container_registry
---@param opts? { parent_state?: string }
return function(acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_cache_rule { creationDate: string, credentialSetResourceId: string, id: string, name: string, provisioningState: string, resourceGroup: string, sourceRepository: string, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, targetRepository: string, type: string }
  ---@type acr_cache_rule[]
  local rules

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az acr cache list -r %s", acr.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve cache rules under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)
    rules = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast rules acr_cache_rule[]

    return utils.map(
      rules,
      function(i, rule)
        return fzf_utils.join_by_delim(
          rule.name,
          utils.ansi_codes.grey(
            string.format(
              "%s -> %s",
              rule.sourceRepository,
              rule.targetRepository
            )
          )
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Cache-Rules",
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
        local rule = rules[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. rule.name .. " ")

        set_preview_content(vim.split(vim.inspect(rule), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local rule = rules[state.focused_entry_index]
        vim.fn.setreg("+", rule.id)
        vim.notify(string.format([[Copied %s to clipboard]], rule.id))
      end,
      ["ctrl-p"] = function(state)
        local rule = rules[state.focused_entry_index]

        -- Make tag user-provided
        local command = string.format(
          "docker pull %s/%s:latest",
          acr.loginServer,
          rule.targetRepository
        )

        if true then
          vim.fn.setreg("+", command)
          vim.notify(string.format([[Copied %s to clipboard]], command))
          return
        end

        local output = vim.fn.system(command)
        if vim.v.shell_error ~= 0 then
          _error(
            string.format("Fail to pull from %s", rule.targetRepository),
            output
          )
          return
        end
        vim.notify(string.format([[Pulled %s]], rule.targetRepository))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
