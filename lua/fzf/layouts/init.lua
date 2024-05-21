local NuiLayout = require("nui.layout")
local MainPopup = require("fzf.layouts.popup").MainPopup
local SidePopup = require("fzf.layouts.popup").SidePopup
local config = require("fzf").config
local opts_utils = require("utils.opts")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

-- TODO: generics on Popup class

---@alias FzfLayoutMainPopupOptions { class?: FzfMainPopup }
---@alias FzfLayoutSidePopupOptions { class?: FzfSidePopup, extra_options?: nui_popup_options }

---@alias FzfLayoutSinglePaneOptions { main_popup?: FzfLayoutMainPopupOptions }
---@param opts? FzfLayoutSinglePaneOptions
---@return NuiLayout layout, { main: FzfMainPopup } popups
M.single_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
  }, opts)
  ---@cast opts FzfLayoutSinglePaneOptions

  local main_popup = opts.main_popup.class.new()

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "95%",
        height = "95%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "100%" }),
    }, {})
  )

  return layout, {
    main = main_popup,
  }
end

---@alias FzfLayoutDualPaneOptions { main_popup?: FzfLayoutMainPopupOptions, side_popup?: FzfLayoutSidePopupOptions }
---@param opts? FzfLayoutDualPaneOptions
---@return NuiLayout, { main: FzfMainPopup, side: FzfSidePopup }
M.dual_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
    side_popup = {
      class = SidePopup,
    },
  }, opts)
  ---@cast opts FzfLayoutDualPaneOptions

  local main_popup = opts.main_popup.class.new()

  local side_popup = opts.side_popup.class.new(opts.side_popup.extra_options)

  local popups = { main = main_popup, side = side_popup }

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "95%",
        height = "95%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "50%" }),
      NuiLayout.Box(side_popup, { size = "50%" }),
    }, { dir = "row" })
  )

  main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() vim.api.nvim_set_current_win(side_popup.winid) end
  )

  side_popup:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  return layout, popups
end

---@alias FzfLayoutTriplePaneOptions { main_popup?: FzfLayoutMainPopupOptions, left_side_popup?: FzfLayoutSidePopupOptions, right_side_popup?: FzfLayoutSidePopupOptions }
---@param opts? FzfLayoutTriplePaneOptions
---@return NuiLayout layout, { main: FzfMainPopup, side: { left: FzfSidePopup, right: FzfSidePopup } } popups
M.triple_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
    left_side_popup = {
      class = SidePopup,
    },
    right_side_popup = {
      class = SidePopup,
    },
  }, opts)
  ---@cast opts FzfLayoutTriplePaneOptions

  local main_popup = MainPopup.new()

  local side_popups = {
    left = opts.left_side_popup.class.new(opts.left_side_popup.extra_options),
    right = opts.right_side_popup.class.new(
      opts.right_side_popup.extra_options
    ),
  }

  local popups = { main = main_popup, side = side_popups }

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "95%",
        height = "95%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "30%" }),
      NuiLayout.Box(side_popups.left, { size = "35%" }),
      NuiLayout.Box(side_popups.right, { size = "35%" }),
    }, { dir = "row" })
  )

  main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() vim.api.nvim_set_current_win(side_popups.left.winid) end
  )

  side_popups.left:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  side_popups.left:map(
    "n",
    config.keymaps.move_to_pane.right,
    function() vim.api.nvim_set_current_win(side_popups.right.winid) end
  )

  side_popups.right:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(side_popups.left.winid) end
  )

  return layout, popups
end

---@alias FzfLayoutTriplePane2ColumnOptions { main_popup?: FzfLayoutMainPopupOptions, top_side_popup?: FzfLayoutSidePopupOptions, bottom_side_popup?: FzfLayoutSidePopupOptions }
---@param opts? FzfLayoutTriplePane2ColumnOptions
---@return NuiLayout, { main: FzfMainPopup, side: { top: FzfSidePopup, bottom: FzfSidePopup } }
M.triple_pane_2_column = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
    top_side_popup = {
      class = SidePopup,
    },
    bottom_side_popup = {
      class = SidePopup,
    },
  }, opts)
  ---@cast opts FzfLayoutTriplePane2ColumnOptions

  local main_popup = MainPopup.new()

  local side_popups = {
    top = opts.top_side_popup.class.new(opts.top_side_popup.extra_options),
    bottom = opts.bottom_side_popup.class.new(
      opts.bottom_side_popup.extra_options
    ),
  }

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "90%",
        height = "90%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "50%" }),
      NuiLayout.Box({
        NuiLayout.Box(side_popups.top, { size = "20%" }),
        NuiLayout.Box(side_popups.bottom, { grow = 1 }),
      }, { size = "50%", dir = "col" }),
    }, { dir = "row" })
  )

  main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() vim.api.nvim_set_current_win(side_popups.top.winid) end
  )

  side_popups.top:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  side_popups.top:map(
    "n",
    config.keymaps.move_to_pane.bottom,
    function() vim.api.nvim_set_current_win(side_popups.bottom.winid) end
  )

  side_popups.bottom:map(
    "n",
    config.keymaps.move_to_pane.top,
    function() vim.api.nvim_set_current_win(side_popups.top.winid) end
  )

  side_popups.bottom:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  return layout, {
    main = main_popup,
    side = side_popups,
  }
end

return M
