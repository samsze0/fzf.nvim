local M = {}

-- Tweaked from:
-- folke/trouble.nvim
-- https://github.com/folke/trouble.nvim/blob/main/lua/trouble/util.lua
--
---@param win number
---@param buf number
---@return { line: number, character: number }
function M.make_lsp_position_param(win, buf)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  row = row - 1
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
  if not line then return { line = 0, character = 0 } end
  col = vim.str_utfindex(line, col)

  return { line = row, character = col }
end

---@param buf number
---@return { uri: string }
function M.make_lsp_text_document_param(buf)
  return { uri = vim.uri_from_bufnr(buf) }
end

---@param uri string
---@return string
function M.uri_to_path(uri)
  return vim.fn.fnamemodify(vim.uri_to_fname(uri), ":~:.")
end

return M
