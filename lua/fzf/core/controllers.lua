local uuid_utils = require("utils.uuid")
local tbl_utils = require("utils.table")
local opts_utils = require("utils.opts")
local terminal_utils = require("utils.terminal")
local CallbackMap = require("fzf.core.callback-map")
local IpcClient = require("fzf.core.ipc-client")
local config = require("fzf").config

-- TODO: generics on entry
-- TODO: generics on FzfController
-- TODO: keep most recent controller stack and destroy them when a new one is spawned

---@alias FzfControllerId string
---@alias FzfUIHooks { show: function, hide: function, focus: function, destroy: function }

---@alias FzfDisplayAccessor fun(entry: string): string
---@alias FzfInitialFocusAccessor fun(entry: string): boolean

-- TODO: move to config
local IPC_CLIENT_TYPE = IpcClient.CLIENT_TYPE.tcp

-- Generic classes still WIP
-- https://github.com/LuaLS/lua-language-server/issues/1861
--
---@class FzfController
---@field name string Name of the selector
---@field _id FzfControllerId The id of the controller
---@field _parent_id? FzfControllerId The id of the parent controller
---@field query string The current query
---@field focus? any The currently focused entry
---@field _ipc_client FzfIpcClient The ipc client
---@field _extra_args? TerminalShellOpts Extra arguments to pass to fzf
---@field _entries_getter? FzfEntriesGetter The function or the shell command to retrieve the entries
---@field _ui_hooks? FzfUIHooks UI hooks
---@field _entries? any[] Current entries
---@field _display_accessor FzfDisplayAccessor Function that retrieves the display string of an entry
---@field _initial_focus_accessor FzfInitialFocusAccessor Function that determines if an entry should be focused on initially
---@field _extra_env_vars? TerminalShellOpts Extra environment variables to pass to fzf
---@field _prev_win? number Previous window before opening fzf
---@field _fetching_entries boolean
---@field _fetching_entries_subscribers FzfCallbackMap Map of subscribers of `fetching_entries`
---@field _is_entries_stale boolean
---@field _is_entries_stale_subscribers FzfCallbackMap Map of subscribers of `is_entries_stale`
---@field _on_exited_subscribers FzfCallbackMap Map of subscribers of the exit event
---@field _on_aborted_subscribers FzfCallbackMap Mapping of subscribers of the abort event
---@field _on_reloaded_subscribers FzfCallbackMap Mapping of subscribers of the reload event
---@field _has_reloaded boolean Whether the entries have been reloaded at least once
---@field _timers table<string, uv_timer_t> Timers used by the controller internally
---@field _refetch_in_background_interval number The time interval of which the entries are fetched in the background
---@field _started boolean Whether the controller has started
---@field _exited boolean Whether the controller has exited
local Controller = {}
Controller.__index = Controller
Controller.__is_class = true

-- Map of controller ID to controller.
-- A singleton.
--
---@class FzfControllerMap
---@field [FzfControllerId] FzfController
local ControllerMap = {}

-- Check if controller exists
--
---@param controller_id FzfControllerId
---@return boolean
function ControllerMap.exists(controller_id)
  return ControllerMap[controller_id] ~= nil
end

---@alias FzfEntriesGetter
--- | fun(): any[]
--- | fun(): thread
--- | string

-- Create controller
--
---@alias FzfCreateControllerOpts { name: string, extra_args?: TerminalShellOpts, extra_env_vars?: TerminalShellOpts, refetch_in_background_interval?: number }
---@param opts FzfCreateControllerOpts
---@return FzfController
function ControllerMap.create(opts)
  if vim.fn.executable("fzf") == 0 then error("fzf is not installed") end

  local controller_id = uuid_utils.v4()
  local controller = {
    name = opts.name,
    _id = controller_id,
    _parent_id = nil,
    query = "",
    focus = nil,
    _ipc_client = IpcClient.new(IPC_CLIENT_TYPE),
    _extra_args = opts.extra_args,
    _entries_getter = nil,
    _entries = nil,
    _display_accessor = function(e) return e.display end,
    _initial_focus_accessor = function(e) return e.initial_focus end,
    _ui_hooks = nil,
    _extra_env_vars = opts.extra_env_vars,
    _fetching_entries = nil,
    _is_entries_stale = nil,
    _fetching_entries_subscribers = CallbackMap.new(),
    _is_entries_stale_subscribers = CallbackMap.new(),
    _on_exited_subscribers = CallbackMap.new(),
    _on_aborted_subscribers = CallbackMap.new(),
    _on_reloaded_subscribers = CallbackMap.new(),
    _has_reloaded = false,
    _timers = {},
    _refetch_in_background_interval = opts.refetch_in_background_interval,
    _prev_win = vim.api.nvim_get_current_win(),
    _started = false,
    _exited = false,
  }
  ControllerMap[controller_id] = controller

  return controller
end

-- Create new controller
--
---@param opts FzfCreateControllerOpts
---@return FzfController
function Controller.new(opts)
  local obj = ControllerMap.create(opts)
  setmetatable(obj, Controller)

  -- Log all controller IDs
  -- print(vim.inspect(utils.filter(ControllerMap, function(k, v)
  --   return type(k) == "string" and k:len() == 36
  -- end)))

  -- Make sure fzf is load up before sending reload action to it
  obj:subscribe("start", nil, function() obj:_init_entries_getter() end)

  obj:subscribe("focus", "{n}", function(payload)
    ---@cast payload string
    local index = payload:match("^(%d+)$")
    assert(tonumber(index) ~= nil)
    obj.focus = obj._entries[tonumber(index) + 1]
  end)
  obj:subscribe("change", "{q}", function(payload)
    local query = payload:match("^'(.*)'$")
    if not query then error("Invalid payload", payload) end
    obj.query = query
  end)

  return obj
end

-- Destroy controller
--
---@param controller_id FzfControllerId
function ControllerMap.destroy(controller_id)
  local controller = ControllerMap[controller_id]
  if not controller then error("Controller not found") end

  controller._ipc_client:destroy()
  -- TODO: impl new data structure timer map that auto stop() and close() the timer
  for _, timer in pairs(controller._timers) do
    timer:stop()
    timer:close()
  end

  controller._ui_hooks:destroy()

  ControllerMap[controller_id] = nil
end

-- Destroy controller
--
---@param self FzfController
function Controller:_destroy() ControllerMap.destroy(self._id) end

-- Set parent controller
--
---@param parent FzfController
function Controller:set_parent(parent) self._parent_id = parent._id end

-- Retrieve parent controller
--
---@return FzfController?
function Controller:parent() return ControllerMap[self._parent_id] end

-- Set entries-getter
--
---@param entries_getter FzfEntriesGetter
---@param opts? { display_accessor?: FzfDisplayAccessor, initial_focus_accessor?: FzfInitialFocusAccessor }
function Controller:set_entries_getter(entries_getter, opts)
  opts = opts_utils.extend({
    display_accessor = function(e) return e.display end,
    initial_focus_accessor = function(e) return e.initial_focus end,
  }, opts)

  self._entries_getter = entries_getter
  self._display_accessor = opts.display_accessor
  self._initial_focus_accessor = opts.initial_focus_accessor

  if self._started then self:_init_entries_getter() end
end

-- Retrieve root controller
--
---@return FzfController
function Controller:root()
  if not self._parent_id then return self end
  return self:parent():root()
end

-- Retrieve prev window (before opening fzf)
--
---@return number
function Controller:prev_win()
  local root = self:root()
  if not root._prev_win then error("Prev win missing") end
  return root._prev_win
end

-- Retrieve prev buffer (before opening fzf)
--
---@return number
function Controller:prev_buf()
  local win = self:prev_win()
  return vim.api.nvim_win_get_buf(win)
end

-- Retrieve the filepath of the file opened in prev buffer (before opening fzf)
--
---@return string
function Controller:prev_filepath()
  return vim.api.nvim_buf_get_name(self:prev_buf())
end

-- Retrieve prev tab (before opening fzf)
--
---@return number
function Controller:prev_tab()
  return vim.api.nvim_win_get_tabpage(self:prev_win())
end

-- Show the UI and focus on it
function Controller:show_and_focus()
  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.show()
  self._ui_hooks.focus()
end

-- Hide the UI
function Controller:hide()
  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.hide()
end

---@param hooks FzfUIHooks
function Controller:set_ui_hooks(hooks) self._ui_hooks = hooks end

-- Start the fzf process
function Controller:start()
  local args = {
    ["--sync"] = "",
    ["--listen"] = ("%s:%s"):format(
      self._ipc_client.fzf_host,
      self._ipc_client.fzf_port
    ),
    ["--ansi"] = "",
    ["--border"] = "none",
    ["--height"] = "100%",
    ["--padding"] = "0,1",
    ["--margin"] = "0",
    ["--bind"] = "'" .. self._ipc_client:bindings() .. "'",
    ["--delimiter"] = "'" .. terminal_utils.nbsp .. "'",
  }
  args =
    tbl_utils.tbl_extend({ mode = "error" }, args, config.default_extra_args)
  args = tbl_utils.tbl_extend({ mode = "error" }, args, self._extra_args)

  local command = "fzf " .. terminal_utils.shell_opts_tostring(args)

  -- TODO: cater Windows
  command = [[printf "" | ]] .. command

  local env_vars = {
    ["FZF_API_KEY"] = IpcClient.API_KEY,
    -- TODO: add warning about SHELL and how it can make the plugin sluggish/lag
  }
  env_vars = tbl_utils.tbl_extend(
    { mode = "error" },
    env_vars,
    config.default_extra_env_vars
  )
  env_vars =
    tbl_utils.tbl_extend({ mode = "error" }, env_vars, self._extra_env_vars)

  command = ("%s %s"):format(
    terminal_utils.shell_opts_tostring(env_vars),
    command
  )

  if self._parent_id then self:parent():hide() end
  self:show_and_focus()

  vim.fn.termopen(command, {
    on_exit = function(job_id, code, event)
      self._exited = true
      self._on_exited_subscribers:invoke_all()

      -- Hide first so that parent UI can be shown without issues
      self:hide()
      if self._parent_id then self:parent():show_and_focus() end

      if code == 0 then
      -- Pass
      elseif code == 1 then
        error("No match")
      elseif code == 2 then
        -- Check stdout if this error occurs
        error("Unexpected error")
      elseif code == 130 then -- abort
        self._on_aborted_subscribers:invoke_all()
      else
        error("Unexpected exit code: " .. code)
      end

      self:_destroy()
    end,
    on_stdout = function(job_id, ...)
      -- _info("fzf stdout", ...)
      -- print(vim.inspect({ ... }))
    end,
    on_stderr = function(job_id, ...)
      -- _info("fzf stderr", ...)
      -- error(vim.inspect({ ... }))
    end,
  })
  self._started = true
end

-- Initialize entries getter by forcing an entries reload and setting up a timer to reload entries in the background (if configured)
function Controller:_init_entries_getter()
  self:_fetch_entries_in_background({
    load_immediately = true,
    change_focus = true,
  })

  if self._refetch_in_background_interval ~= nil then
    self:on_is_entries_stale_change(function()
      if self:is_entries_stale() then return end -- Should only trigger when new entries are loaded

      -- Stop existing reload timer (if any)
      local reload_timer = self._timers["reload"]
      if reload_timer then
        reload_timer:stop()
        reload_timer:close()
      end

      local reload_timer = vim.loop.new_timer()
      local ok, err = reload_timer:start(
        0,
        self._refetch_in_background_interval,
        vim.schedule_wrap(function() self:_fetch_entries_in_background() end)
      )
      assert(ok, err)
      self._timers["reload"] = reload_timer
    end)
  end
end

-- Send an action to fzf to execute
--
---@param action string
---@param opts? { load_action_from_file?: boolean }
function Controller:execute(action, opts)
  return self._ipc_client:execute(action, opts)
end

-- Retrieve information from fzf
--
---@param response_payload? string
---@param callback FzfCallback
function Controller:ask(response_payload, callback)
  return self._ipc_client:ask(response_payload, callback)
end

-- Bind a fzf event to a fzf action
--
---@param event string
---@param action string
function Controller:bind(event, action) self._ipc_client:bind(event, action) end

-- Subscribe to fzf event
--
---@param event string
---@param response_payload? string
---@param callback FzfCallback
function Controller:subscribe(event, response_payload, callback)
  return self._ipc_client:subscribe(event, response_payload, callback)
end

-- Manually trigger a fzf event
--
---@param event string
function Controller:trigger_event(event) self._ipc_client:trigger_event(event) end

-- Abort controller
function Controller:abort() self:execute("abort") end

-- TODO: cleanup `refresh`, `_load_fetch_entries`, `_fetch_entries_in_background`

-- Fetch entries in the background to check if current entries are stale
--
---@param opts? { load_immediately?: boolean, change_focus?: boolean }
function Controller:_fetch_entries_in_background(opts)
  opts = opts or {}

  if not self._entries_getter then error("Entries getter not configured") end

  local old_entries = self._entries

  if type(self._entries_getter) == "function" then
    self:set_fetching_entries(true)
    local x = self._entries_getter()

    if type(x) == "thread" then
      if coroutine.status(x) ~= "suspended" then
        error("Invalid coroutine status")
      end

      -- Stop existing timer (if any)
      local get_entries_timer = self._timers["coroutine-get-entries"]
      if get_entries_timer then
        get_entries_timer:stop()
        get_entries_timer:close()
      end

      local timer = vim.loop.new_timer()
      timer:start(
        0,
        0,
        vim.schedule_wrap(function()
          while coroutine.status(x) ~= "dead" do
            if coroutine.status(x) ~= "suspended" then
              error("Unexpected coroutine status")
            end

            local ok, fzf_entry = coroutine.resume(x)
            assert(ok, debug.traceback(x))
            -- TODO: add fzf_entry to entries
          end
        end)
      )
      self._timers["coroutine-get-entries"] = timer
    elseif type(x) == "table" then
      self._entries = x
      self:set_fetching_entries(false)

      -- TODO: deep compare
      if vim.inspect(old_entries) ~= vim.inspect(self._entries) then
        self:set_is_entries_stale(true)
        if opts.load_immediately then
          self:_load_fetched_entries({ change_focus = opts.change_focus })
        end
      end
    else
      error("Invalid entries getter")
    end
  else
    error("Invalid entries getter")
  end
end

-- TODO: support shell command as entries getter

-- Refresh list of entries.
-- If there exists fetched entries and currently displayed entries are marked as stale, then simply load those entries.
-- Else, fetch entries in the background and load them immediately.
-- If the `force_refetch` option is set to true, then always fetch entries in the background.
--
---@alias FzfControllerRefreshOpts { change_focus?: boolean, refetch?: boolean }
---@param opts? FzfControllerRefreshOpts
function Controller:refresh(opts)
  opts = opts_utils.extend({
    refetch = true,
  }, opts)
  ---@cast opts FzfControllerRefreshOpts

  if self:is_entries_stale() and not opts.refetch then
    self:_load_fetched_entries({ change_focus = opts.change_focus })
  else
    -- TODO: add support for loading entries in the foreground (blocking)
    self:_fetch_entries_in_background({
      load_immediately = true,
      change_focus = opts.change_focus,
    })
  end
end

-- Load the background-fetched-entries into fzf
--
---@param opts? { change_focus?: boolean }
function Controller:_load_fetched_entries(opts)
  opts = opts or {}

  if not self:is_entries_stale() then
    _warn("Entries are up to date. Ignoring refresh request")
    return
  end

  local initial_pos
  local fzf_rows = tbl_utils.map(self._entries, function(i, e)
    local display = self._display_accessor(e)
    if type(display) ~= "string" then error("Invalid entry " .. e) end

    local initial_focus = self._initial_focus_accessor(e)
    if initial_focus then initial_pos = i end

    return display
  end)
  ---@cast fzf_rows string[]
  if #fzf_rows == 0 then
    self:execute("reload()")
  else
    local action = ("reload%s%s%s"):format(
      "$", -- TODO: Make this configurable
      ([[cat <<"EOF"
%s
EOF
]]):format(table.concat(fzf_rows, "\n")),
      "$"
    )
    self:execute(action, { load_action_from_file = true })
  end
  self:ask(nil, function()
    self:set_is_entries_stale(false)

    self._on_reloaded_subscribers:invoke_all(not self._has_reloaded)
    self._has_reloaded = true

    if opts.change_focus and initial_pos ~= nil then
      -- FIX: `pos` action only takes effect if we force it to wait for a while
      vim.fn.system("sleep 0.01")
      self:execute(([[pos(%d)]]):format(initial_pos))
    else
      self:trigger_event("focus")
    end
  end)
end

-- Retrieve selections
--
---@param callback fun(entries: any[])
function Controller:selections(callback)
  self:ask("{+n}", function(payload)
    local indices = tbl_utils.map(vim.split(payload, " "), function(_, i)
      local index = tonumber(i) + 1
      assert(index ~= nil)
      return index
    end)
    callback(tbl_utils.map(indices, function(_, i) return self._entries[i] end))
  end)
end

-- __newindex only triggers when the index doesn't exist in the table.
-- So using method seems to be the more straight forward approach

function Controller:is_entries_stale() return self._is_entries_stale end

function Controller:fetching_entries() return self._fetching_entries end

function Controller:started() return self._started end

function Controller:exited() return self._exited end

function Controller:set_is_entries_stale(v)
  if self._is_entries_stale == v then return end

  self._is_entries_stale = v
  self._is_entries_stale_subscribers:invoke_all()
end

function Controller:set_fetching_entries(v)
  if self._fetching_entries == v then return end

  self._fetching_entries = v
  self._fetching_entries_subscribers:invoke_all()
end

-- Subscribe to changes in the field `fetching_entries`
--
---@param callback fun()
---@return fun() Unsubscribe
function Controller:on_fetching_entries_change(callback)
  return self._fetching_entries_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to changes in the field `is_entries_stale`
--
---@param callback fun()
---@return fun() Unsubscribe
function Controller:on_is_entries_stale_change(callback)
  return self._is_entries_stale_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to the event "exited"
--
---@param callback fun()
---@return fun() Unsubscribe
function Controller:on_exited(callback)
  return self._on_exited_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to the event "aborted"
--
---@param callback fun()
---@return fun() Unsubscribe
function Controller:on_aborted(callback)
  return self._on_aborted_subscribers:add_and_return_remove_fn(callback)
end

-- Subscribe to the event "reloaded"
--
---@param callback fun(is_first: boolean)
---@return fun() Unsubscribe
function Controller:on_reloaded(callback)
  return self._on_reloaded_subscribers:add_and_return_remove_fn(callback)
end

-- Send current selections to loclist
--
---@alias FzfControllerSendSelectionsToLoclistOpts { filename_accessor?: (string | fun(entry: any): string), lnum_accessor?: (number | fun(entry: any): number), col_accessor?: (number | fun(entry: any): number), text_accessor?: (string | fun(entry: any): string), callback?: function }
---@param opts? FzfControllerSendSelectionsToLoclistOpts
function Controller:send_selections_to_loclist(opts)
  opts = opts_utils.extend({
    filename_accessor = function(e) return e.filename end,
    col_accessor = function(e) return e.col end,
    lnum_accessor = function(e) return e.lnum end,
    text_accessor = function(e) return e.text end,
  }, opts)
  ---@cast opts FzfControllerSendSelectionsToLoclistOpts

  -- TODO: having this extra callback opt is a bit cumbersome. Maybe impl something like async/await

  self:selections(function(entries)
    tbl_utils.map(entries, function(_, e)
      -- :h setqflist
      return {
        filename = type(opts.filename_accessor) == "string"
            and opts.filename_accessor
          or opts.filename_accessor(e),
        lnum = type(opts.lnum_accessor) == "number" and opts.lnum_accessor
          or opts.lnum_accessor(e),
        col = type(opts.col_accessor) == "number" and opts.col_accessor
          or opts.col_accessor(e),
        text = type(opts.text_accessor) == "string" and opts.text_accessor
          or opts.text_accessor(e),
      }
    end)

    -- TODO: send to loclist. Need to deal with circular dependencies. Probably need to dynamic import

    if opts.callback then opts.callback() end
  end)
end

ControllerMap.Controller = Controller

return ControllerMap
