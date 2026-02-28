local Event = {}
Event.__index = Event;

--- Create a new event
--- @param cancellable boolean Whether the event is cancellable
--- @param stopOnCancel boolean Whether to stop the event if a listener cancels
function Event.new(cancellable, stopOnCancel)
    local self = {};
    self.listeners = {};
    self.cancellable = cancellable or false;
    self.stopOnCancel = stopOnCancel or false;

    return setmetatable(self, Event);
end

--- Check if a listener exists
--- @param cb function
function Event:exists(cb)
    return self.listeners[cb] ~= nil;
end

--- Add a listener
--- @param cb function
function Event:listen(cb)
    assert(type(cb) == "function", "Listener must be a function...");
    if (self.listeners[cb] ~= nil) then return cb end
    self.listeners[cb] = cb;
    return cb;
end

--- Remove a listener
--- @param cb function
function Event:remove(cb)
    if (self.listeners[cb] == nil) then return false; end

    self.listeners[cb] = nil;
    return true;
end

--- Invoke the event 
function Event:invoke(...)
    if (self.cancellable) then
        local cancelled = false;
        for _, listener in pairs(self.listeners) do
            cancelled = cancelled or listener(...);
            if (cancelled and self.cancelListeners) then break end
        end
        return cancelled;
    else
        for _, listener in pairs(self.listeners) do
            listener(...);
        end
    end
end

return Event;