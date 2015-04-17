

-- dispatcher.lua: Callback handling mechanism


-- Namespace
local dispatcher = {}


-- Import
local util = require('dovahbot.util')

local table = table
local next = next
local pairs = pairs
local pcall = pcall
local unpack = unpack
local select = select
local setmetatable = setmetatable


-- Dispatcher API
local dis_api = {}
dis_api.__index = dis_api

function dis_api:register(event,func)
  util.argcheck(event,1,'string')
  util.argcheck(func,2,'function')
  
  if not self.events[event] then
    -- Registering event for first time
    self.events[event] = {}
    self.registration_queue[event] = {}
    self.dispatch_queue[event] = {}
  end
  local events = self.events[event]
  local registration_queue = self.registration_queue[event]
  
  if events[func] or registration_queue[func] then return end
  
  if #self.dispatch_queue[event] > 0 then
    -- We're not in the process of dispatching: insert directly
    events[func] = true
  else
    -- We're dispatching, queue it up to be inserted later
    registration_queue[func] = true
  end
end

function dis_api:unregister(event,func)
  util.argcheck(event,1,'string')
  util.argcheck(func,2,'function')
  
  local events = self.events[event]
  local registration_queue = self.registration_queue[event]
  
  if not events then return end  -- no callbacks listening
  
  events[func] = nil
  registration_queue[func] = nil
  
  if not next(events) and not next(registration_queue) then
    -- No more callbacks listening to this events; delete it
    self.events[event] = nil
    self.registration_queue[event] = nil
    self.dispatch_queue[event] = nil
  end
end

local nop = function() end

local function dispatch(self,event)
  local errorhandler = self.errorhandler or nop
  local succ,err
  local args = self.dispatch_queue[1]
  for func in pairs(self.events[event]) do
    succ,err = pcall(func,unpack(args,1,args.n))
    if not succ then
      pcall(errorhandler,err)
    end
  end
  -- Don't pop until the end; otherwise, dispatch queue looks empty on
  -- subsequent calls to :invoke().
  table.remove(self.dispatch_queue[event],1)
end

function dis_api:invoke(event,...)
  util.argcheck(event,1,'string')
  
  if not self.events[event] then return end  -- no callbacks registered
  
  local queue = self.dispatch_queue[event]
  queue[#queue+1] = { n = select('#',...), ... }
  
  if #queue > 1 then
    return  -- Wait until it unrolls to process new invocation
  end
  
  repeat
    dispatch(self,event)
  until #queue == 0
  
  -- Process all the callbacks waiting to be registered for this event
  local events = self.events[event]
  local registration_queue = self.registration_queue[event]
  for func in pairs(registration_queue) do
    events[func] = true
    registration_queue[func] = nil
  end
end

function dis_api:seterrorhandler(func)
  util.argcheck(func,1,'function')
  self.errorhandler = func
end

function dis_api:geterrorhandler()
  return self.errorhandler
end


-- Public API: grab new instance
function dispatcher.new()
  local new = {
    events = {},
    dispatch_queue = {},
    registration_queue = {},
  }
  setmetatable(new,dis_api)
  return new
end

setmetatable(dispatcher,{ __call = dispatcher.new })


return dispatcher
