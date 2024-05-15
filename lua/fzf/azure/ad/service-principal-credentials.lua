local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  customKeyIdentifier = "Custom identifier for the key.",
  displayName = "Display name for the credential.",
  endDateTime = "Expiry date and time for the credential.",
  hint = "Hint to help identify the credential.",
  keyId = "Unique identifier for the credential.",
  secretText = "The secret text of the credential, not returned for security reasons.",
  startDateTime = "Start date and time for the credential.",
}

-- Fzf the list of credentials associated with the service principal
--
---@param service_principal_id string
---@param opts? { parent_state?: string }
return function(service_principal_id, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azuread_service_principal_credential { customKeyIdentifier: string, displayName: string, endDateTime: string, hint: string, keyId: string, secretText: string, startDateTime: string }
  ---@type azuread_service_principal_credential[]
  local credentials

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result
    result =
      vim.fn.system("az ad sp credential list --id " .. service_principal_id)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve azuread service principal credentials",
        result
      )
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    credentials = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast credentials azuread_service_principal_credential[]

    return utils.map(
      credentials,
      function(i, credential)
        return fzf_utils.join_by_delim(credential.displayName)
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azuread-Service-Principal-Credentials",
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
        local credential = credentials[state.focused_entry_index]

        popups.nvim_preview.border:set_text(
          "top",
          " " .. credential.displayName .. " "
        )

        set_preview_content(vim.split(vim.inspect(credential), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local credential = credentials[state.focused_entry_index]
        vim.fn.setreg("+", credential.keyId)
        vim.notify(string.format([[Copied %s to clipboard]], credential.keyId))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
