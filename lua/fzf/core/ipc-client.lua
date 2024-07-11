local uuid_utils = require("utils.uuid")
local terminal_utils = require("utils.terminal")
local EventMap = require("tui.event-map")
local uv_utils = require("utils.uv")
local os_utils = require("utils.os")
local CallbackMap = require("tui.callback-map")

---@enum FzfIpcClientType
local CLIENT_TYPE = {
  tcp = 1,
  websocket = 2
}

local FZF_API_KEY = uuid_utils.v4()

---@class FzfIpcClient
---@field fzf_host string
---@field fzf_port number
---@field _event_map TUIEventMap Map of events to fzf action(s)
---@field _callback_map TUICallbackMap Map of keys to lua callbacks
local IpcClient = {}
IpcClient.__index = IpcClient
IpcClient.__is_class = true

---@param action string
---@param opts? { load_action_from_file?: boolean }
function IpcClient:execute(action, opts)
  error("Not implemented")
end

---@param body? string
---@param callback function
function IpcClient:ask(body, callback)
  error("Not implemented")
end

---@param event string
---@param body? string
---@param callback function
function IpcClient:subscribe(event, body, callback)
  error("Not implemented")
end

function IpcClient:on_focus(payload)
  error("Not implemented")
end

function IpcClient:destroy()
  error("Not implemented")
end

---@param message string
function IpcClient:on_message(message)
  local json_obj = vim.json.decode(message)
  if not json_obj then error("Invalid message") end

  if not json_obj.key then error("Key missing in message") end
  self._callback_map:invoke_if_exists(json_obj.key, json_obj.message)
end

-- Return the fzf bindings
--
---@return string
function IpcClient:bindings() return tostring(self._event_map) end

-- Bind a fzf event to a fzf action
--
---@param event string
---@param action string
function IpcClient:bind(event, action) self._event_map:append(event, action) end

-- Manually trigger a fzf event
--
---@param event string
function IpcClient:trigger_event(event)
  local actions = self._event_map:get(event)

  for _, action in ipairs(actions) do
    self:execute(action)
  end
end

-- TODO: tcp server typing

---@class FzfTcpIpcClient : FzfIpcClient
---@field host string Host of the server that listens to incoming messages from fzf
---@field port number Port of the server that listens to incoming messages from fzf
---@field _tcp_server any
local TcpIpcClient = {}
TcpIpcClient.__index = TcpIpcClient
TcpIpcClient.__is_class = true
setmetatable(TcpIpcClient, { __index = IpcClient })

function TcpIpcClient.new()
  local obj = setmetatable({
    host = "127.0.0.1",
    port = nil,
    fzf_host = "127.0.0.1",
    -- TODO
    fzf_port = "8204",
    _event_map = EventMap.new(),
    _callback_map = CallbackMap.new(),
  }, TcpIpcClient)
  ---@cast obj FzfTcpIpcClient

  local tcp_server = uv_utils.create_tcp_server(obj.host, function(message)
    obj:on_message(message)
  end)
  obj.port = tcp_server.port
  obj._tcp_server = tcp_server

  return obj
end

---@param action string
---@param opts? { load_action_from_file?: boolean }
function TcpIpcClient:execute(action, opts)
  opts = opts or {}

  local fn = function()
    if opts.load_action_from_file then
      local tmpfile = vim.fn.tempname()
      vim.fn.writefile(vim.split(action, "\n"), tmpfile)
      terminal_utils.system_unsafe(
        ([[curl -X POST --data-binary '@%s' -H 'x-api-key: %s' %s:%s]]):format(
          tmpfile,
          FZF_API_KEY,
          self.fzf_host,
          self.fzf_port
        )
      )
      vim.fn.delete(tmpfile)
    else
      terminal_utils.system_unsafe(
        ([[curl -X POST --data '%s' -H 'x-api-key: %s' %s:%s]]):format(
          action,
          FZF_API_KEY,
          self.fzf_host,
          self.fzf_port
        )
      )
    end
  end

  uv_utils.schedule_if_needed(fn)
end

---@param body? string
---@param callback function
function TcpIpcClient:ask(body, callback)
  local key = self._callback_map:add(callback)

  local message = vim.json.encode({
    key = key,
    message = body,
  })
  local command = os_utils.write_to_tcp_cmd(self.host, self.port, message)

  local action = ("execute-silent(%s)"):format(command)
  self:execute(action)
end

---@param event string
---@param body? string
---@param callback function
function TcpIpcClient:subscribe(event, body, callback)
  local key = self._callback_map:add(callback)

  local message = vim.json.encode({
    key = key,
    message = body,
    event = event,
  })

  local command = os_utils.write_to_tcp_cmd(self.host, self.port, message)

  local action = ("execute-silent(%s)"):format(command)

  self:bind(event, action)
end

function TcpIpcClient:destroy()
  self._tcp_server:close()
end

---@return ShellOpts
function TcpIpcClient:args()
  return {
    ["--listen"] = ("%s:%s"):format(
      self.fzf_host,
      self.fzf_port
    ),
    ["--bind"] = "'" .. self:bindings() .. "'",
  }
end

---@return ShellOpts
function TcpIpcClient:env_vars()
  return {
    ["FZF_API_KEY"] = FZF_API_KEY,
  }
end

return {
  AbstractIpcClient = IpcClient,
  TcpIpcClient = TcpIpcClient,
}
