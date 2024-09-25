local uuid_utils = require("utils.uuid")
local terminal_utils = require("utils.terminal")
local TUIEventMap = require("tui.event-map")
local uv_utils = require("utils.uv")
local os_utils = require("utils.os")
local TUICallbackMap = require("tui.callback-map")
local config = require("fzf.core.config").value
local oop_utils = require("utils.oop")
local WebsocketClient = require("websocket.client").WebsocketClient
local IpcClient = require("fzf.core.ipc-client.base").IpcClient
local FZF_API_KEY = require("fzf.core.ipc-client.base").FZF_API_KEY

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

-- TODO: tcp server typing

---@class FzfWebsocketIpcClient : FzfIpcClient
---@field _websocket_client WebsocketClient
---@field _rows_tmp_file string Path to the temporary file that stores the rows for fzf to load
local WebsocketIpcClient = oop_utils.new_class(IpcClient)

function WebsocketIpcClient.new()
  local obj = setmetatable({
    fzf_host = "127.0.0.1",
    fzf_port = os_utils.find_available_port(),
    _event_map = TUIEventMap.new(),
    _callback_map = TUICallbackMap.new(),
    _rows_tmp_file = vim.fn.tempname(),
  }, WebsocketIpcClient)
  ---@cast obj FzfWebsocketIpcClient

  local websocket_client = WebsocketClient.new({
    connect_addr = ("%s:%s"):format(obj.fzf_host, obj.fzf_port),
    on_message = function(client, message)
      xpcall(
        function() obj:on_message(message) end,
        function(err) _error(debug.traceback("Error in on_message: " .. err)) end
      )
    end,
    on_error = function(client, err) _error("Websocket error: " .. err) end,
  })
  obj._websocket_client = websocket_client
  return obj
end

---@param rows string[]
function WebsocketIpcClient:reload(rows)
  if #rows == 0 then
    self:execute("reload()")
  else
    vim.fn.writefile(rows, self._rows_tmp_file)
    self:execute(
      "reload(cat " .. vim.fn.shellescape(self._rows_tmp_file) .. ")"
    )
  end
end

---@param action string
---@param opts? { load_action_from_file?: boolean }
function WebsocketIpcClient:execute(action, opts)
  opts = opts or {}

  local fn = function()
    if opts.load_action_from_file then
      local tmpfile = vim.fn.tempname()
      vim.fn.writefile(vim.split(action, "\n"), tmpfile)
      self._websocket_client:try_send_data(("@%s"):format(tmpfile))
      vim.fn.delete(tmpfile)
    else
      self._websocket_client:try_send_data(action)
    end

    -- TODO: check if request is successful
    -- TODO: block until data is sent over websocket
  end

  uv_utils.schedule_if_needed(fn)
end

---@param body? string
---@param callback function
function WebsocketIpcClient:ask(body, callback)
  local key = self._callback_map:add(callback)

  local message = vim.json.encode({
    key = key,
    message = body,
  })
  local action = ("websocket-broadcast(%s)"):format(message)
  self:execute(action)
end

---@param event string
---@param body? string
---@param callback function
function WebsocketIpcClient:subscribe(event, body, callback)
  local key = self._callback_map:add(callback)

  local message = vim.json.encode({
    key = key,
    message = body,
    event = event,
  })
  local action = ("websocket-broadcast(%s)"):format(message)
  self:bind(event, action)
end

function WebsocketIpcClient:destroy()
  -- Websocket client would shutdown itself once connection to fzf is lost

  vim.fn.delete(self._rows_tmp_file)
end

---@return ShellOpts
function WebsocketIpcClient:args()
  return {
    ["--websocket-listen"] = ("%s:%s"):format(self.fzf_host, self.fzf_port),
    ["--bind"] = "'" .. self:bindings() .. "'",
  }
end

---@return ShellOpts
function WebsocketIpcClient:env_vars()
  return {
    ["FZF_API_KEY"] = FZF_API_KEY,
  }
end

return WebsocketIpcClient
