local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  contentType = "Indicates the type of content stored in the configuration setting, such as a reference to a Key Vault secret, or any arbitrary type.",
  etag = "A unique identifier for a particular version of the configuration setting.",
  key = "The key of the configuration setting. Acts as a unique identifier.",
  label = "A label used to group configuration settings for different scenarios, environments, or app versions.",
  lastModified = "The timestamp of when the configuration setting was last modified.",
  locked = "Indicates whether the configuration setting is locked from modification.",
  tags = "A collection of tags that can be used to categorize and filter configuration settings.",
  value = "The value of the configuration setting. Value would be a JSON with a URI pointing to an Azure Key Vault secret if the contentType is a reference to a Key Vault secret.",
}

-- Fzf all key-value pairs under the app-config.
--
---@param appconfig azure_appconfig
---@param opts? { parent_state?: string }
return function(appconfig, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azure_appconfig_keyvaluepair { contentType: string, etag: string, key: string, label: string, lastModified: string, locked: boolean, tags: string[], value: string }
  ---@type azure_appconfig_keyvaluepair[]
  local keyvalue_pairs

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az appconfig kv list -n %s", appconfig.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve key-value pairs under the azure app-config",
        appconfig.name,
        result
      )
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    keyvalue_pairs = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast keyvalue_pairs azure_appconfig_keyvaluepair[]

    return utils.map(
      keyvalue_pairs,
      function(i, p)
        return fzf_utils.join_by_delim(
          p.locked and utils.ansi_codes.grey("") or " ",
          p.key
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-App-Config-Key-Value-Pairs",
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
        local p = keyvalue_pairs[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. p.key .. " ")

        set_preview_content(vim.split(vim.inspect(p), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local p = keyvalue_pairs[state.focused_entry_index]
        vim.fn.setreg("+", p.key)
        vim.notify(string.format([[Copied %s to clipboard]], p.key))
      end,
      ["ctrl-l"] = function(state)
        local p = keyvalue_pairs[state.focused_entry_index]

        local command = string.format(
          "az appconfig kv lock --name %s --key %s --label %s",
          appconfig.name,
          p.key,
          p.label
        )
        vim.fn.setreg("+", command)
        vim.notify(string.format([[Copied %s to clipboard]], command))
      end,
      ["ctrl-x"] = function(state)
        local p = keyvalue_pairs[state.focused_entry_index]

        local command = string.format(
          "az appconfig kv delete --name %s --key %s --label %s",
          appconfig.name,
          p.key,
          p.label
        )
        vim.fn.setreg("+", command)
        vim.notify(string.format([[Copied %s to clipboard]], command))
      end,
      ["ctrl-u"] = function(state)
        local p = keyvalue_pairs[state.focused_entry_index]

        local command = string.format(
          "az appconfig kv unlock --name %s --key %s --label %s",
          appconfig.name,
          p.key,
          p.label
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
