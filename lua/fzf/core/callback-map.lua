local utils = require("utils")

---@alias FzfCallback function

---@class FzfCallbackMap
---@field private value table<string, FzfCallback> Callback map
local CallbackMap = {}
CallbackMap.__index = CallbackMap

---@param base? FzfCallbackMap
---@return FzfCallbackMap self
function CallbackMap.new(base)
  local obj = base or {}
  setmetatable(obj, CallbackMap)
  obj.value = {}
  return obj
end

-- Add callback to the map
--
---@param callback FzfCallback
---@return string key
function CallbackMap:add(callback)
  local key = self:empty_slot()
  self.value[key] = callback
  return key
end

-- Remove callback from the map
--
---@param key string
function CallbackMap:remove(key)
  if not self:exists(key) then error("Callback not found: " .. key) end
  self.value[key] = nil
end

-- Add callback and return a function to remove the callback from the map
--
---@param callback FzfCallback
---@return fun(): nil
function CallbackMap:add_and_return_remove_fn(callback)
  local key = self:add(callback)
  return function() self:remove(key) end
end

-- Get callback from the map
--
---@param key string
---@return FzfCallback
function CallbackMap:get(key)
  if not self:exists(key) then error("Callback not found: " .. key) end
  return self.value[key]
end

-- Find empty slot in the map and return the key
--
---@return string key
function CallbackMap:empty_slot()
  local key = utils.uuid()
  local retry_count = 3
  while self:exists(key) and retry_count >= 1 do
    retry_count = retry_count - 1
    key = utils.uuid()
  end
  if self:exists(key) then error("Failed to find empty slot") end
  return key
end

function CallbackMap:exists(key) return self.value[key] ~= nil end

-- Invoke callback
--
---@param key string
---@vararg any
function CallbackMap:invoke(key, ...)
  local cb = self:get(key)
  local args = { ... }
  vim.schedule(function() cb(unpack(args)) end)
end

-- Invoke callback if key exists, otherwise do nothing
--
---@param key string
---@vararg any
function CallbackMap:invoke_if_exists(key, ...)
  if not self:exists(key) then return end
  local args = { ... }
  self:invoke(key, unpack(args))
end

-- Invoke all callbacks
--
---@vararg any
function CallbackMap:invoke_all(...)
  local args = { ... }
  for _, cb in pairs(self.value) do
    vim.schedule(function() cb(unpack(args)) end)
  end
end

return CallbackMap
