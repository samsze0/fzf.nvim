local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")
local azuread_objects = require("fzf.azure.ad.objects")
-- local azuread_groups = require("fzf.azure.ad.groups")

local manual = {
  businessPhones = "Array of business phone numbers associated with the user.",
  displayName = "The display name of the user.",
  givenName = "The given (first) name of the user.",
  id = "The unique identifier for the user.",
  jobTitle = "The job title of the user.",
  mail = "The primary email address of the user.",
  mobilePhone = "The mobile phone number of the user.",
  officeLocation = "The office location for the user.",
  preferredLanguage = "The preferred language of the user.",
  surname = "The surname (last name) of the user.",
  userPrincipalName = "The principal name of the user, used for signing in to their Azure AD account.",
}

-- Fzf all azuread users associated with the signed-in user,
-- or the owners of the azuread service principal (if `service_principal_id` is provided)
-- or the owners of the azuread group (if `owners_group_id` is provided)
-- or the owners of the azuread group (if `members_group_id` is provided)
--
---@param opts? { service_principal_id?: string, members_group_id?: string, owners_group_id?: string, parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azuread_user { businessPhones: string[], displayName: string, givenName: string, id: string, jobTitle: string, mail: string, mobilePhone: string, officeLocation: string, preferredLanguage: string, surname: string, userPrincipalName: string }
  ---@type azuread_user[]
  local users

  ---@type azuread_user?
  local signed_in_user

  local initial_pos

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result
    if opts.service_principal_id then
      result =
        vim.fn.system("az ad sp owner list --id " .. opts.service_principal_id)
      if vim.v.shell_error ~= 0 then
        _error("Fail to retrieve azuread service principal owners", result)
        return {}
      end
    elseif opts.owners_group_id then
      result =
        vim.fn.system("az ad group owner list --group " .. opts.owners_group_id)
      if vim.v.shell_error ~= 0 then
        _error("Fail to retrieve azuread group owners", result)
        return {}
      end
    elseif opts.members_group_id then
      result = vim.fn.system(
        "az ad group member list --group " .. opts.members_group_id
      )
      if vim.v.shell_error ~= 0 then
        _error("Fail to retrieve azuread group members", result)
        return {}
      end
    else
      result = vim.fn.system("az ad user list")
      if vim.v.shell_error ~= 0 then
        _error("Fail to retrieve azuread users", result)
        return {}
      end
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    users = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast users azuread_user[]

    -- TODO: handle case where there is no signed in user
    local result = vim.fn.system("az ad signed-in-user show")
    if vim.v.shell_error ~= 0 then
      _error("Fail to retrieve currently signed-in user", result)
      return {}
    end

    result = vim.trim(result)

    signed_in_user = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast signed_in_user azuread_user

    return utils.map(users, function(i, user)
      local signed_in = user.id == signed_in_user.id
      if signed_in then initial_pos = i end

      return fzf_utils.join_by_delim(
        signed_in and utils.ansi_codes.blue("") or " ",
        user.displayName
      )
    end)
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azuread-Users",
    layout = layout,
    main_popup = popups.main,
    initial_position = initial_pos,
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
        local user = users[state.focused_entry_index]

        popups.nvim_preview.border:set_text(
          "top",
          " " .. user.displayName .. " "
        )

        set_preview_content(vim.split(vim.inspect(user), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local user = users[state.focused_entry_index]
        vim.fn.setreg("+", user.id)
        vim.notify(string.format([[Copied %s to clipboard]], user.id))
      end,
      ["ctrl-o"] = function(state)
        local user = users[state.focused_entry_index]
        if user.id ~= signed_in_user.id then
          _error("Can only get owned objects for the signed-in user")
          return
        end

        azuread_objects({ user_id = user.id, parent_state = state.id })
      end,
      ["ctrl-g"] = function(state)
        local user = users[state.focused_entry_index]

        -- TODO: avoid circular dependency
        -- azuread_groups({ user_id = user.id, parent_state = state.id })
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
