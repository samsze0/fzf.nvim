local utils = require("utils")
local EventMap = require("fzf.core.event-map")
local uv_utils = require("utils.uv")
local json = require("utils.json")
local os_utils = require("utils.os")
local CallbackMap = require("fzf.core.callback-map")

---@enum FzfIpcClientType
local CLIENT_TYPE = {
  tcp = 1,
  named_pipe = 2,
  nvim_rpc = 3,
}

local FZF_API_KEY = utils.uuid()

local FZF_BASE_PORT = 8839

---@class FzfIpcClient
---@field client_type FzfIpcClientType
---@field host string The host of which the server that listens to incoming messages from fzf is running on
---@field port number The port of which the server that listens to incoming messages from fzf is running on
---@field fzf_host string
---@field fzf_port number
---@field _event_map FzfEventMap Map of events to fzf action(s). I.e. the list of Fzf bindings
---@field _callback_map FzfCallbackMap Map of keys to lua callbacks
---@field execute fun(self: FzfIpcClient, action: string, opts?: { load_action_from_file?: boolean }) Send an action to fzf to execute
---@field ask fun(self: FzfIpcClient, response_payload?: string, callback: function) Retrieve information from fzf
---@field subscribe fun(self: FzfIpcClient, event: string, response_payload?: string, callback?: function): (fun(): nil) Subscribe to a fzf event
---@field destroy fun(self: FzfIpcClient): nil Destroy the fzf client by freeing up any occupied resources
local FzfIpcClient = {
  CLIENT_TYPE = CLIENT_TYPE,
  API_KEY = FZF_API_KEY,
}
FzfIpcClient.__index = FzfIpcClient

---@param client_type FzfIpcClientType
function FzfIpcClient.new(client_type)
  local obj = setmetatable({
    client_type = client_type,
    host = "127.0.0.1",
    port = nil,
    fzf_host = "127.0.0.1",
    fzf_port = os_utils.next_available_port(FZF_BASE_PORT),
    _event_map = EventMap.new(),
    _callback_map = CallbackMap.new(),
  }, FzfIpcClient)

  local function message_handler(message)
    local json_obj = json.parse(message)
    if not json_obj then error("Invalid message") end

    if not json_obj.key then error("Key missing in message") end
    obj._callback_map:invoke_if_exists(json_obj.key, json_obj.message)
  end

  if client_type == CLIENT_TYPE.tcp then
    local tcp_server = uv_utils.create_tcp_server(obj.host, message_handler)

    -- TODO: support HTTP
    --   local command = (
    --     -- Adding space between quoted string breaks fzf
    --     [[cat <<EOF | curl -H 'Content-Type:application/json' -X POST --data-binary @- %s:%s
    -- %s
    -- EOF
    -- ]]):format(
    --     fzf_nvim_server.host,
    --     fzf_nvim_server.port,
    --     payload
    --   )

    obj.port = tcp_server.port

    ---@param action string
    ---@param opts? { load_action_from_file?: boolean }
    local to_fzf = function(action, opts)
      opts = opts or {}

      local fn = function()
        -- TODO: optimise this. Action is concatenated and then splited again
        if opts.load_action_from_file then
          local tmpfile = vim.fn.tempname()
          vim.fn.writefile(vim.split(action, "\n"), tmpfile)
          utils.system(
            ([[curl -X POST --data-binary '@%s' -H 'x-api-key: %s' %s:%s]]):format(
              tmpfile,
              FZF_API_KEY,
              obj.fzf_host,
              obj.fzf_port
            )
          )
          vim.fn.delete(tmpfile)
        else
          utils.system(
            ([[curl -X POST --data '%s' -H 'x-api-key: %s' %s:%s]]):format(
              action,
              FZF_API_KEY,
              obj.fzf_host,
              obj.fzf_port
            )
          )
        end
      end

      uv_utils.schedule_if_needed(fn)
    end

    obj.execute = function(self, action, opts) to_fzf(action, opts) end

    obj.ask = function(self, response_payload, callback)
      local key = self._callback_map:add(callback)

      local message = json.stringify({
        key = key,
        message = response_payload,
      })
      local command = os_utils.write_to_tcp_cmd(obj.host, obj.port, message)

      local action = ("execute-silent(%s)"):format(command)

      to_fzf(action)
    end

    obj.subscribe = function(self, event, response_payload, callback)
      local key = self._callback_map:add(callback)

      local message = json.stringify({
        key = key,
        message = response_payload,
        event = event,
      })

      local command = os_utils.write_to_tcp_cmd(obj.host, obj.port, message)

      local action = ("execute-silent(%s)"):format(command)

      self:bind(event, action)

      return function() self._callback_map:remove(key) end
    end

    obj.destroy = function(self) tcp_server.close() end
  elseif client_type == CLIENT_TYPE.nvim_rpc then
    error("Not implemented")
  elseif client_type == CLIENT_TYPE.named_pipe then
    error("Not implemented")

    -- local pipe_server = uv_utils.create_named_pipe_server(message_handler)

    -- local pipe_name = ("nvim.fzf-%s"):format(utils.uuid())
    -- utils.system("mkfifo " .. pipe_name)

    -- obj.receive_message_cmd = function(self, message)
    --   return os_utils.write_to_named_pipe_cmd(pipe.name, message)
    -- end
  else
    error("Invalid client type")
  end

  return obj
end

-- Return the fzf bindings string
--
---@return string
function FzfIpcClient:bindings() return tostring(self._event_map) end

-- Bind a fzf event to a fzf action
--
---@param event string
---@param action string
function FzfIpcClient:bind(event, action) self._event_map:append(event, action) end

-- Manually trigger a fzf event
--
---@param event string
function FzfIpcClient:trigger_event(event)
  local actions = self._event_map:get(event)

  for _, action in ipairs(actions) do
    self:execute(action)
  end
end

return FzfIpcClient
