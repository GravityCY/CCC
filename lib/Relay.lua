local Sides = require("lib.Sides");
local Peripheral = require("lib.Peripheral");

local RelayLib = {};

---@class Relay : myCcTweaked.peripherals.RelayInstance
local RelayInstance = {};
RelayInstance.__name = "Relay";

---@param self Relay
---@param key string
---@return any
function RelayInstance.__index(self, key)
    if (RelayInstance[key] ~= nil) then return RelayInstance[key]; end

    local og = self.data.relay[key];
    if (type(og) ~= "function") then return og; end
    
    if (rawget(self, key) == nil) then
        rawset(self, key, function(_, ...) return og(...); end);
    end

    return rawget(self, key);
end

function RelayLib.instanceof(obj)
    return type(obj) == "table" and getmetatable(obj) == RelayInstance;
end

---@return Relay
function RelayLib.wrap(obj)
    local periph = nil;
    if (obj == redstone) then periph = redstone;
    else periph = Peripheral.asPeripheral(obj); end
    if (periph == nil) then error("periph is nil"); end

    ---@cast periph myCcTweaked.peripherals.Relay
    
    ---@class Relay
    local self = {
        data = {
            relay = periph;
        }
    };

    return setmetatable(self, RelayInstance);
end

--- Set output state on all sides
---@param state boolean
function RelayInstance:setOutputAll(state)
    for _, side in ipairs(Sides.values()) do
        local direction = Sides.toPeripheralName(side);
        self.data.relay.setOutput(direction, state);
    end
end

--- Set redstone output on 1 side
---@param dir? string
---@param state boolean
function RelayInstance:setOutput(dir, state)
    if (dir == nil) then
        self:setOutputAll(state);
        return;
    end
    self.data.relay.setOutput(dir, state);
end

--- Tick a side on and off 
--- @param dir? string
--- @param startState boolean
--- @param time number
function RelayInstance:tick(dir, startState, time)
    self:setOutput(dir, startState);
    sleep(time);
    self:setOutput(dir, not startState);
end


---@alias RelayListener fun(side: integer, prev: integer, new: integer)

function RelayInstance:getState()
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
function RelayInstance:awaitAny()
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
function RelayInstance:awaitAnyPoll(pollCooldown, timeout)
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
function RelayInstance:awaitSide(side, onlyIfLevel)
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
function RelayInstance:awaitSidePoll(side, pollingCooldown, timeout, onlyIfLevel)
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

return RelayLib;