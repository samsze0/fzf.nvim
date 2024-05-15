local utils = require("utils")

local M = {}

-- Generate a preview window offset string for fzf
--
---@param offset integer | string
---@param opts? { fixed_header?: number, center?: boolean }
---@return string
M.preview_offset = function(offset, opts)
  opts = vim.tbl_extend("force", {
    fixed_header = 0,
    center = true,
  }, opts or {})

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

  return (("%s"):rep(size, utils.nbsp)):format(...)
end

-- Write content to a temporary file and return its path
--
---@param content string|string[]
---@return string
M.write_to_tmpfile = function(content)
  local tmp = vim.fn.tempname()
  vim.fn.writefile(
    type(content) == "string" and vim.split(content, "\n") or content,
    tmp
  )
  return tmp
end

return M
