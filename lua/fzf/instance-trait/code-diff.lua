local FzfController = require("fzf.core.controller")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local jumplist = require("jumplist")
local fzf_utils = require("fzf.utils")
local vimdiff_utils = require("utils.vimdiff")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfCodeDiffInstanceTrait : FzfController
---@field layout TUITriplePaneLayout
---@field _a_filepath_accessor? fun(entry: FzfEntry): string
---@field _b_filepath_accessor? fun(entry: FzfEntry): string
---@field _a_content_accessor? fun(entry: FzfEntry): string[]
---@field _b_content_accessor? fun(entry: FzfEntry): string[]
---@field _picker fun(entry: FzfEntry): ("a" | "b")
local FzfCodeDiffInstanceTrait = {}
FzfCodeDiffInstanceTrait.__index = FzfCodeDiffInstanceTrait
FzfCodeDiffInstanceTrait.__is_class = true
setmetatable(FzfCodeDiffInstanceTrait, { __index = FzfController })

function FzfCodeDiffInstanceTrait:setup_vimdiff()
  vimdiff_utils.diff_bufs(
    self.layout.side_popups.left.bufnr,
    self.layout.side_popups.right.bufnr
  )
end

-- Configure file preview
--
---@param opts? { }
function FzfCodeDiffInstanceTrait:setup_filepreview(opts)
  opts = opts_utils.extend({}, opts)

  self:on_focus(function(payload)
    self.layout.side_popups.left:set_lines({})
    self.layout.side_popups.right:set_lines({})

    local focus = self.focus
    if not focus then return end

    if self._a_filepath_accessor then
      self.layout.side_popups.left:show_file_content(self._a_filepath_accessor(self.focus))
    elseif self._a_content_accessor then
      self.layout.side_popups.left:set_lines(self._a_content_accessor(self.focus))
    end

    if self._b_filepath_accessor then
      self.layout.side_popups.right:show_file_content(self._b_filepath_accessor(self.focus))
    elseif self._b_content_accessor then
      self.layout.side_popups.right:set_lines(self._b_content_accessor(self.focus))
    end
  end)
end

-- TODO: move to private config
function FzfCodeDiffInstanceTrait:setup_fileopen_keymaps()
  ---@param save_in_jumplist boolean
  ---@param open_command string
  local function open_file(save_in_jumplist, open_command)
    if not self.focus then return end

    local a_or_b = self._picker(self.focus)

    local filepath
    if a_or_b == "a" then
      if self._a_filepath_accessor then
        filepath = self._a_filepath_accessor(self.focus)
      else
        filepath = fzf_utils.write_to_temp_file(self._a_content_accessor(self.focus))
      end
    else
      if self._b_filepath_accessor then
        filepath = self._b_filepath_accessor(self.focus)
      else
        filepath = fzf_utils.write_to_temp_file(self._b_content_accessor(self.focus))
      end
    end

    self:hide()
    if save_in_jumplist then
      jumplist.save()
    end
    vim.cmd(([[%s %s]]):format(open_command, filepath))
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
function FzfCodeDiffInstanceTrait:setup_copy_filepath_keymap()
  self.layout.main_popup:map("<C-y>", "Copy filepath", function()
    if not self.focus then return end

    local a_or_b = self._picker(self.focus)
    local filepath
    if a_or_b == "a" then
      if not self._a_filepath_accessor then
        _warn("No filepath accessor for a")
        return
      end
      filepath = self._a_filepath_accessor(self.focus)
    else
      if not self._b_filepath_accessor then
        _warn("No filepath accessor for b")
        return
      end
      filepath = self._b_filepath_accessor(self.focus)
    end

    vim.fn.setreg("+", filepath)
    _info(([[Copied %s to clipboard]]):format(filepath))
  end)
end

return FzfCodeDiffInstanceTrait
