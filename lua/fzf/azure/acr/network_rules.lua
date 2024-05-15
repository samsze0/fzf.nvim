local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  ipRules = {
    {
      action = "The action to take (e.g., Allow) when the rule is matched.",
      ipAddressOrRange = "The specific IP address or range to apply the rule to.",
    },
  },
}

-- Fzf all geo-replications under the acr.
--
---@param acr string
---@param opts? { parent_state?: string }
return function(acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_ip_rule { action: string, ipAddressOrRange: string }
  ---@alias acr_network_rule acr_ip_rule
  ---@type acr_network_rule[]
  local network_rules

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command = string.format("az acr network-rule list --name %s", acr)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve network rule set under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)
    ---@type { ipRules: acr_ip_rule[] }
    local network_rule_set = json.parse(result) ---@diagnostic disable-line: assign-type-mismatch

    network_rules = network_rule_set.ipRules
    ---@cast network_rules acr_network_rule[]

    return utils.map(
      network_rules,
      function(i, r)
        return fzf_utils.join_by_delim(
          utils.ansi_codes.grey(string.format("[%s]", "IpRule")),
          r.ipAddressOrRange,
          r.action
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Network-Rules",
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
        local r = network_rules[state.focused_entry_index]

        popups.nvim_preview.border:set_text(
          "top",
          " " .. "[IpRule]" .. " " .. r.ipAddressOrRange .. " "
        )

        set_preview_content(vim.split(vim.inspect(r), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local r = network_rules[state.focused_entry_index]
        vim.fn.setreg("+", r.ipAddressOrRange)
        vim.notify(
          string.format([[Copied %s to clipboard]], r.ipAddressOrRange)
        )
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
