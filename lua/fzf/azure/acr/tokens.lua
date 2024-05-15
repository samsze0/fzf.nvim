local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  creationDate = "The date and time when the ACR scope map was created.",
  credentials = {
    certificates = "Certificates associated with the ACR scope map.",
    passwords = "Passwords associated with the ACR scope map.",
  },
  id = "The full identifier of the ACR scope map resource.",
  name = "The name of the ACR scope map.",
  provisioningState = "The provisioning state of the ACR scope map.",
  resourceGroup = "The name of the resource group within which the ACR scope map is located.",
  scopeMapId = "The identifier of the scope map associated with this ACR token.",
  status = "The status of the ACR scope map.",
  systemData = {
    createdAt = "The date and time when the ACR scope map was created.",
    createdBy = "The email or identifier of the creator of the ACR scope map.",
    createdByType = "The type of creator (e.g., User, Application, ManagedIdentity, Key).",
    lastModifiedAt = "The date and time when the ACR scope map was last modified.",
    lastModifiedBy = "The email or identifier of the last user or process that modified the ACR scope map.",
    lastModifiedByType = "The type of the last modifier (e.g., User, Application, ManagedIdentity, Key).",
  },
  type = "The type of the Azure resource (ACR tokens in this case).",
}

-- Fzf all tokens under the acr.
--
---@param acr azure_container_registry
---@param opts? { parent_state?: string }
return function(acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_token { creationDate: string, credentials: { certificates: string[], passwords: string[] }, id: string, name: string, provisioningState: string, resourceGroup: string, scopeMapId: string, status: string, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, type: string }
  ---@type acr_token[]
  local tokens

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az acr token list -r %s", acr.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve tokens under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)
    tokens = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast tokens acr_token[]

    return utils.map(tokens, function(i, token)
      local parts = vim.split(token.scopeMapId, "/")

      return fzf_utils.join_by_delim(
        token.status == "enabled" and token.name
          or utils.ansi_codes.grey(token.name),
        utils.ansi_codes.grey(string.format("-> %s", parts[#parts]))
      )
    end)
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Tokens",
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
        local token = tokens[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. token.name .. " ")

        set_preview_content(vim.split(vim.inspect(token), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local token = tokens[state.focused_entry_index]
        vim.fn.setreg("+", token.id)
        vim.notify(string.format([[Copied %s to clipboard]], token.id))
      end,
      ["ctrl-l"] = function(state)
        local token = tokens[state.focused_entry_index]

        local command = string.format(
          "docker login --username %s %s",
          token.name,
          acr.loginServer
        )
        vim.fn.setreg("+", command)
        vim.notify(string.format([[Copied %s to clipboard]], command))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
