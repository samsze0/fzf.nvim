local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  compositionType = "Indicates the type of composition for the snapshot.",
  created = "The date and time when the snapshot was created.",
  etag = "A unique identifier for the current state of the snapshot.",
  expires = "The expiration date and time of the snapshot.",
  filters = {
    {
      key = "A pattern that keys must match to be included in the snapshot.",
      label = "A label that keys must match to be included in the snapshot.",
    },
  },
  itemsCount = "The total number of items included in the snapshot.",
  name = "The name of the snapshot.",
  retentionPeriod = "The period, in seconds, for which the snapshot is retained.",
  size = "The size of the snapshot in bytes.",
  status = "The current status of the snapshot.",
  tags = "A collection of tags associated with the snapshot.",
}

-- Fzf all snapshots under the app-config.
--
---@param appconfig azure_appconfig
---@param opts? { parent_state?: string }
return function(appconfig, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azure_appconfig_snapshot { compositionType: string, created: string, etag: string, expires: string, filters: { key: string, label: string }[], itemsCount: number, name: string, retentionPeriod: number, size: number, status: string, tags: table<string, string> }
  ---@type azure_appconfig_snapshot[]
  local snapshots

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command =
      string.format("az appconfig snapshot list -n %s --all", appconfig.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve snapshots under the azure app-config",
        appconfig.name,
        result
      )
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    snapshots = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast snapshots azure_appconfig_snapshot[]

    return utils.map(
      snapshots,
      function(i, s)
        return fzf_utils.join_by_delim(
          s.status == "ready" and utils.ansi_codes.blue("")
            or s.status == "failed" and utils.ansi_codes.red("")
            or s.status == "archived" and utils.ansi_codes.grey("")
            or " ",
          s.name
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-App-Config-Snapshots",
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
        local s = snapshots[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. s.name .. " ")

        set_preview_content(vim.split(vim.inspect(s), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local s = snapshots[state.focused_entry_index]
        vim.fn.setreg("+", s.name)
        vim.notify(string.format([[Copied %s to clipboard]], s.name))
      end,
      ["ctrl-a"] = function(state)
        local s = snapshots[state.focused_entry_index]

        local command = string.format(
          "az appconfig snapshot archive --name %s --snapshot-name %s",
          appconfig.name,
          s.name
        )
        vim.fn.setreg("+", command)
        vim.notify(string.format([[Copied %s to clipboard]], command))
      end,
      ["ctrl-r"] = function(state)
        local s = snapshots[state.focused_entry_index]

        local command = string.format(
          "az appconfig snapshot recover --name %s --snapshot-name %s",
          appconfig.name,
          s.name
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
