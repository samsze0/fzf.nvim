local utils = require("utils")

---@alias FzfAction string

---@class FzfEventMap
---@field private value table<string, FzfAction[]>
local EventMap = {}
EventMap.__index = EventMap

---@param base? FzfEventMap
---@return FzfEventMap self
function EventMap.new(base)
  local obj = base or {}
  setmetatable(obj, EventMap)
  obj.value = {}
  return obj
end

-- Add binds to the map
--
---@param binds table<string, FzfAction | FzfAction[]>
---@return FzfEventMap self
function EventMap:extend(binds)
  for k, v in pairs(binds) do
    if type(v) == "table" then
      EventMap:append(k, unpack(v))
    else
      EventMap:append(k, v)
    end
  end

  return self
end

-- Add bind(s) to the map
--
---@param event string
---@param binds FzfAction[]
---@param opts { prepend: boolean }
---@return FzfEventMap self
function EventMap:_add(event, binds, opts)
  utils.switch_with_func(type(self.value[event]), {
    ["nil"] = function() self.value[event] = binds end,
    ["table"] = function()
      if opts.prepend then
        self.value[event] = utils.list_extend(binds, self.value[event])
      else
        self.value[event] = utils.list_extend(self.value[event], binds)
      end
    end,
  }, function() error("Invalid value") end)
  return self
end

-- Append bind(s) to the map
--
---@param event string
---@vararg FzfAction
---@return FzfEventMap self
function EventMap:append(event, ...)
  local binds = { ... }
  return self:_add(event, binds, { prepend = false })
end

-- Prepend bind(s) to the map
--
---@param event string
---@vararg FzfAction
---@return FzfEventMap self
function EventMap:prepend(event, ...)
  local binds = { ... }
  return self:_add(event, binds, { prepend = true })
end

-- Get bind(s) from the map by event name
--
---@param event string
---@return FzfAction[]
function EventMap:get(event)
  local actions = self.value[event]
  if not actions then return {} end
  return actions
end

function EventMap:__tostring()
  return table.concat(
    utils.map(
      self.value,
      function(ev, actions)
        return ("%s:%s"):format(ev, table.concat(actions, "+"))
      end
    ),
    ","
  )
end

return EventMap
