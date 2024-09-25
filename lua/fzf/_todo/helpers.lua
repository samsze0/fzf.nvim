local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local config = require("fzf").config
local jumplist = require("jumplist")
local NuiEvent = require("nui.utils.autocmd").event
local layouts = require("fzf.layouts")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

-- Layout & popup configurations for grep
--
---@alias FzfLayoutTriplePane2ColumnGrepOptions { filepath_accessor: (fun(focus: any): string), row_accessor: (fun(focus: any): number), col_accessor: (fun(focus: any): number), display_accessor?: (fun(focus: any): string), main_popup?: FzfLayoutMainPopupOptions, textarea_popup?: FzfLayoutSidePopupOptions, preview_popup?: FzfLayoutSidePopupOptions }
---@param controller FzfController
---@param opts FzfLayoutTriplePane2ColumnGrepOptions
---@return NuiLayout, { main: FzfMainPopup, side: { textarea: FzfSidePopup, preview: FzfSidePopup } }
M.triple_pane_2_column_grep = function(controller, opts)
  opts = opts_utils.deep_extend({
    textarea_popup = {
      extra_options = {
        win_options = {
          number = true,
        },
      },
    },
    preview_popup = {
      extra_options = {
        win_options = {
          number = true,
          cursorline = true,
        },
      },
    },
  }, opts)
  ---@cast opts FzfLayoutTriplePane2ColumnGrepOptions

  local layout, popups = layouts.triple_pane_2_column({
    main_popup = opts.main_popup,
    top_side_popup = opts.textarea_popup,
    bottom_side_popup = opts.preview_popup,
  })

  M.configure_controller_ui_hooks(layout, popups.main, controller)
  M.configure_remote_nav(popups.main, popups.side.bottom)
  M.configure_main_popup_top_border_text(popups.main, controller)
  M.configure_main_popup_bottom_border_text(popups.main, controller)
  M.configure_side_popup_top_border_text(popups.side.bottom, controller, {
    display_accessor = opts.display_accessor,
  })

  M.configure_filepreview(popups.main, popups.side.bottom, controller, {
    setup_file_open_keymaps = true,
    highlight_pos = true,
    filepath_accessor = opts.filepath_accessor,
    row_accessor = opts.row_accessor,
    col_accessor = opts.col_accessor,
  })

  local function refresh_preview()
    if not controller.focus then return end

    local focus = controller.focus

    local replacement = table.concat(popups.side.top:get_lines(), "\n")

    local filepath = opts.filepath_accessor(focus)

    if #replacement > 0 then
      popups.side.bottom:set_lines(
        terminal_utils.systemlist_unsafe(
          ([[cat "%s" | sed -E "%ss/%s/%s/g"]]):format(
            filepath,
            opts.filepath_accessor(focus),
            controller.query,
            replacement
          )
        )
      )
      local filetype = vim.filetype.match({
        filename = vim.fn.fnamemodify(filepath, ":t"),
        contents = vim.fn.readfile(filepath),
      })
      vim.bo[popups.side.bottom.bufnr].filetype = filetype or ""
    else
      -- TODO: can optimize this if grep is file mode
      popups.side.bottom:show_file_content(opts.filepath_accessor(focus), {
        cursor_pos = { opts.row_accessor(focus), opts.col_accessor(focus) },
      })
    end
  end

  controller:subscribe("focus", nil, function(payload) refresh_preview() end)
  controller:subscribe(
    "change",
    nil,
    function(payload) controller:refresh() end
  )
  popups.side.top:on(
    { NuiEvent.TextChanged, NuiEvent.TextChangedI },
    refresh_preview
  )

  popups.main:map(
    "<C-l>",
    "Send to loclist",
    function() controller:send_selections_to_loclist() end
  )

  popups.main:map("<C-p>", "Replace", function()
    controller:send_selections_to_loclist({
      callback = function()
        local search = controller.query
        local replacement = table.concat(popups.side.top:get_lines(), "\n")
        vim.cmd(([[ldo %%s/%s/%s/g]]):format(search, replacement)) -- Run substitution
      end,
    })
  end)

  return layout,
    {
      main = popups.main,
      side = {
        textarea = popups.side.top,
        preview = popups.side.bottom,
      },
    }
end

return M
