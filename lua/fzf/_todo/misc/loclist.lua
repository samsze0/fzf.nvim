local core = require("fzf.core")
local fzf_utils = require("fzf.utils")
local layouts = require("fzf.layouts")
local helpers = require("fzf.helpers")
local config = require("fzf").config
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

-- Fzf the most recent loclist of current window
--
---@param opts? { }
return function(opts)
  opts = opts_utils.extend({}, opts)

  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()

  local function get_entries()
    local ll = vim.fn.getloclist(current_win)

    return tbl_utils.map(
      ll,
      function(_, l)
        return fzf_utils.join_by_delim(
          l.bufnr,
          terminal_utils.ansi.grey(
            vim.fn.fnamemodify(vim.api.nvim_buf_get_name(l.bufnr), ":~:.")
          ),
          l.lnum,
          l.col,
          l.text
        )
      end
    )
  end

  local entries = get_entries()

  local parse_entry = function(entry)
    local bufnr, filepath, row, col =
      unpack(vim.split(entry, terminal_utils.nbsp))
    return tonumber(bufnr), filepath, tonumber(row), tonumber(col)
  end

  local layout, popups, set_preview_content, binds =
    layouts.create_nvim_preview_layout({
      preview_popup_win_options = {
        cursorline = true,
      },
    })

  core.fzf(entries, {
    prompt = "Loclist",
    layout = layout,
    main_popup = popups.main,
    binds = fzf_utils.bind_extend(binds, {
      ["+before-start"] = function(controller)
        popups.main.border:set_text(
          "bottom",
          " <select> goto buf | <w> write all changes "
        )
      end,
      ["focus"] = function(controller)
        local bufnr, filepath, row, col = parse_entry(controller.focused_entry)

        popups.nvim_preview.border:set_text(
          "top",
          " " .. vim.fn.fnamemodify(filepath, ":t") .. " "
        )

        helpers.preview_buffer(bufnr, popups.nvim_preview, {
          cursor_pos = { row = row, col = col },
        })
      end,
      ["+select"] = function(controller)
        local bufnr = parse_entry(controller.focused_entry)

        vim.cmd(string.format([[buffer %s]], bufnr))
      end,
      ["ctrl-w"] = function(controller)
        vim.cmd([[ldo update]]) -- Write all changes
      end,
    }),
    extra_args = opts_utils.extend(helpers.fzf_default_args, {
      ["--with-nth"] = "2,5",
    }),
  })
end
