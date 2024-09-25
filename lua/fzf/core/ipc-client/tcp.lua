local uuid_utils = require("utils.uuid")
local terminal_utils = require("utils.terminal")
local TUIEventMap = require("tui.event-map")
local uv_utils = require("utils.uv")
local os_utils = require("utils.os")
local TUICallbackMap = require("tui.callback-map")
local config = require("fzf.core.config").value
local oop_utils = require("utils.oop")
local IpcClient = require("fzf.core.ipc-client.base").IpcClient
local FZF_API_KEY = require("fzf.core.ipc-client.base").FZF_API_KEY

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

-- TODO: tcp server typing

---@class FzfTcpIpcClient : FzfIpcClient
---@field host string Host of the server that listens to incoming messages from fzf
---@field port number Port of the server that listens to incoming messages from fzf
---@field _tcp_server any
---@field _rows_tmp_file string Path to the temporary file that stores the rows for fzf to load
local TcpIpcClient = oop_utils.new_class(IpcClient)

function TcpIpcClient.new()
  local obj = setmetatable({
    host = "127.0.0.1",
    port = nil,
    fzf_host = "127.0.0.1",
    fzf_port = os_utils.find_available_port(),
    _event_map = TUIEventMap.new(),
    _callback_map = TUICallbackMap.new(),
    _rows_tmp_file = vim.fn.tempname(),
  }, TcpIpcClient)
  ---@cast obj FzfTcpIpcClient

  local tcp_server = uv_utils.create_tcp_server(obj.host, function(message)
    xpcall(
      function() obj:on_message(message) end,
      function(err) _error(debug.traceback("Error in on_message: " .. err)) end
    )
  end)
  obj.port = tcp_server.port
  obj._tcp_server = tcp_server

  return obj
end

---@param rows string[]
function TcpIpcClient:reload(rows)
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
function TcpIpcClient:execute(action, opts)
  opts = opts or {}

  local fn = function()
    local curl_output
    if opts.load_action_from_file then
      local tmpfile = vim.fn.tempname()
      vim.fn.writefile(vim.split(action, "\n"), tmpfile)
      curl_output = terminal_utils.system_unsafe(
        ([[curl --include --silent -X POST --data-binary '@%s' -H 'x-api-key: %s' %s:%s]]):format(
          tmpfile,
          FZF_API_KEY,
          self.fzf_host,
          self.fzf_port
        ),
        { trim_endline = true }
      )
      vim.fn.delete(tmpfile)
    else
      curl_output = terminal_utils.system_unsafe(
        ([[curl --include --silent -X POST --data '%s' -H 'x-api-key: %s' %s:%s]]):format(
          action,
          FZF_API_KEY,
          self.fzf_host,
          self.fzf_port
        ),
        { trim_endline = true }
      )
    end

    local status_code = curl_output:match("^HTTP/1%.1 (%d+)")
    if not status_code then
      error(
        "Failed to get status code from curl output: "
          .. vim.inspect(curl_output)
      )
    end

    if status_code ~= "200" then
      error("Failed to send message to fzf: " .. vim.inspect(curl_output))
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
  -- TCP server would shutdown itself once connection to fzf is lost
  -- self._tcp_server.close()

  vim.fn.delete(self._rows_tmp_file)
end

---@return ShellOpts
function TcpIpcClient:args()
  return {
    ["--listen"] = ("%s:%s"):format(self.fzf_host, self.fzf_port),
    ["--bind"] = "'" .. self:bindings() .. "'",
  }
end

---@return ShellOpts
function TcpIpcClient:env_vars()
  return {
    ["FZF_API_KEY"] = FZF_API_KEY,
  }
end

return TcpIpcClient