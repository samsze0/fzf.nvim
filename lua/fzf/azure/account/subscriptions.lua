local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

-- Fzf all azure subscriptions owned by the logged in account (both enabled and disabled)
--
---@param opts? { parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@type number
  local initial_pos

  ---@alias azure_subscription { cloudName: string, homeTenantId: string, id: string, isDefault: boolean, managedByTenants: string[], name: string, state: string, tenantId: string, user: { name: string, type: string } }
  ---@type azure_subscription[]
  local subscriptions

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result = vim.fn.system("az account list --all")
    if vim.v.shell_error ~= 0 then
      _error(
        "Fail to retrieve azure subscriptions for the signed-in account",
        result
      )
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    subscriptions = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast subscriptions azure_subscription[]

    return utils.map(subscriptions, function(i, acc)
      if acc.isDefault then initial_pos = i end

      return fzf_utils.join_by_delim(
        acc.isDefault and utils.ansi_codes.blue("") or " ",
        acc.state == "Enabled" and acc.name or utils.ansi_codes.grey(acc.name)
      )
    end)
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-Subscriptions",
    initial_position = initial_pos,
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
        local sub = subscriptions[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. sub.name .. " ")

        set_preview_content(vim.split(vim.inspect(sub), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local sub = subscriptions[state.focused_entry_index]
        vim.fn.setreg("+", sub.id)
        vim.notify(string.format([[Copied %s to clipboard]], sub.id))
      end,
      ["left"] = function(state)
        local sub = subscriptions[state.focused_entry_index]

        vim.fn.system(
          string.format([[az account set --subscription %s]], sub.id)
        )
        if vim.v.shell_error ~= 0 then
          _error(
            "Fail to set subscription",
            sub.name,
            "to be the default one"
          )
          return
        end
        core.send_to_fzf(state.id, fzf_utils.reload_action(get_entries()))
      end,
      ["ctrl-a"] = function(state)
        -- TODO: create access-token
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
