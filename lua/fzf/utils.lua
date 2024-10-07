local terminal_utils = require("utils.terminal")
local opts_utils = require("utils.opts")

local M = {}

-- Generate a preview window offset string for fzf
--
---@param offset integer | string
---@param opts? { fixed_header?: number, center?: boolean }
---@return string
M.preview_offset = function(offset, opts)
  opts = opts_utils.extend({
    fixed_header = 0,
    center = true,
  }, opts)

  return ([[~%s,+%s%s,+%s%s]]):format(
    tostring(opts.fixed_header),
    tostring(opts.fixed_header),
    opts.center and "/2" or "",
    tostring(offset),
    opts.center and "/2" or ""
  )
end

return M
