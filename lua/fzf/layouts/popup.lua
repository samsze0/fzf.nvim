local NuiLayout = require("nui.layout")
local NuiPopup = require("nui.popup")
local NuiEvent = require("nui.utils.autocmd").event
local utils = require("utils")

local base_popup_config = {
  focusable = true,
  border = {
    style = "rounded",
    text = {
      top = "", -- Border text not showing if undefined
      bottom = "",
      top_align = "center",
      bottom_align = "center",
    },
  },
  buf_options = {
    modifiable = true,
  },
  win_options = {
    winblend = 0,
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    number = false,
    wrap = false,
  },
}

-- TODO: restrict access to NuiBorder directly by creating a proxy table?
-- TODO: hijack/proxy map method and record the mappings so that we can warn user if a key is already bind to something else

---@class FzfMainPopup: NuiPopup
---@field _fzf_keymaps table<string, string> Mappings of key to name (of the handler)
local MainPopup = {}
MainPopup.__index = MainPopup
MainPopup.__is_class = true
setmetatable(MainPopup, { __index = NuiPopup })

---@param config? nui_popup_options
---@return FzfMainPopup
function MainPopup.new(config)
  config = utils.opts_deep_extend(base_popup_config, {
    enter = false, -- This can mute BufEnter event
    border = {
      text = {
        top_align = "left",
        bottom_align = "left",
      },
    },
    buf_options = {
      modifiable = false,
      filetype = "fzf",
    },
    win_options = {},
  }, config)

  local obj = NuiPopup(config)
  setmetatable(obj, MainPopup)
  ---@cast obj FzfMainPopup

  obj._fzf_keymaps = {}

  obj:on(NuiEvent.BufEnter, function() vim.cmd("startinsert!") end)

  return obj
end

function MainPopup:focus() vim.api.nvim_set_current_win(self.winid) end

---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function MainPopup:map(key, name, handler, opts)
  opts = utils.opts_extend({ force = false }, opts)
  name = name or "?"

  if self._fzf_keymaps[key] and not opts.force then
    error(
      ("Key %s is already mapped to %s"):format(key, self._fzf_keymaps[key])
    )
    return
  end
  NuiPopup.map(self, "t", key, handler)
  self._fzf_keymaps[key] = name
end

-- Get current mappings of keys to handler names
---@return table<string, string>
function MainPopup:keymaps() return self._fzf_keymaps end

---@param popup FzfSidePopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function MainPopup:map_remote(popup, name, key, opts)
  self:map(key, name, function()
    -- Looks like window doesn't get redrawn if we don't switch to it
    -- vim.api.nvim_win_call(popup.winid, function() vim.api.nvim_input(key) end)

    vim.api.nvim_set_current_win(popup.winid)
    vim.api.nvim_input(key)
    -- Because nvim_input is non-blocking, so we need to schedule the switch such that the switch happens after the input
    vim.schedule(function() vim.api.nvim_set_current_win(self.winid) end)
  end, opts)
end

---@class FzfSidePopup: NuiPopup
local SidePopup = {}
SidePopup.__index = SidePopup
SidePopup.__is_class = true
setmetatable(SidePopup, { __index = NuiPopup })

---@param config? nui_popup_options
---@return FzfSidePopup
function SidePopup.new(config)
  config = utils.opts_deep_extend(base_popup_config, {}, config)

  local obj = NuiPopup(config)
  setmetatable(obj, SidePopup)
  ---@cast obj FzfSidePopup

  return obj
end

function SidePopup:focus() vim.api.nvim_set_current_win(self.winid) end

---@return string[]
function SidePopup:get_lines()
  return vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
end

---@param lines string[]
---@param opts? { cursor_pos?: number[] }
function SidePopup:set_lines(lines, opts)
  opts = utils.opts_extend({}, opts)

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  if opts.cursor_pos then
    vim.api.nvim_win_set_cursor(self.winid, opts.cursor_pos or { 1, 0 })
    vim.api.nvim_win_call(self.winid, function() vim.cmd("normal! zz") end)
  end
end

---@param path string
---@param opts? { cursor_pos?: number[] }
function SidePopup:show_file_content(path, opts)
  opts = utils.opts_extend({}, opts)

  if vim.fn.filereadable(path) ~= 1 then
    self:set_lines({ "File not readable, or doesnt exist" })
    return
  end

  local is_binary = utils
    .system("file --mime " .. path, {
      on_error = function()
        self:set_lines({
          "Cannot determine if file is binary",
        })
      end,
    })
    :match("charset=binary")

  if is_binary then
    self:set_lines({ "No preview available for binary file" })
    return
  end

  local lines = vim.fn.readfile(path)
  local filename = vim.fn.fnamemodify(path, ":t")
  local filetype = vim.filetype.match({
    filename = filename,
    contents = lines,
  })
  self:set_lines(lines, { cursor_pos = opts.cursor_pos })
  vim.bo[self.bufnr].filetype = filetype or ""
end

---@param buf number
---@param opts? { cursor_pos?: number[] }
function SidePopup:show_buf_content(buf, opts)
  opts = opts or {}

  local path = vim.api.nvim_buf_get_name(buf)
  self:show_file_content(path, { cursor_pos = opts.cursor_pos })
end

return {
  MainPopup = MainPopup,
  SidePopup = SidePopup,
}
