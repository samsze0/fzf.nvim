local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  connectionString = "A complete connection string that includes the endpoint, ID, and secret for connecting to Azure App Configuration.",
  id = "A unique identifier for the credential.",
  lastModified = "The date and time when the credential was last modified.",
  name = "A descriptive name for the credential.",
  readOnly = "Indicates whether the credential provides read-only access.",
  value = "The secret value associated with this credential.",
}

-- Fzf all credentials under the app-config.
--
---@param appconfig azure_appconfig
---@param opts? { parent_state?: string }
return function(appconfig, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azure_appconfig_credential { connectionString: string, id: string, lastModified: string, name: string, readOnly: boolean, value: string }
  ---@type azure_appconfig_credential[]
  local credentials

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command =
      string.format("az appconfig credential list -n %s", appconfig.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve credentials under the azure app-config",
        appconfig.name,
        result
      )
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    credentials = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast credentials azure_appconfig_credential[]

    return utils.map(
      credentials,
      function(i, c)
        return fzf_utils.join_by_delim(
          c.readOnly and utils.ansi_codes.grey("") or " ",
          c.name
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-App-Config-Credentials",
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
        local c = credentials[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. c.name .. " ")

        set_preview_content(vim.split(vim.inspect(c), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local c = credentials[state.focused_entry_index]
        vim.fn.setreg("+", c.id)
        vim.notify(string.format([[Copied %s to clipboard]], c.id))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
