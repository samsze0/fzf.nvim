local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")
local timeago = require("utils.timeago")

local manual = {
  agentConfiguration = "Configuration details of the agent, including CPU allocation.",
  agentPoolName = "The name of the agent pool, if any.",
  createTime = "The timestamp when the task run was created.",
  customRegistries = "Custom registries involved in the task run.",
  finishTime = "The timestamp when the task run was finished.",
  id = "The unique identifier for the task run.",
  imageUpdateTrigger = "Trigger related to image updates.",
  isArchiveEnabled = "Indicates if archiving is enabled for the run.",
  lastUpdatedTime = "The last updated timestamp for the task run.",
  logArtifact = "Log artifacts associated with the task run.",
  name = "The name of the task run.",
  outputImages = "Output images from the task run.",
  platform = {
    architecture = "The architecture of the platform (e.g., amd64).",
    os = "The operating system of the platform (e.g., linux).",
    variant = "Variant of the platform, if any.",
  },
  provisioningState = "The provisioning state of the task run (e.g., Succeeded).",
  resourceGroup = "The resource group where the task run is located.",
  runErrorMessage = "Error message if the run encountered an error.",
  runId = "The run identifier.",
  runType = "The type of run (e.g., QuickRun).",
  sourceRegistryAuth = "Authentication details for the source registry.",
  sourceTrigger = "Details about the source trigger, if any.",
  startTime = "The timestamp when the task run was started.",
  status = "The status of the task run (e.g., Succeeded).",
  systemData = {
    createdAt = "The creation timestamp of the task run within system data.",
    createdBy = "The creator of the task run within system data.",
    createdByType = "The type of creator (e.g., User) within system data.",
    lastModifiedAt = "The last modification timestamp of the task run within system data.",
    lastModifiedBy = "The last modifier of the task run within system data.",
    lastModifiedByType = "The type of last modifier (e.g., User) within system data.",
  },
  task = "The name of the task associated with the run.",
  timerTrigger = "Details about the timer trigger, if any.",
  type = "The resource type of the task run.",
  updateTriggerToken = "Token for the update trigger.",
}

-- Fzf the list of runs of a particular acr task.
--
---@param task acr_task
---@param acr azure_container_registry
---@param opts? { parent_state?: string }
return function(task, acr, opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias acr_task_run { agentConfiguration: string, agentPoolName: string, createTime: string, customRegistries: string, finishTime: string, id: string, imageUpdateTrigger: string, isArchiveEnabled: string, lastUpdatedTime: string, logArtifact: string, name: string, outputImages: string, platform: { architecture: string, os: string, variant: string }, provisioningState: string, resourceGroup: string, runErrorMessage: string, runId: string, runType: string, sourceRegistryAuth: string, sourceTrigger: string, startTime: string, status: string, systemData: { createdAt: string, createdBy: string, createdByType: string, lastModifiedAt: string, lastModifiedBy: string, lastModifiedByType: string }, task: string, timerTrigger: string, type: string, updateTriggerToken: string }
  ---@type acr_task_run[]
  local runs

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local command =
      string.format("az acr task list-runs -n %s -r %s", task.name, acr.name)
    local result = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve the list of runs of the task under the azure container registry",
        result
      )
      return {}
    end

    result = vim.trim(result)
    runs = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast runs acr_task_run[]

    return utils.map(
      runs,
      function(i, run)
        return fzf_utils.join_by_delim(
          utils.ansi_codes.grey(string.format("[%s]", run.status)),
          run.name,
          run.startTime
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "ACR-Task-Runs",
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
        local run = runs[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. run.name .. " ")

        set_preview_content(vim.split(vim.inspect(run), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local run = runs[state.focused_entry_index]
        vim.fn.setreg("+", run.id)
        vim.notify(string.format([[Copied %s to clipboard]], run.id))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
