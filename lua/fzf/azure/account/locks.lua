local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

-- Fzf all azure subscription-level locks
--
---@param opts? { parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias subscription_level_lock { id: string, level: string, name: string, notes: string, owners: string[], type: string }
  ---@type subscription_level_lock[]
  local locks

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result = vim.fn.system("az account lock list")
    if vim.v.shell_error ~= 0 then
      _error("Fail to retrieve azure subscription-level locks", result)
      return {}
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    locks = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast locks subscription_level_lock[]

    return utils.map(
      locks,
      function(_, l)
        return fzf_utils.join_by_delim(
          utils.ansi_codes.grey(string.format("[%s]", l.level)),
          l.name
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azure-Subscription-Level-Locks",
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
        local lock = locks[state.focused_entry_index]

        popups.nvim_preview.border:set_text("top", " " .. lock.name .. " ")

        set_preview_content(vim.split(vim.inspect(lock), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local lock = locks[state.focused_entry_index]
        vim.fn.setreg("+", lock.id)
        vim.notify(string.format([[Copied %s to clipboard]], lock.id))
      end,
      ["ctrl-x"] = function(state)
        local lock = locks[state.focused_entry_index]

        vim.fn.system(
          string.format([[az account lock delete --ids %s]], lock.id)
        )
        if vim.v.shell_error ~= 0 then
          _error("Fail to delete subscription-level lock", lock.name)
          return
        end
        core.send_to_fzf(state.id, fzf_utils.reload_action(get_entries()))
      end,
      ["ctrl-a"] = function(state)
        -- TODO: create lock
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
