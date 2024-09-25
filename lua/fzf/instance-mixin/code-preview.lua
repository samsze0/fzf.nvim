local FzfController = require("fzf.core.controller")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local jumplist = require("jumplist")
local file_utils = require("utils.files")
local NuiText = require("nui.text")
local str_utils = require("utils.string")
local oop_utils = require("utils.oop")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@class FzfCodePreviewLayout : FzfLayout
---@field underlay_popups { main: FzfTUIPopup, preview: FzfUnderlayPopup }

---@alias FzfCodePreviewInstanceMixin.accessor fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@alias FzfCodePreviewInstanceMixin.row_accessor fun(entry: FzfEntry): number
---@alias FzfCodePreviewInstanceMixin.col_accessor fun(entry: FzfEntry): number

---@class FzfCodePreviewInstanceMixin : FzfController
---@field layout FzfCodePreviewLayout
---@field _accessor? FzfCodePreviewInstanceMixin.accessor
---@field _row_accessor? FzfCodePreviewInstanceMixin.row_accessor
---@field _col_accessor? FzfCodePreviewInstanceMixin.col_accessor
local FzfCodePreviewInstanceMixin = oop_utils.new_class(FzfController)

-- Configure file preview
--
---@param opts? { }
function FzfCodePreviewInstanceMixin:setup_filepreview(opts)
  opts = opts_utils.extend({}, opts)

  local preview_popup = self.layout.underlay_popups.preview

  self:on_focus(function(payload)
    preview_popup:set_lines({})

    local focus = self.focus
    if not focus then return end

    local cursor_pos = self._row_accessor
        and {
          self._row_accessor(self.focus),
          self._col_accessor and self._col_accessor(self.focus) or 1,
        }
      or nil

    local x = self._accessor(self.focus)
    if x.filepath then
      preview_popup:show_file_content(x.filepath, {
        cursor_pos = cursor_pos,
      })
    elseif x.lines then
      preview_popup:set_lines(x.lines, {
        cursor_pos = cursor_pos,
        filetype = x.filetype,
      })
    end
  end)
end

-- TODO: move to private config
function FzfCodePreviewInstanceMixin:setup_fileopen_keymaps()
  local function highlight_row()
    if self._row_accessor ~= nil then
      vim.fn.cursor({
        self._row_accessor(self.focus),
        self._col_accessor and self._col_accessor(self.focus) or 1,
      })
    end
  end

  ---@param save_in_jumplist boolean
  ---@param open_command string
  local function open_file(save_in_jumplist, open_command)
    if not self.focus then return end

    local filepath
    local filetype

    local x = self._accessor(self.focus)
    if x.filepath then
      filepath = x.filepath
    else
      filepath = file_utils.write_to_tmpfile(x.lines)
    end
    filetype = x.filetype

    self:hide()
    if save_in_jumplist then jumplist.save() end
    vim.cmd(([[%s %s]]):format(open_command, filepath))

    if filetype then vim.bo.filetype = filetype end

    highlight_row()
  end

  local main_popup = self.layout.underlay_popups.main

  main_popup:map(
    "<C-w>",
    "Open in new window",
    function() open_file(false, "vsplit") end
  )

  main_popup:map(
    "<C-t>",
    "Open in new tab",
    function() open_file(false, "tabnew") end
  )

  main_popup:map("<CR>", "Open", function() open_file(true, "edit") end)
end

-- TODO: move to private config
function FzfCodePreviewInstanceMixin:setup_copy_filepath_keymap()
  local main_popup = self.layout.underlay_popups.main

  main_popup:map("<C-y>", "Copy filepath", function()
    if not self.focus then return end

    local x = self._accessor(self.focus)
    if not x.filepath then
      _warn("No filepath accessor provided")
      return
    end

    local filepath = x.filepath
    vim.fn.setreg("+", filepath)
    _info(([[Copied %s to clipboard]]):format(filepath))
  end)
end

function FzfCodePreviewInstanceMixin:setup_filetype_border_component()
  local preview_popup = self.layout.underlay_popups.preview

  local border_component = preview_popup.bottom_border_text:append("right")

  self:on_focus(function(payload)
    local entry = payload.entry
    if not entry then return end

    ---@cast entry FzfFileEntry

    local preview_buf = preview_popup:get_buffer()

    if not preview_buf then return end

    local filetype = vim.bo[preview_buf].filetype
    ---@cast filetype string
    border_component:render(
      NuiText(
        str_utils.title_case(filetype),
        config.highlight_groups.border_text.filetype
      )
    )
  end)
end

return FzfCodePreviewInstanceMixin
