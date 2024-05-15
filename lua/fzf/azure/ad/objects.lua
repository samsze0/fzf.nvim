local core = require("fzf.core")
local helpers = require("fzf.helpers")
local fzf_utils = require("fzf.utils")
local utils = require("utils")
local json = require("utils.json")
local shared = require("fzf.azure.shared")

-- If `user_id` option is given, fzf the list of azuread objects owned by the signed-in user
--
---@param opts? { user_id?: string, parent_state?: string }
return function(opts)
  opts = vim.tbl_extend("force", {}, opts or {})

  ---@alias azuread_object table<string, any>
  ---@type azuread_object[]
  local objects

  local function get_entries()
    if not shared.is_azurecli_available() then error("Azure cli not found") end

    local result
    if opts.user_id then
      result =
        -- TODO: check if the user_id is indeed the signed-in user?
        vim.fn.system("az ad signed-in-user list-owned-objects")
      if vim.v.shell_error ~= 0 then
        _error("Fail to retrieve azuread objects owned by the user", result)
        return {}
      end
    end

    result = vim.trim(result)

    -- TODO: impl something like zod?
    objects = json.parse(result) ---@diagnostic disable-line: cast-local-type
    ---@cast objects azuread_object[]

    return utils.map(
      objects,
      function(i, obj)
        return fzf_utils.join_by_delim(
          utils.ansi_codes.grey(string.format("[%s]", obj["@odata.type"])),
          obj.displayName
        )
      end
    )
  end

  local layout, popups, set_preview_content =
    helpers.create_nvim_preview_layout()

  core.fzf(get_entries(), {
    prompt = "Azuread-Objects",
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
        local obj = objects[state.focused_entry_index]

        popups.nvim_preview.border:set_text(
          "top",
          " " .. obj["@odata.type"] .. " " .. obj.displayName .. " "
        )

        set_preview_content(vim.split(vim.inspect(obj), "\n"))
        vim.bo[popups.nvim_preview.bufnr].filetype = "lua"
      end,
      ["ctrl-y"] = function(state)
        local obj = objects[state.focused_entry_index]
        vim.fn.setreg("+", obj.id)
        vim.notify(string.format([[Copied %s to clipboard]], obj.id))
      end,
    },
    extra_args = vim.tbl_extend("force", helpers.fzf_default_args, {
      ["--with-nth"] = "1..",
    }),
  }, opts.parent_state)
end
