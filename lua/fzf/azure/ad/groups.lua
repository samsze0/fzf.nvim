local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")
local azuread_users = require("fzf.azure.ad.users")

local manual = {
  ["@odata.type"] = "The OData type of the group object.",
  classification = "Classification of the group (e.g., confidential).",
  createdDateTime = "The date and time when the group was created.",
  creationOptions = "Options used when creating the group.",
  deletedDateTime = "The date and time when the group was deleted.",
  description = "Description of the group.",
  displayName = "The display name of the group.",
  expirationDateTime = "The date and time when the group expires.",
  groupTypes = "Types of the group, such as Unified to indicate an Office 365 group.",
  id = "The unique identifier of the group.",
  isAssignableToRole = "Indicates whether the group can be assigned to roles.",
  mail = "The SMTP address for the group, if mail is enabled.",
  mailEnabled = "Indicates whether the group is mail-enabled.",
  mailNickname = "The mail nickname for the group.",
  membershipRule = "The rule that determines membership for a dynamic group.",
  membershipRuleProcessingState = "State of processing for the membership rule.",
  onPremisesDomainName = "The domain name of the group on-premises.",
  onPremisesLastSyncDateTime = "The last time the group was synchronized with on-premises directory.",
  onPremisesNetBiosName = "The NetBIOS name of the group on-premises.",
  onPremisesProvisioningErrors = "Errors when provisioning the group from on-premises directory.",
  onPremisesSamAccountName = "The SAM account name of the group on-premises.",
  onPremisesSecurityIdentifier = "The security identifier (SID) of the group on-premises.",
  onPremisesSyncEnabled = "Indicates whether synchronization with on-premises directory is enabled.",
  preferredDataLocation = "Preferred data location for the group.",
  preferredLanguage = "Preferred language for the group.",
  proxyAddresses = "Proxy addresses for the group.",
  renewedDateTime = "The date and time when the group was last renewed.",
  resourceBehaviorOptions = "Behavior options for resources owned by the group.",
  resourceProvisioningOptions = "Provisioning options for resources owned by the group.",
  securityEnabled = "Indicates whether the group is security-enabled.",
  securityIdentifier = "The security identifier (SID) for the group.",
  serviceProvisioningErrors = "Errors when provisioning services for the group.",
  theme = "The theme of the group.",
  visibility = "Visibility of the group, such as Public or Private.",
}

-- TODO: get member/sub groups with the `get-member-groups` subcommand

-- Fzf all azuread groups associated with the signed-in user,
-- or the groups that the user is a member of (if `user_id` option is given).
--
---@param opts? { user_id?: string, parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azuread_group { ["@odata.type"]: string, classification: string, createdDateTime: string, creationOptions: string, deletedDateTime: string, description: string, displayName: string, expirationDateTime: string, groupTypes: string[], id: string, isAssignableToRole: boolean, mail: string, mailEnabled: boolean, mailNickname: string, membershipRule: string, membershipRuleProcessingState: string, onPremisesDomainName: string, onPremisesLastSyncDateTime: string, onPremisesNetBiosName: string, onPremisesProvisioningErrors: string[], onPremisesSamAccountName: string, onPremisesSecurityIdentifier: string, onPremisesSyncEnabled: boolean, preferredDataLocation: string, preferredLanguage: string, proxyAddresses: string[], renewedDateTime: string, resourceBehaviorOptions: string[], resourceProvisioningOptions: string[], securityEnabled: boolean, securityIdentifier: string, serviceProvisioningErrors: string[], theme: string, visibility: string }
  ---@type azuread_group[]
  local groups

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    if opts.user_id then
      local result =
        vim.fn.system("az ad user get-member-groups --id " .. opts.user_id)
      if vim.v.shell_error ~= 0 then
        _error(
          "Fail to retrieve azuread groups for user",
          opts.user_id,
          result
        )
        return {}
      end
    else
      local result = vim.fn.system("az ad group list")
      if vim.v.shell_error ~= 0 then
        _error("Fail to retrieve azuread groups", result)
        return {}
      end
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    groups = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast groups azuread_group[]

    return utils.map(
      groups,
      function(i, group) return fzf_utils.join_by_delim(group.displayName) end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azuread-Groups",
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
        local group = groups[state.focused_entry_index]

        popups.nvim_preview.border:set_text(
          "top",
          " " .. group.displayName .. " "
        )

        set_preview_content(vim.split(vim.inspect(group), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local group = groups[state.focused_entry_index]
        vim.fn.setreg("+", group.id)
        vim.notify(string.format([[Copied %s to clipboard]], group.id))
      end,
      ["ctrl-o"] = function(state)
        local group = groups[state.focused_entry_index]
        azuread_users({
          owners_group_id = group.id,
          parent_state = state.id,
        })
      end,
      ["ctrl-m"] = function(state)
        local group = groups[state.focused_entry_index]
        azuread_users({
          members_group_id = group.id,
          parent_state = state.id,
        })
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
