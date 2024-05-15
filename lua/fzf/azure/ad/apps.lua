local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

-- TODO: display manual on hover with something like https://github.com/lewis6991/hover.nvim
-- or as virtual text
local manual = {
  addIns = "List of add-ins associated with this application. Add-ins are additional features or customizations.",
  api = {
    acceptMappedClaims = "Specifies whether the application accepts mapped claims in tokens.",
    knownClientApplications = "List of client applications known to this API. Used for cross-app SSO.",
    oauth2PermissionScopes = "Defines the OAuth2.0 permission scopes that this API exposes.",
    preAuthorizedApplications = "Applications that are pre-authorized to access this API.",
    requestedAccessTokenVersion = "The version of access tokens requested by this application. Null means default.",
  },
  appId = "The unique identifier for this application in Azure AD.",
  appRoles = "Roles defined by the application that can be assigned to users or groups.",
  applicationTemplateId = "Identifier of the application template this app was created from, if any.",
  certification = "Information about the certification of the application.",
  createdDateTime = "The date and time this application was registered.",
  defaultRedirectUri = "Default redirect URI for web-based sign-in.",
  deletedDateTime = "The date and time this application was deleted, if it has been.",
  description = "Description of the application.",
  disabledByMicrosoftStatus = "Status indicating if Microsoft has disabled the application.",
  displayName = "The display name of the application.",
  groupMembershipClaims = "Configures the groups claim issued in a user or OAuth 2.0 access token that the app expects.",
  id = "The unique identifier for this service principal in Azure AD.",
  identifierUris = "URIs that identify the application.",
  info = {
    logoUrl = "URL to the application's logo.",
    marketingUrl = "URL to the application's marketing page.",
    privacyStatementUrl = "URL to the application's privacy statement.",
    supportUrl = "URL to the application's support page.",
    termsOfServiceUrl = "URL to the application's terms of service.",
  },
  isDeviceOnlyAuthSupported = "Indicates if the application supports device-only authentication without a user.",
  isFallbackPublicClient = "Indicates if the application is a public client that can use a fallback authentication method.",
  keyCredentials = "Certificates and secrets associated with this application.",
  notes = "Notes about the application.",
  optionalClaims = "Optional claims configured for the application.",
  parentalControlSettings = {
    countriesBlockedForMinors = "Countries where the app is blocked for minors.",
    legalAgeGroupRule = "Rule to apply for users of legal age.",
  },
  passwordCredentials = "List of password credentials associated with the application.",
  publicClient = {
    redirectUris = "Redirect URIs for public clients (e.g., desktop, mobile apps).",
  },
  publisherDomain = "The verified domain of the application publisher.",
  requestSignatureVerification = "Indicates if request signature verification is enabled for this application.",
  requiredResourceAccess = "Resources that this application requires access to.",
  samlMetadataUrl = "URL to the SAML metadata for the application.",
  serviceManagementReference = "Reference to the service management detail.",
  servicePrincipalLockConfiguration = "Configuration for locking the service principal.",
  signInAudience = "Specifies the Microsoft accounts that are supported for sign-in.",
  spa = {
    redirectUris = "Single Page Application redirect URIs.",
  },
  tags = "Tags associated with the application.",
  tokenEncryptionKeyId = "The key ID used for token encryption.",
  verifiedPublisher = {
    addedDateTime = "The date and time the publisher was verified.",
    displayName = "The display name of the verified publisher.",
    verifiedPublisherId = "The unique identifier of the verified publisher.",
  },
  web = {
    homePageUrl = "URL to the application's homepage.",
    implicitGrantSettings = "Settings related to implicit grant flow.",
    logoutUrl = "URL to be used for logging out users.",
    redirectUriSettings = "Settings for redirect URIs.",
    redirectUris = "Redirect URIs for web applications.",
  },
}

-- Fzf all azuread apps associated with the signed-in user
--
---@param opts? { parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@type number
  local initial_pos

  ---@alias azuread_app { addIns: any[], api: { acceptMappedClaims: any, knownClientApplications: any[], oauth2PermissionScopes: any[], preAuthorizedApplications: any[], requestedAccessTokenVersion: any }, appId: string, appRoles: any[], applicationTemplateId: any, certification: any, createdDateTime: string, defaultRedirectUri: any, deletedDateTime: any, description: any, disabledByMicrosoftStatus: any, displayName: string, groupMembershipClaims: any, id: string, identifierUris: any[], info: { logoUrl: any, marketingUrl: any, privacyStatementUrl: any, supportUrl: any, termsOfServiceUrl: any }, isDeviceOnlyAuthSupported: any, isFallbackPublicClient: any, keyCredentials: any[], notes: any, optionalClaims: any, parentalControlSettings: { countriesBlockedForMinors: any[], legalAgeGroupRule: string }, passwordCredentials: { customKeyIdentifier: any, displayName: string, endDateTime: string, hint: string, keyId: string, secretText: any, startDateTime: string }[], publicClient: { redirectUris: string[] }, publisherDomain: string, requestSignatureVerification: any, requiredResourceAccess: { resourceAccess: { id: string, type: string }[], resourceAppId: string }[], samlMetadataUrl: any, serviceManagementReference: any, servicePrincipalLockConfiguration: { allProperties: boolean, credentialsWithUsageSign: boolean, credentialsWithUsageVerify: boolean, identifierUris: boolean, isEnabled: boolean, tokenEncryptionKeyId: boolean }, signInAudience: string, spa: { redirectUris: any[] }, tags: any[], tokenEncryptionKeyId: any, verifiedPublisher: { addedDateTime: any, displayName: any, verifiedPublisherId: any }, web: { homePageUrl: any, implicitGrantSettings: { enableAccessTokenIssuance: boolean, enableIdTokenIssuance: boolean }, logoutUrl: any, redirectUriSettings: any[], redirectUris: any[] } }
  ---@type azuread_app[]
  local apps

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result = vim.fn.system("az ad app list --all")
    if vim.v.shell_error ~= 0 then
      _error("Fail to retrieve azuread apps", result)
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    apps = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast apps azuread_app[]

    return utils.map(
      apps,
      function(i, app) return fzf_utils.join_by_delim(app.displayName) end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azuread-Apps",
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
        local app = apps[state.focused_entry_index]

        popups.nvim_preview.border:set_text(
          "top",
          " " .. app.displayName .. " "
        )

        set_preview_content(vim.split(vim.inspect(app), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local app = apps[state.focused_entry_index]
        vim.fn.setreg("+", app.id)
        vim.notify(string.format([[Copied %s to clipboard]], app.id))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
