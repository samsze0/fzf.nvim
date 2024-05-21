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

-- Configure remote navigation between main and target popup.
--
---@param main_popup FzfMainPopup
---@param target_popup FzfSidePopup
M.configure_remote_nav = function(main_popup, target_popup)
  main_popup:map_remote(
    target_popup,
    "Scroll preview up",
    config.keymaps.remote_scroll_preview_pane.up
  )
  main_popup:map_remote(
    target_popup,
    "Scroll preview left",
    config.keymaps.remote_scroll_preview_pane.left
  )
  main_popup:map_remote(
    target_popup,
    "Scroll preview down",
    config.keymaps.remote_scroll_preview_pane.down
  )
  main_popup:map_remote(
    target_popup,
    "Scroll preview right",
    config.keymaps.remote_scroll_preview_pane.right
  )
end

-- Configure file open keymaps
--
---@param main_popup FzfMainPopup
---@param controller FzfController
---@param opts { highlight_pos: boolean, filepath_accessor: (fun(focus: any): string), row_accessor?: (fun(focus: any): number), col_accessor?: (fun(focus: any): number) }
M.configure_file_open_keymaps = function(main_popup, controller, opts)
  opts = opts_utils.extend({
    filepath_accessor = function(focus) return focus.filepath end,
    row_accessor = function(focus) return focus.row end,
    col_accessor = function(focus) return focus.col end,
  }, opts)

  main_popup:map("<C-w>", "Open in new window", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    vim.cmd(([[vsplit %s]]):format(filepath))

    if opts.highlight_pos then
      vim.fn.cursor({
        opts.row_accessor(controller.focus),
        opts.col_accessor(controller.focus),
      })
    end
  end)

  main_popup:map("<C-t>", "Open in new tab", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    vim.cmd(([[tabnew %s]]):format(filepath))

    if opts.highlight_pos then
      vim.fn.cursor({
        opts.row_accessor(controller.focus),
        opts.col_accessor(controller.focus),
      })
    end
  end)

  main_popup:map("<CR>", "Open", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    jumplist.save()
    vim.cmd(([[e %s]]):format(filepath))

    if opts.highlight_pos then
      vim.fn.cursor({
        opts.row_accessor(controller.focus),
        opts.col_accessor(controller.focus),
      })
    end
  end)
end

-- Configure file preview.
--
---@param main_popup FzfMainPopup
---@param preview_popup FzfSidePopup
---@param controller FzfController
---@param opts { setup_file_open_keymaps?: boolean, highlight_pos: boolean, filepath_accessor: (fun(focus: any): string), row_accessor?: (fun(focus: any): number), col_accessor?: (fun(focus: any): number) }
M.configure_filepreview = function(main_popup, preview_popup, controller, opts)
  opts = opts_utils.extend({
    filepath_accessor = function(focus) return focus.filepath end,
    row_accessor = function(focus) return focus.row end,
    col_accessor = function(focus) return focus.col end,
  }, opts)

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus

    preview_popup:set_lines({})

    if not focus then return end

    local cursor_pos = opts.highlight_pos
        and { opts.row_accessor(focus), opts.col_accessor(focus) }
      or nil

    preview_popup:show_file_content(
      opts.filepath_accessor(focus),
      { cursor_pos = cursor_pos }
    )
  end)

  -- TODO: source keybinds from config

  main_popup:map("<C-y>", "Copy filepath", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    vim.fn.setreg("+", filepath)
    _info(([[Copied %s to clipboard]]):format(filepath))
  end)

  if opts.setup_file_open_keymaps then
    M.configure_file_open_keymaps(main_popup, controller, opts)
  end
end

-- Configure main popup's top border text.
--
---@param main_popup FzfMainPopup
---@param controller FzfController
M.configure_main_popup_top_border_text = function(main_popup, controller)
  local refresh = function()
    ---@type FzfController[]
    local controller_stack = {}

    ---@type FzfController?
    local c = controller
    while c do
      table.insert(controller_stack, 1, c)
      c = c:parent()
    end

    local selector_breadcrumbs = table.concat(
      tbl_utils.map(controller_stack, function(_, e) return e.name end),
      " > "
    )

    local icons = {}
    if controller:fetching_entries() then table.insert(icons, "󱥸") end
    if controller:is_entries_stale() then table.insert(icons, "") end
    main_popup.border:set_text(
      "top",
      ([[ %s %s ]]):format(selector_breadcrumbs, table.concat(icons, " "))
    )
  end

  controller:on_fetching_entries_change(refresh)
  controller:on_is_entries_stale_change(refresh)

  refresh()
end

-- Configure main popup's bottom border text.
--
---@param main_popup FzfMainPopup
---@param controller FzfController
M.configure_main_popup_bottom_border_text = function(main_popup, controller)
  local keymap_helper = table.concat(
    tbl_utils.map(
      main_popup:keymaps(),
      function(key, name) return key .. " " .. name end
    ),
    " | "
  )
  main_popup.border:set_text("bottom", " " .. keymap_helper)
end

-- Configure side popup's top border text.
--
---@param side_popup FzfSidePopup
---@param controller FzfController
---@param opts? { display_accessor: (fun(focus: any): string) }
M.configure_side_popup_top_border_text = function(side_popup, controller, opts)
  opts = opts_utils.extend({
    display_accessor = function(focus) return focus.display end,
  }, opts)

  controller:subscribe("focus", nil, function(payload)
    if not controller.focus then return end

    side_popup.border:set_text(
      "top",
      " "
        .. terminal_utils.strip_ansi_codes(opts.display_accessor(controller.focus))
        .. " "
    )
  end)
end

---@param layout NuiLayout
---@param main_popup FzfMainPopup
---@param controller FzfController
M.configure_controller_ui_hooks = function(layout, main_popup, controller)
  controller:set_ui_hooks({
    show = function() layout:show() end,
    hide = function() layout:hide() end,
    focus = function() main_popup:focus() end,
    destroy = function() layout:unmount() end,
  })
end

-- Layout & popup configurations for previewing terminal output
-- To be used in conjunction with `terminal-filetype`
--
---@alias FzfLayoutDualPaneTerminalPreviewOptions { display_accessor?: (fun(focus: any): string), main_popup?: FzfLayoutMainPopupOptions, side_popup?: FzfLayoutSidePopupOptions }
---@param controller FzfController
---@param opts? FzfLayoutDualPaneTerminalPreviewOptions
---@return NuiLayout, { main: FzfMainPopup, side: FzfSidePopup }
M.dual_pane_terminal_preview = function(controller, opts)
  opts = opts_utils.deep_extend({
    side_popup = {
      extra_options = {
        buf_options = {
          filetype = "terminal",
          synmaxcol = 0,
        },
        win_options = {
          number = true,
          conceallevel = 3,
          concealcursor = "nvic",
        },
      },
    },
  }, opts)
  ---@cast opts FzfLayoutDualPaneTerminalPreviewOptions

  local layout, popups = layouts.dual_pane({
    main_popup = opts.main_popup,
    side_popup = opts.side_popup,
  })

  M.configure_controller_ui_hooks(layout, popups.main, controller)
  M.configure_remote_nav(popups.main, popups.side)
  M.configure_main_popup_top_border_text(popups.main, controller)
  M.configure_main_popup_bottom_border_text(popups.main, controller)
  M.configure_side_popup_top_border_text(popups.side, controller, {
    display_accessor = opts.display_accessor,
  })

  return layout, popups
end

-- Layout & popup configurations for previewing code
--
---@alias FzfLayoutDualPaneCodePreviewOptions { highlight_pos: boolean, filepath_accessor: (fun(focus: any): string), row_accessor?: (fun(focus: any): number), col_accessor?: (fun(focus: any): number), display_accessor?: (fun(focus: any): string), main_popup?: FzfLayoutMainPopupOptions, side_popup?: FzfLayoutSidePopupOptions }
---@param controller FzfController
---@param opts FzfLayoutDualPaneCodePreviewOptions
---@return NuiLayout, { main: FzfMainPopup, side: FzfSidePopup }
M.dual_pane_code_preview = function(controller, opts)
  opts = opts_utils.deep_extend({
    side_popup = {
      extra_options = {
        win_options = {
          number = true,
          cursorline = true,
        },
      },
    },
  }, opts)
  ---@cast opts FzfLayoutDualPaneCodePreviewOptions

  local layout, popups = layouts.dual_pane({
    main_popup = opts.main_popup,
    side_popup = opts.side_popup,
  })

  M.configure_controller_ui_hooks(layout, popups.main, controller)
  M.configure_remote_nav(popups.main, popups.side)
  M.configure_main_popup_top_border_text(popups.main, controller)
  M.configure_main_popup_bottom_border_text(popups.main, controller)
  M.configure_side_popup_top_border_text(popups.side, controller, {
    display_accessor = opts.display_accessor,
  })

  M.configure_filepreview(popups.main, popups.side, controller, {
    setup_file_open_keymaps = true,
    highlight_pos = opts.highlight_pos,
    filepath_accessor = opts.filepath_accessor,
    row_accessor = opts.row_accessor,
    col_accessor = opts.col_accessor,
  })

  return layout, popups
end

-- Layout & popup configurations for previewing lua object
--
---@alias FzfLayoutDualPaneLuaObjectPreviewOptions { lua_object_accessor: (fun(focus: any): string), display_accessor?: (fun(focus: any): string), main_popup?: FzfLayoutMainPopupOptions, side_popup?: FzfLayoutSidePopupOptions }
---@param controller FzfController
---@param opts FzfLayoutDualPaneLuaObjectPreviewOptions
---@return NuiLayout, { main: FzfMainPopup, side: FzfSidePopup }
M.dual_pane_lua_object_preview = function(controller, opts)
  opts = opts_utils.deep_extend({}, opts)
  ---@cast opts FzfLayoutDualPaneLuaObjectPreviewOptions

  local layout, popups = layouts.dual_pane({
    main_popup = opts.main_popup,
    side_popup = opts.side_popup,
  })

  M.configure_controller_ui_hooks(layout, popups.main, controller)
  M.configure_remote_nav(popups.main, popups.side)
  M.configure_main_popup_top_border_text(popups.main, controller)
  M.configure_main_popup_bottom_border_text(popups.main, controller)
  M.configure_side_popup_top_border_text(popups.side, controller, {
    display_accessor = opts.display_accessor,
  })

  vim.bo[popups.side.bufnr].filetype = "lua"

  controller:subscribe("focus", nil, function(payload)
    local focus = controller.focus

    popups.side:set_lines({})

    if not focus then return end

    popups.side:set_lines(
      vim.split(vim.inspect(opts.lua_object_accessor(focus)), "\n")
    )
  end)

  return layout, popups
end

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

-- Layout & popup configurations for code diff
--
---@alias FzfLayoutTriplePaneCodeDiffOptions { filepath_accessor: (fun(focus: any): string), row_accessor: (fun(focus: any): number), col_accessor: (fun(focus: any): number), display_accessor?: (fun(focus: any): string), main_popup?: FzfLayoutMainPopupOptions, left_preview_popup?: FzfLayoutSidePopupOptions, right_preview_popup?: FzfLayoutSidePopupOptions }
---@param controller FzfController
---@param opts? FzfLayoutTriplePaneCodeDiffOptions
---@return NuiLayout, { main: FzfMainPopup, side: { left: FzfSidePopup, right: FzfSidePopup } }
M.triple_pane_code_diff = function(controller, opts)
  opts = opts_utils.deep_extend({
    left_preview_popup = {
      extra_options = {
        win_options = {
          number = true,
        },
      },
    },
    right_preview_popup = {
      extra_options = {
        win_options = {
          number = true,
        },
      },
    },
  }, opts)
  ---@cast opts FzfLayoutTriplePaneCodeDiffOptions

  local layout, popups = layouts.triple_pane({
    main_popup = opts.main_popup,
    left_side_popup = opts.left_preview_popup,
    right_side_popup = opts.right_preview_popup,
  })

  M.configure_controller_ui_hooks(layout, popups.main, controller)
  M.configure_remote_nav(popups.main, popups.side.left)
  M.configure_main_popup_top_border_text(popups.main, controller)
  M.configure_main_popup_bottom_border_text(popups.main, controller)
  M.configure_side_popup_top_border_text(popups.side.left, controller, {
    display_accessor = opts.display_accessor,
  })

  return layout, popups
end

return M
