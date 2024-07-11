local FzfController = require("fzf.core.controller")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local jumplist = require("jumplist")
local fzf_utils = require("fzf.utils")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfCodePreviewInstanceTrait : FzfController
---@field layout TUIDualPaneLayout
---@field _filepath_accessor? fun(entry: FzfEntry): string
---@field _content_accessor fun(entry: FzfEntry): string[]
---@field _row_accessor? fun(entry: FzfEntry): number
---@field _col_accessor? fun(entry: FzfEntry): number
local FzfCodePreviewInstanceTrait = {}
FzfCodePreviewInstanceTrait.__index = FzfCodePreviewInstanceTrait
FzfCodePreviewInstanceTrait.__is_class = true
setmetatable(FzfCodePreviewInstanceTrait, { __index = FzfController })

-- Configure file preview
--
---@param opts? { }
function FzfCodePreviewInstanceTrait:setup_filepreview(opts)
  opts = opts_utils.extend({}, opts)

  self:on_focus(function(payload)
    self.layout.side_popup:set_lines({})

    local focus = self.focus
    if not focus then return end

    local cursor_pos = self._row_accessor and {
      self._row_accessor(self.focus),
      self._col_accessor(self.focus),
    } or nil

    if self._filepath_accessor then
      self.layout.side_popup:show_file_content(self._filepath_accessor(self.focus), {
        cursor_pos = cursor_pos,
      })
    elseif self._content_accessor then
      self.layout.side_popup:set_lines(self._content_accessor(self.focus), {
        cursor_pos = cursor_pos,
      })
    end
  end)
end

-- TODO: move to private config
function FzfCodePreviewInstanceTrait:setup_fileopen_keymaps()
  local function highlight_row()
    if self._row_accessor ~= nil then
      vim.fn.cursor({
        self._row_accessor(self.focus),
        self._col_accessor(self.focus),
      })
    end
  end

  ---@param save_in_jumplist boolean
  ---@param open_command string
  local function open_file(save_in_jumplist, open_command)
    if not self.focus then return end

    local filepath
    
    if self._filepath_accessor then
      filepath = self._filepath_accessor(self.focus)
    else
      filepath = fzf_utils.write_to_tmpfile(self._content_accessor(self.focus))
    end

    self:hide()
    if save_in_jumplist then
      jumplist.save()
    end
    vim.cmd(([[%s %s]]):format(open_command, filepath))

    highlight_row()
  end

  self.layout.main_popup:map("<C-w>", "Open in new window", function()
    open_file(false, "vsplit")
  end)

  self.layout.main_popup:map("<C-t>", "Open in new tab", function()
    open_file(false, "tabnew")
  end)

  self.layout.main_popup:map("<CR>", "Open", function()
    open_file(true, "edit")
  end)
end

-- TODO: move to private config
function FzfCodePreviewInstanceTrait:setup_copy_filepath_keymap()
  self.layout.main_popup:map("<C-y>", "Copy filepath", function()
    if not self.focus then return end

    if not self._filepath_accessor then
      _warn("No filepath accessor provided")
      return
    end

    local filepath = self._filepath_accessor(self.focus)
    vim.fn.setreg("+", filepath)
    _info(([[Copied %s to clipboard]]):format(filepath))
  end)
end

return FzfCodePreviewInstanceTrait
