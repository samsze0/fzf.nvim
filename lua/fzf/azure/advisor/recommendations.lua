local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

local manual = {
  category = "The category of the recommendation, indicating the area of impact, such as HighAvailability.",
  extendedProperties = {
    region = "Additional properties of the recommendation, such as the Azure region related to the recommendation.",
  },
  id = "The unique identifier for the recommendation resource.",
  impact = "The impact level of the recommendation, such as Medium.",
  impactedField = "The specific Azure service or resource type impacted by the recommendation.",
  impactedValue = "The specific name or identifier of the Azure resource impacted.",
  lastUpdated = "The timestamp of when the recommendation was last updated.",
  metadata = "Metadata associated with the recommendation. Can include various additional information.",
  name = "The name of the recommendation, typically a GUID.",
  recommendationTypeId = "The unique identifier for the type of recommendation.",
  resourceGroup = "The name of the Azure resource group containing the impacted resource.",
  resourceMetadata = {
    resourceId = "The full resource ID of the impacted Azure resource.",
    source = "The source of the recommendation, providing context on where it's coming from.",
  },
  risk = "The level of risk associated with not implementing the recommendation.",
  shortDescription = {
    problem = "A brief description of the problem identified by the recommendation.",
    solution = "A brief description of the recommended solution or action to take.",
  },
  suppressionIds = "IDs of any suppressions applied to the recommendation, indicating it has been acknowledged but not acted upon.",
  type = "The resource type of the recommendation, indicating it's an Azure Advisor recommendation.",
}

-- Fzf all recommendations provided by the default advisor configuration
--
---@param opts? { parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azure_advisor_recommendation { category: string, extendedProperties: { region: string }, id: string, impact: string, impactedField: string, impactedValue: string, lastUpdated: string, metadata: string, name: string, recommendationTypeId: string, resourceGroup: string, resourceMetadata: { resourceId: string, source: string }, risk: string, shortDescription: { problem: string, solution: string }, suppressionIds: string, type: string }
  ---@type azure_advisor_recommendation[]
  local recommendations

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result = vim.fn.system("az advisor recommendation list")
    if vim.v.shell_error ~= 0 then
      _error("Fail to retrieve advisor recommendations", result)
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    recommendations = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast recommendations azure_advisor_recommendation[]

    return utils.map(
      recommendations,
      function(i, r)
        return fzf_utils.join_by_delim(
          utils.ansi_codes.grey(string.format("[%s]", r.impact)),
          r.shortDescription.problem
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-Advisor-Recommendations",
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
        local r = recommendations[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. r.shortDescription.problem .. " ")

        set_preview_content(vim.split(vim.inspect(r), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local r = recommendations[state.focused_entry_index]
        vim.fn.setreg("+", r.id)
        vim.notify(string.format([[Copied %s to clipboard]], r.id))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
