local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  conditions = {
    client_filters = {
      {
        name = "Name of the feature filter.",
        parameters = "Parameters of the feature filter.",
      },
    },
  },
  description = "Description of the feature, explaining its purpose or use.",
  key = "The unique key identifying this feature flag within Azure App Configuration.",
  label = "A label used to differentiate feature flags with the same key.",
  lastModified = "The date and time when the feature flag was last modified.",
  locked = "Indicates whether the feature flag is locked to prevent modification.",
  name = "The name of the feature flag.",
  state = "The state of the feature flag, indicating its current status (e.g., enabled, disabled, conditional).",
}

-- Fzf all features under the app-config.
--
---@param appconfig azure_appconfig
---@param opts? { parent_state?: string }
return function(appconfig, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azure_appconfig_feature { conditions: { client_filters: { name: string, parameters: table<string, string> } }, description: string, key: string, label: string, lastModified: string, locked: boolean, name: string, state: string }
  ---@type azure_appconfig_feature[]
  local features

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command =
      string.format("az appconfig feature list -n %s", appconfig.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve features under the azure app-config",
        appconfig.name,
        result
      )
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    features = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast features azure_appconfig_feature[]

    return utils.map(
      features,
      function(i, f)
        return fzf_utils.join_by_delim(
          f.state == "off" and utils.ansi_codes.grey(" ")
            or utils.ansi_codes.blue(" "),
          f.locked and utils.ansi_codes.grey("") or " ",
          f.name
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-App-Config-Features",
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
        local f = features[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. f.name .. " ")

        set_preview_content(vim.split(vim.inspect(f), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local f = features[state.focused_entry_index]
        vim.fn.setreg("+", f.key)
        vim.notify(string.format([[Copied %s to clipboard]], f.key))
      end,
      ["ctrl-x"] = function(state)
        local f = features[state.focused_entry_index]

        local command = string.format(
          "az appconfig feature delete --name %s --key %s --label %s",
          appconfig.name,
          f.key,
          f.label
        )
        vim.fn.setreg("+", command)
        vim.notify(string.format([[Copied %s to clipboard]], command))
      end,
      ["ctrl-l"] = function(state)
        local f = features[state.focused_entry_index]

        local command = string.format(
          "az appconfig feature lock --name %s --key %s --label %s",
          appconfig.name,
          f.key,
          f.label
        )
        vim.fn.setreg("+", command)
        vim.notify(string.format([[Copied %s to clipboard]], command))
      end,
      ["ctrl-u"] = function(state)
        local f = features[state.focused_entry_index]

        local command = string.format(
          "az appconfig feature unlock --name %s --key %s --label %s",
          appconfig.name,
          f.key,
          f.label
        )
        vim.fn.setreg("+", command)
        vim.notify(string.format([[Copied %s to clipboard]], command))
      end,
      ["left"] = function(state)
        local f = features[state.focused_entry_index]

        local command = string.format(
          "az appconfig feature enable --name %s --key %s --label %s",
          appconfig.name,
          f.key,
          f.label
        )
        if true then
          vim.fn.setreg("+", command)
          vim.notify(string.format([[Copied %s to clipboard]], command))
          return
        end

        local output = vim.fn.system(command .. " --yes")
        if vim.v.shell_error ~= 0 then
          _error("Fail to enable feature", f.name, output)
          return
        end
        core.send_to_fzf(state.id, fzf_utils.reload_action(get_entries()))
      end,
      ["right"] = function(state)
        local f = features[state.focused_entry_index]

        local command = string.format(
          "az appconfig feature disable --name %s --key %s --label %s",
          appconfig.name,
          f.key,
          f.label
        )
        if true then
          vim.fn.setreg("+", command)
          vim.notify(string.format([[Copied %s to clipboard]], command))
          return
        end

        local output = vim.fn.system(command .. " --yes")
        if vim.v.shell_error ~= 0 then
          _error("Fail to disable feature", f.name, output)
          return
        end
        core.send_to_fzf(state.id, fzf_utils.reload_action(get_entries()))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
