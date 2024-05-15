local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local config = {
  ACR = require("fzf.azure.acr").list,
  ["Account"] = require("fzf.azure.account").subscriptions,
  ["AzureAD Users"] = require("fzf.azure.ad").users,
  ["AzureAD Groups"] = require("fzf.azure.ad").groups,
  ["AzureAD Service Principals"] = require("fzf.azure.ad").service_principals,
  ["AzureAD Apps"] = require("fzf.azure.ad").apps,
}

-- Fzf all available Azure selectors
--
---@param opts? { parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  local function get_entries()
    return utils.map(
      config,
      function(k, v) return fzf_utils.join_by_delim(k) end
    )
  end

  local layout, popups = helpers.create_plain_layout()

  core.fzf(get_entries(), {
    prompt = "Azure",
    layout = layout,
    main_popup = popups.main,
    binds = {
      ["+select"] = function(state)
        local selector = config[state.focused_entry]
        selector()
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
