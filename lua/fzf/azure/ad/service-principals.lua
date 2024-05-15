local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")
local azuread_users = require("fzf.azure.ad.users")
local azuread_service_principal_credentials =
  require("fzf.azure.ad.service-principal-credentials")

local manual = {
  ["@odata.type"] = "The OData type of the service principal object.",
  accountEnabled = "Specifies whether the service principal account is enabled.",
  addIns = "Additional features or customizations associated with the service principal.",
  alternativeNames = "Alternative names for the service principal.",
  appDescription = "Description of the associated application.",
  appDisplayName = "Display name of the associated application.",
  appId = "Unique identifier for the associated application.",
  appOwnerOrganizationId = "Identifier of the organization that owns the application.",
  appRoleAssignmentRequired = "Indicates whether users or groups require assignment to roles before they can access the app.",
  appRoles = "Roles defined by the application that can be assigned to users or groups.",
  applicationTemplateId = "Identifier of the application template this service principal was created from.",
  createdDateTime = "The date and time the service principal was created.",
  deletedDateTime = "The date and time the service principal was deleted, if applicable.",
  description = "Description of the service principal.",
  disabledByMicrosoftStatus = "Status indicating if Microsoft has disabled the service principal.",
  displayName = "The display name of the service principal.",
  homepage = "URL to the service principal's homepage.",
  id = "The unique identifier for this service principal.",
  info = {
    logoUrl = "URL to the service principal's logo.",
    marketingUrl = "URL to the service principal's marketing page.",
    privacyStatementUrl = "URL to the service principal's privacy statement.",
    supportUrl = "URL to the service principal's support page.",
    termsOfServiceUrl = "URL to the service principal's terms of service.",
  },
  keyCredentials = "Certificates and secrets associated with the service principal.",
  loginUrl = "URL for logging into the service principal.",
  logoutUrl = "URL for logging out of the service principal.",
  notes = "Notes about the service principal.",
  notificationEmailAddresses = "Email addresses to receive notifications about the service principal.",
  oauth2PermissionScopes = "OAuth2.0 permission scopes that the service principal exposes.",
  passwordCredentials = "Password credentials associated with the service principal.",
  preferredSingleSignOnMode = "Preferred single sign-on mode for the service principal.",
  preferredTokenSigningKeyThumbprint = "Thumbprint of the preferred token signing key.",
  replyUrls = "URLs to which Azure AD will redirect in response to an OAuth 2.0 request.",
  resourceSpecificApplicationPermissions = "Application permissions specific to a resource that the service principal requires.",
  samlSingleSignOnSettings = {
    relayState = "Relay state used in SAML single sign-on settings.",
  },
  servicePrincipalNames = "Names that identify the service principal.",
  servicePrincipalType = "Type of the service principal, indicating it represents an application.",
  signInAudience = "Specifies the Microsoft accounts that are supported for sign-in.",
  tags = "Tags associated with the service principal.",
  tokenEncryptionKeyId = "The key ID used for token encryption.",
  verifiedPublisher = {
    addedDateTime = "The date and time the publisher was verified.",
    displayName = "The display name of the verified publisher.",
    verifiedPublisherId = "The unique identifier of the verified publisher.",
  },
}

-- Fzf all azuread service principals associated with the signed-in user
--
---@param opts? { parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azuread_service_principal { accountEnabled: boolean, addIns: any[], alternativeNames: any[], appDescription: string, appDisplayName: string, appId: string, appOwnerOrganizationId: string, appRoleAssignmentRequired: boolean, appRoles: any[], applicationTemplateId: string, createdDateTime: string, deletedDateTime: string, description: string, disabledByMicrosoftStatus: string, displayName: string, homepage: string, id: string, info: { logoUrl: string, marketingUrl: string, privacyStatementUrl: string, supportUrl: string, termsOfServiceUrl: string }, keyCredentials: any[], loginUrl: string, logoutUrl: string, notes: string, notificationEmailAddresses: any[], oauth2PermissionScopes: any[], passwordCredentials: any[], preferredSingleSignOnMode: string, preferredTokenSigningKeyThumbprint: string, replyUrls: string[], resourceSpecificApplicationPermissions: any[], samlSingleSignOnSettings: string, servicePrincipalNames: string[], servicePrincipalType: string, signInAudience: string, tags: any[], tokenEncryptionKeyId: string, verifiedPublisher: { addedDateTime: string, displayName: string, verifiedPublisherId: string } }
  ---@type azuread_service_principal[]
  local service_principals

  -- Whether to show all service principals or only the ones owned by the signed-in user
  local show_all = false

  ---@param opts?: { show_mine_only?: boolean }
  local function get_entries(opts)
    opts = vim.tbl_extend("force", { show_mine_only = true }, opts or {})

    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result = vim.fn.system(
      "az ad sp list --all " .. (opts.show_mine_only and "--show-mine" or "")
    )
    if vim.v.shell_error ~= 0 then
      _error("Fail to retrieve azuread service principals", result)
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    service_principals = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast service_principals azuread_service_principal[]

    return utils.map(
      service_principals,
      function(i, sp) return fzf_utils.join_by_delim(sp.displayName) end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azuread-Service-Principals",
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
        local sp = service_principals[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. sp.displayName .. " ")

        set_preview_content(vim.split(vim.inspect(sp), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local sp = service_principals[state.focused_entry_index]
        vim.fn.setreg("+", sp.id)
        vim.notify(string.format([[Copied %s to clipboard]], sp.id))
      end,
      ["ctrl-a"] = function(state)
        show_all = not show_all
        core.send_to_fzf(
          state.id,
          fzf_utils.reload_action(
            get_entries({ show_mine_only = not show_all })
          )
        )
      end,
      ["ctrl-o"] = function(state)
        local sp = service_principals[state.focused_entry_index]
        azuread_users({
          service_principal_id = sp.id,
          parent_state = state.id,
        })
      end,
      ["ctrl-l"] = function(state)
        local sp = service_principals[state.focused_entry_index]
        azuread_service_principal_credentials(sp.id, {
          parent_state = state.id,
        })
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
