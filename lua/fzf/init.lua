local opts_utils = require("utils.opts")

local M = {}

---@alias FzfNotifier { info?: fun(message: string), warn?: fun(message: string), error?: fun(message: string) }
---@alias FzfKeymapsOptions { move_to_pane?: { left?: string, down?: string, up?: string, right?: string }, remote_scroll_preview_pane?: { up?: string, down?: string, left?: string, right?: string } }
---@alias FzfOptions { keymaps?: FzfKeymapsConfig, default_extra_args?: UtilsShellOpts, default_extra_env_vars?: UtilsShellOpts, default_rg_args?: UtilsShellOpts }

M.config = {
  notifier = {
    info = function(message)
      vim.notify(message, vim.log.levels.INFO)
    end,
    warn = function(message)
      vim.notify(message, vim.log.levels.WARN)
    end,
    error = function(message)
      vim.notify(message, vim.log.levels.ERROR)
    end,
  },
  keymaps = {
    move_to_pane = {
      left = "<C-s>",
      down = "<C-d>",
      up = "<C-e>",
      right = "<C-f>",
    },
    remote_scroll_preview_pane = {
      up = "<S-Up>",
      down = "<S-Down>",
      left = "<S-Left>",
      right = "<S-Right>",
    },
  },
  default_extra_args = {
    ["--scroll-off"] = "2",
    -- ["--with-nth"] = "1..",  -- Decrease performance: https://github.com/junegunn/fzf?tab=readme-ov-file#performance
  },
  default_extra_env_vars = {
    -- ["SHELL"] = "$(which bash)",
  },
  default_rg_args = {
    ["--smart-case"] = "",
    ["--no-ignore"] = "",
    ["--hidden"] = "",
    ["--trim"] = "",
    ["--color"] = "always",
    ["--colors"] = {
    "'match:fg:blue'",
    "'path:none'",
    "'line:none'",
    },
    ["--no-column"] = "",
    ["--line-number"] = "",
    ["--no-heading"] = "",
  },
}

---@param opts? FzfOptions
function M.setup(opts)
  M.config = opts_utils.deep_extend(M.config, opts)
end

return M