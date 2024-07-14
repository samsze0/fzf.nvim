local FzfController = require("fzf.core.controller")
local config = require("fzf.core.config").value
local opts_utils = require("utils.opts")
local jumplist = require("jumplist")
local vimdiff_utils = require("utils.vimdiff")
local file_utils = require("utils.files")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@class FzfCodeDiffInstanceTrait : FzfController
---@field layout TUITriplePaneLayout
---@field _a_accessor fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field _b_accessor fun(entry: FzfEntry): { filepath?: string, lines?: string[], filetype?: string }
---@field _picker fun(entry: FzfEntry): ("a" | "b")
local FzfCodeDiffInstanceTrait = {}
FzfCodeDiffInstanceTrait.__index = FzfCodeDiffInstanceTrait
FzfCodeDiffInstanceTrait.__is_class = true
setmetatable(FzfCodeDiffInstanceTrait, { __index = FzfController })

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

    local function show(x, popup)
      if x.filepath then
        popup:show_file_content(x.filepath)
      elseif x.lines then
        popup:set_lines(x.lines, {
          filetype = x.filetype,
        })
      end
    end

    local a = self._a_accessor(self.focus)
    show(a, self.layout.side_popups.left)

    local b = self._b_accessor(self.focus)
    show(b, self.layout.side_popups.right)

    vimdiff_utils.diff_bufs(
      self.layout.side_popups.left.bufnr,
      self.layout.side_popups.right.bufnr
    )
  end)
end

-- TODO: move to private config
function FzfCodeDiffInstanceTrait:setup_fileopen_keymaps()
  ---@param save_in_jumplist boolean
  ---@param open_command string
  local function open_file(save_in_jumplist, open_command)
    if not self.focus then return end

    local a_or_b = self._picker(self.focus)

    local function get_path(x)
      if x.filepath then
        return x.filepath
      else
        return file_utils.write_to_tmpfile(x.lines)
      end
    end

    local filepath
    local filetype
    if a_or_b == "a" then
      local a = self._a_accessor(self.focus)
      filepath = get_path(a)
      filetype = a.filetype
    else
      local b = self._b_accessor(self.focus)
      filepath = get_path(b)
      filetype = b.filetype
    end

    self:hide()
    if save_in_jumplist then jumplist.save() end
    vim.cmd(([[%s %s]]):format(open_command, filepath))

    if filetype then vim.bo.filetype = filetype end
  end

  self.layout.main_popup:map(
    "<C-w>",
    "Open in new window",
    function() open_file(false, "vsplit") end
  )

  self.layout.main_popup:map(
    "<C-t>",
    "Open in new tab",
    function() open_file(false, "tabnew") end
  )

  self.layout.main_popup:map(
    "<CR>",
    "Open",
    function() open_file(true, "edit") end
  )
end

-- TODO: move to private config
function FzfCodeDiffInstanceTrait:setup_copy_filepath_keymap()
  self.layout.main_popup:map("<C-y>", "Copy filepath", function()
    if not self.focus then return end

    local a_or_b = self._picker(self.focus)
    local filepath
    if a_or_b == "a" then
      local a = self._a_accessor(self.focus)
      if not a.filepath then
        _warn("No filepath accessor for a")
        return
      end
      filepath = a.filepath
    else
      local b = self._b_accessor(self.focus)
      if not b.filepath then
        _warn("No filepath accessor for b")
        return
      end
      filepath = b.filepath
    end

    vim.fn.setreg("+", filepath)
    _info(([[Copied %s to clipboard]]):format(filepath))
  end)
end

return FzfCodeDiffInstanceTrait
