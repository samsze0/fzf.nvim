local uuid_utils = require("utils.uuid")
local config = require("fzf.core.config").value
local oop_utils = require("utils.oop")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@enum FzfIpcClientType
local CLIENT_TYPE = {
  tcp = 1,
  websocket = 2,
}

local FZF_API_KEY = uuid_utils.v4()

---@class FzfIpcClient
---@field fzf_host string
---@field fzf_port number
---@field _event_map TUIEventMap Map of events to fzf action(s)
---@field _callback_map TUICallbackMap Map of keys to lua callbacks
local IpcClient = oop_utils.new_class()

---@param action string
---@param opts? { load_action_from_file?: boolean }
function IpcClient:execute(action, opts) error("Not implemented") end

---@param body? string
---@param callback function
function IpcClient:ask(body, callback) error("Not implemented") end

---@param event string
---@param body? string
---@param callback function
function IpcClient:subscribe(event, body, callback) error("Not implemented") end

function IpcClient:on_focus(payload) error("Not implemented") end

---@param rows string[]
function IpcClient:reload(rows) error("Not implemented") end

function IpcClient:destroy() error("Not implemented") end

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

---@return ShellOpts
function IpcClient:args() error("Not implemented") end

---@return ShellOpts
function IpcClient:env_vars() error("Not implemented") end

return {
  IpcClient = IpcClient,
  FZF_API_KEY = FZF_API_KEY,
  IPC_CLIENT_TYPE = CLIENT_TYPE,
}