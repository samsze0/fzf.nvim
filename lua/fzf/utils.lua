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

-- Join several string parts by the nbsp character
--
---@vararg string
---@return string
M.join_by_nbsp = function(...)
  local args = { ... }
  local size = #args

  return (("%s"):rep(size, terminal_utils.nbsp)):format(...)
end

-- Replace curly braces with square brackets
--
-- Curly brackets would cause render failure because fzf will try evaluating them
--
---@param str string
---@return string
M.replace_curly_braces = function(str)
  local v, _ = str:gsub("{", "["):gsub("}", "]")
  return v
end

return M
