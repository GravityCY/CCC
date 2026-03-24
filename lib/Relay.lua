local Sides = require("lib.Sides");
local Peripheral = require("lib.Peripheral");

local RelayLib = {};

---@class Relay : myCcTweaked.peripherals.RelayInstance
local Relay = {};
Relay.__name = "Relay";

---@param self Relay
---@param key string
---@return any
function Relay.__index(self, key)
    if (Relay[key] ~= nil) then return Relay[key]; end

    local og = self.data.relay[key];
    if (type(og) ~= "function") then return og; end
    
    if (rawget(self, key) == nil) then
        rawset(self, key, function(_, ...) return og(...); end);
    end

    return rawget(self, key);
end

function RelayLib.class()
    return Relay;
end

function RelayLib.instanceof(obj)
    return type(obj) == "table" and getmetatable(obj) == Relay;
end

---@return Relay
function RelayLib.wrap(obj)
    local periph = nil;
    if (obj == redstone) then periph = redstone;
    else periph = Peripheral.asPeripheral(obj); end
    assert(periph ~= nil, "periph is nil");

    ---@cast periph myCcTweaked.peripherals.Relay
    
    ---@class Relay
    local self = {
        data = {
            relay = periph;
        }
    };

    return setmetatable(self, Relay);
end

--- Set output state on all sides
---@param state boolean|integer
function Relay:setOutputAll(state)
    local changed = false;
    for _, side in ipairs(Sides.values()) do
        local direction = Sides.toPeripheralName(side);
        changed = changed or self:setOutput(direction, state);
    end
    return changed;
end

--- Set redstone output on 1 side
---@param dir? string
---@param state boolean|integer
---@return boolean changed did anything change?
function Relay:setOutput(dir, state)
    if (dir == nil) then
        return self:setOutputAll(state);
    end

    if (type(state) == "boolean") then
        if (self.data.relay.getOutput(dir) == state) then return false; end
        self.data.relay.setOutput(dir, state);
    else
        if (self.data.relay.getAnalogOutput(dir) == state) then return false; end
        self.data.relay.setAnalogOutput(dir, state);
    end

    return true;
end

--- Tick a side on and off 
--- @param dir? string
--- @param startState boolean|integer
--- @param endState boolean|integer
--- @param time number
function Relay:tick(dir, startState, endState, time)
    self:setOutput(dir, startState);
    sleep(time);
    self:setOutput(dir, endState);
end

---@alias RelayListener fun(side: integer, prev: integer, new: integer)

function Relay:getState()
    return {
        [Sides.FORWARD] = self.data.relay.getAnalogInput("front"),
        [Sides.RIGHT] = self.data.relay.getAnalogInput("right"),
        [Sides.BACK] = self.data.relay.getAnalogInput("back"),
        [Sides.LEFT] = self.data.relay.getAnalogInput("left"),
        [Sides.UP] = self.data.relay.getAnalogInput("top"),
        [Sides.DOWN] = self.data.relay.getAnalogInput("bottom")
    };
end

--- Wait for a redstone event and invoke listeners
function Relay:awaitAny()
    local prevState = self:getState();
    while true do
        os.pullEvent("redstone");
        local currentState = self:getState();
        for side, prevValue in pairs(prevState) do
            local newValue = currentState[side];
            if (newValue ~= prevValue) then
                return side, prevValue, newValue;
            end
        end
    end
end

--- Wait for a redstone event
function Relay:awaitAnyPoll(pollCooldown, timeout)
    pollCooldown = pollCooldown or 0.05;

    local start = os.clock();
    local prevState = self:getState();
    while ((os.clock() - start) < timeout) do
        sleep(pollCooldown);

        local currentState = self:getState();
        for side, prevValue in pairs(prevState) do
            local newValue = currentState[side];
            if (newValue ~= prevValue) then
                return side, prevValue, newValue;
            end
        end
    end
end

--- Wait for a redstone event on a specific side <br>
--- If `onlyIfLevel` is provided, only allow the event if the new level is the same as `onlyIfLevel`
--- @param side redstone.side
--- @param onlyIfLevel? integer 0-15
--- @return integer prevLevel, integer newLevel
function Relay:awaitSide(side, onlyIfLevel)
    local prev = self.data.relay.getAnalogInput(side);
    while true do
        os.pullEvent("redstone");
        local current = self.data.relay.getAnalogInput(side);
        local shouldAllow = onlyIfLevel == nil or onlyIfLevel == current;
        if (shouldAllow and current ~= prev) then return prev, current; end
        prev = current;
    end
end

--- Wait for a redstone event on a specific side <br>
--- If `onlyIfLevel` is provided, only allow the event if the new level is the same as `onlyIfLevel`
--- @param side redstone.side
--- @param timeout? number seconds
--- @param onlyIfLevel? integer 0-15
--- @return integer? prevLevel, integer? newLevel
function Relay:awaitSidePoll(side, pollingCooldown, timeout, onlyIfLevel)
    pollingCooldown = pollingCooldown or 0.05;
    timeout = timeout or math.huge;

    local start = os.clock();
    local prev = self.data.relay.getAnalogInput(side);
    while ((os.clock() - start) < timeout) do
        sleep(pollingCooldown);
        local current = self.data.relay.getAnalogInput(side);
        local shouldAllow = onlyIfLevel == nil or onlyIfLevel == current;
        if (shouldAllow and current ~= prev) then return prev, current; end
        prev = current;
    end
end

Relay.__construct = RelayLib.wrap;
return RelayLib;