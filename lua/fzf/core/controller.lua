local uuid_utils = require("utils.uuid")
local lang_utils = require("utils.lang")
local match = lang_utils.match
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local TUICallbackMap = require("tui.callback-map")
local TcpIpcClient = require("fzf.core.ipc-client").TcpIpcClient
local WebsocketIpcClient = require("fzf.core.ipc-client").WebsocketIpcClient
local fzf_utils = require("fzf.utils")
local config = require("fzf.core.config").value
local TUIController = require("tui.controller")
local TUIControllerMap = require("tui.controller-map")
local uv_utils = require("utils.uv")
local oop_utils = require("utils.oop")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

-- TODO: keep most recent controller stack and destroy them when a new one is spawned

---@alias FzfEntry any
---@alias FzfDisplayAccessor fun(entry: FzfEntry): string | string[]
---@alias FzfInitialFocusAccessor fun(entry: FzfEntry): boolean
---@alias FzfEntriesGetter
--- | fun(): FzfEntry[]

-- Generic classes still WIP
-- https://github.com/LuaLS/lua-language-server/issues/1861
--
---@class FzfController : TUIController
---@field name string Name of the selector
---@field _parent_id? TUIControllerId The id of the parent controller
---@field fzf_ready boolean
---@field query string The current query
---@field focus? FzfEntry The currently focused entry
---@field _ipc_client FzfIpcClient The ipc client
---@field _entries_getter FzfEntriesGetter The function or the shell command to retrieve the entries
---@field _entries? FzfEntry[] Current entries
---@field _display_accessor FzfDisplayAccessor Function that retrieves the display string of an entry
---@field _initial_focus_accessor FzfInitialFocusAccessor Function that determines if an entry should be focused on initially
---@field _fetching_entries boolean
---@field _fetching_entries_subscribers TUICallbackMap Map of subscribers of `fetching_entries`
---@field _is_entries_stale boolean
---@field _is_entries_stale_subscribers TUICallbackMap Map of subscribers of `is_entries_stale`
---@field _on_aborted_subscribers TUICallbackMap Mapping of subscribers of the abort event
---@field _on_reloaded_subscribers TUICallbackMap Mapping of subscribers of the reload event
local FzfController = oop_utils.new_class(TUIController)

-- Map of controller ID to controller.
-- A singleton.
local fzf_controller_map = TUIControllerMap.new()

---@class FzfCreateControllerOptions: TUICreateControllerOptions
---@field name string
---@field parent? FzfController
---@field entries_getter FzfEntriesGetter
---@field display_accessor? FzfDisplayAccessor
---@field initial_focus_accessor? FzfInitialFocusAccessor

-- Create new controller
--
---@param opts FzfCreateControllerOptions
---@return FzfController
function FzfController.new(opts)
  opts = opts_utils.extend({
    config = require("fzf.core.config"),
    index = fzf_controller_map,

    display_accessor = function(e) return e.display end,
    initial_focus_accessor = function(e) return e.initial_focus end,
  }, opts)
  ---@cast opts FzfCreateControllerOptions

  if not vim.fn.executable("fzf") == 1 then error("fzf is not installed") end

  local obj = TUIController.new(opts)
  ---@cast obj FzfController

  obj.name = opts.name
  obj.query = ""
  obj.fzf_ready = false
  obj._ipc_client = match(config.ipc_client_type, {
    [1] = function() return TcpIpcClient.new() end,
    [2] = function() return WebsocketIpcClient.new() end,
  })()
  obj._display_accessor = function(e) return e.display end
  obj._initial_focus_accessor = function(e) return e.initial_focus end
  obj._fetching_entries_subscribers = TUICallbackMap.new()
  obj._is_entries_stale_subscribers = TUICallbackMap.new()
  obj._on_aborted_subscribers = TUICallbackMap.new()
  obj._on_reloaded_subscribers = TUICallbackMap.new()
  obj._entries_getter = opts.entries_getter
  obj._display_accessor = opts.display_accessor
  obj._initial_focus_accessor = opts.initial_focus_accessor

  if opts.parent then obj._parent_id = opts.parent._id end

  setmetatable(obj, FzfController)

  -- Make sure fzf is load up before sending reload action to it
  obj:on_start(function(payload)
    obj.fzf_ready = true

    obj:set_fetching_entries(true)

    if not obj._entries_getter then return end

    obj:_fetch_entries()
    obj:_load_fetched_entries({ change_focus = true })
  end)

  obj:on_focus(function(payload) obj.focus = payload.entry end)

  obj:on_change(function(payload) obj.query = payload.query end)

  return obj
end

-- Destroy controller
--
function FzfController:_destroy()
  TUIController._destroy(self)

  self._ipc_client:destroy()
end

-- Retrieve parent controller
--
---@return FzfController?
function FzfController:parent()
  if self._parent_id then
    return fzf_controller_map:get(self._parent_id) ---@diagnostic disable-line: return-type-mismatch
  end
end

-- Retrieve root controller
--
---@return FzfController
function FzfController:root()
  if not self._parent_id then return self end
  return self:parent():root()
end

-- Start the fzf process
function FzfController:start()
  local args = self:_args_extend({
    ["--sync"] = "",
    ["--ansi"] = "",
    ["--border"] = "none",
    ["--height"] = "100%",
    ["--padding"] = "0,1",
    ["--margin"] = "0",
    ["--delimiter"] = "'" .. terminal_utils.nbsp .. "'",
  })
  args = opts_utils.extend(args, self._ipc_client:args())

  local env_vars = self:_env_vars_extend({})
  env_vars = opts_utils.extend(env_vars, self._ipc_client:env_vars())

  -- TODO: cater Windows
  -- Start fzf without any entries
  local command = terminal_utils.shell_opts_tostring(env_vars)
    .. ([[ printf "" | %s ]]):format(config.fzf_bin or "fzf")
    .. terminal_utils.shell_opts_tostring(args)

  if self._parent_id then self:parent():hide() end

  self:on_exited(function()
    -- Hide first to make sure parent UI can be shown without issues
    self:hide()
    if self._parent_id then self:parent():show_and_focus() end
  end)

  -- Remove previously stack if a new stack is spawned
  if self._parent_id == nil then
    -- _info("Clearing selectors : " .. vim.inspect(tbl_utils.map(fzf_controller_map:all(), function(_, c)
    --   ---@cast c FzfController
    --   return c.name
    -- end)))
    for _, c in ipairs(fzf_controller_map:all()) do
      ---@cast c FzfController
      c:_destroy()
    end
  end

  self:_start({
    command = command,
    exit_code_handler = function(code)
      if code == 0 then
        -- Match
      elseif code == 1 then
        -- No match
      elseif code == 2 then
        -- Check stdout if this error occurs
        local stdout = vim.fn.system(command)
        -- TODO: Capture stdout without having to re-run the command
        error("Unexpected error: " .. stdout)
      elseif code == 130 then -- abort
        self._on_aborted_subscribers:invoke_all()
      else
        error("Unexpected exit code: " .. code)
      end
    end,
  })
end

---@return integer
function FzfController:prev_win() return self:root()._prev_win end

-- Make sure function is run when fzf is ready
--
---@param fn function
function FzfController:run_when_ready(fn)
  if self.fzf_ready then
    fn()
  else
    self:on_start(fn)
  end
end

-- Send an action to fzf to execute
--
---@param action string
---@param opts? { load_action_from_file?: boolean }
function FzfController:execute(action, opts)
  return self:run_when_ready(
    function() self._ipc_client:execute(action, opts) end
  )
end

function FzfController:ask(body, callback)
  return self:run_when_ready(
    function() self._ipc_client:ask(body, callback) end
  )
end

function FzfController:subscribe(event, body, callback)
  return self._ipc_client:subscribe(event, body, callback)
end

---@param entries_getter FzfEntriesGetter
function FzfController:set_entries_getter(entries_getter)
  self._entries_getter = entries_getter

  if self:started() then
    self:refresh({
      refetch = true,
      change_focus = true,
    })
  end
end

-- Bind a fzf event to a fzf action
--
---@param event string
---@param action string
function FzfController:bind(event, action)
  self:run_when_ready(
    function() return self._ipc_client:bind(event, action) end
  )
end

-- Manually trigger a fzf event
--
---@param event string
function FzfController:trigger_event(event)
  self:run_when_ready(function() self._ipc_client:trigger_event(event) end)
end

-- Abort controller
function FzfController:abort()
  self:run_when_ready(function() self:execute("abort") end)
end

-- Set pos
--
---@param index number
function FzfController:pos(index)
  self:run_when_ready(function() self:execute(("pos(%d)"):format(index)) end)
end

-- Reload
--
---@param rows string[]
function FzfController:reload(rows)
  self:run_when_ready(function() self._ipc_client:reload(rows) end)
end

-- Fetch entries and check if they are stale
function FzfController:_fetch_entries(opts)
  opts = opts or {}

  local old_entries = self._entries

  self:set_fetching_entries(true)
  self._entries = self._entries_getter()
  self:set_fetching_entries(false)

  if not vim.deep_equal(old_entries, self._entries) then
    self:set_is_entries_stale(true)
  end
end

-- Refresh list of entries.
-- If there exists fetched entries and currently displayed entries are marked as stale, then simply load those entries.
-- Else, fetch entries and load them immediately.
-- If the `force_fetch` option is set to true, then always go fetch entries
--
---@alias FzfControllerRefreshOpts { force_fetch?: boolean, change_focus?: boolean }
---@param opts? FzfControllerRefreshOpts
function FzfController:refresh(opts)
  opts = opts_utils.extend({
    refetch = true,
  }, opts)
  ---@cast opts FzfControllerRefreshOpts

  self:run_when_ready(function()
    if not self._entries_getter then error("No entries getter") end

    if self:is_entries_stale() and not opts.force_fetch then
      self:_load_fetched_entries({ change_focus = opts.change_focus })
    else
      self:_fetch_entries()
      self:_load_fetched_entries({ change_focus = opts.change_focus })
    end
  end)
end

-- Load the background-fetched-entries into fzf
--
---@param opts? { change_focus?: boolean }
function FzfController:_load_fetched_entries(opts)
  opts = opts or {}

  if not self:is_entries_stale() then
    _info("No changes")
    return
  end

  ---@type number?
  local initial_pos
  local rows = tbl_utils.map(self._entries, function(i, e)
    local display = self._display_accessor(e)
    if type(display) == "table" then
      display = terminal_utils.join_by_nbsp(unpack(display))
    elseif type(display) == "string" then
      display = display
    else
      error("Invalid display", display)
    end

    local initial_focus = self._initial_focus_accessor(e)
    if initial_focus then initial_pos = i end

    return display
  end)
  ---@cast rows string[]

  self:reload(rows)

  self:set_is_entries_stale(false)

  self._on_reloaded_subscribers:invoke_all()

  if initial_pos ~= nil and opts.change_focus then
    self:pos(initial_pos)
  else
    self:trigger_event("focus")
  end
end

-- Retrieve current selections
--
---@param callback fun(entries: FzfEntry[])
function FzfController:selections(callback)
  self:run_when_ready(function()
    self._ipc_client:ask("{+n}", function(payload)
      local indices = tbl_utils.map(vim.split(payload, " "), function(_, i)
        local index = tonumber(i) + 1
        if index == nil then error("Invalid payload", payload) end
        return index
      end)
      callback(
        tbl_utils.map(indices, function(_, i) return self._entries[i] end)
      )
    end)
  end)
end

function FzfController:is_entries_stale() return self._is_entries_stale end

function FzfController:fetching_entries() return self._fetching_entries end

function FzfController:set_is_entries_stale(v)
  if self._is_entries_stale == v then return end

  self._is_entries_stale = v
  self._is_entries_stale_subscribers:invoke_all()
end

function FzfController:set_fetching_entries(v)
  if self._fetching_entries == v then return end

  self._fetching_entries = v
  self._fetching_entries_subscribers:invoke_all()
end

-- Subscribe to changes in the field `fetching_entries`
--
---@param callback fun()
---@return fun() Unsubscribe
function FzfController:on_fetching_entries_change(callback)
  return self._fetching_entries_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to changes in the field `is_entries_stale`
--
---@param callback fun()
---@return fun() Unsubscribe
function FzfController:on_is_entries_stale_change(callback)
  return self._is_entries_stale_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to the event "exited"
--
---@param callback fun()
---@return fun() Unsubscribe
function FzfController:on_exited(callback)
  return self._on_exited_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to the event "aborted"
--
---@param callback fun()
---@return fun() Unsubscribe
function FzfController:on_aborted(callback)
  return self._on_aborted_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to the event "reloaded"
--
---@param callback fun(is_first: boolean)
---@return fun() Unsubscribe
function FzfController:on_reloaded(callback)
  return self._on_reloaded_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to the event "start"
--
---@alias FzfControllerOnStartCallbackPayload {}
---@param callback fun(payload: FzfControllerOnStartCallbackPayload)
function FzfController:on_start(callback)
  self:subscribe("start", nil, function(payload) callback({}) end)
end

-- Subscribe to the event "focus"
--
---@alias FzfControllerOnFocusCallbackPayload { index: number, entry: FzfEntry }
---@param callback fun(payload: FzfControllerOnFocusCallbackPayload)
---@param opts? { debounce_ms?: number }
function FzfController:on_focus(callback, opts)
  opts = opts_utils.extend({
    debounce_ms = config.focus_event_default_debounce_ms,
  }, opts)

  local debounced_callback =
    uv_utils.debounce(callback, opts.debounce_ms, { run_in_main_loop = true })

  self:subscribe("focus", "{n}", function(payload)
    local index = tonumber(payload)
    if index == nil then error("Invalid payload", payload) end
    debounced_callback({ index = index, entry = self._entries[index + 1] })
  end)
end

-- Subscribe to the event "change"
--
---@alias FzfControllerOnChangeCallbackPayload { query: string }
---@param callback fun(payload: FzfControllerOnChangeCallbackPayload)
---@param opts? { debounce_ms?: number }
function FzfController:on_change(callback, opts)
  opts = opts_utils.extend({
    debounce_ms = config.change_event_default_debounce_ms,
  }, opts)

  local debounced_callback =
    uv_utils.debounce(callback, opts.debounce_ms, { run_in_main_loop = true })

  self:subscribe("change", "{q}", function(payload)
    local query = payload:match("^'(.*)'$")
    if not query then error("Invalid payload", payload) end
    debounced_callback({ query = query })
  end)
end

return FzfController
