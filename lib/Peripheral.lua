--- Title: Peripheral
--- Description: A library for working with peripherals.
--- Version: 0.2.5

local Helper = require("lib.Helper");
local Address = require("lib.Address");

local _def = Helper._def;
local _if = Helper._if;

--- A wrapper for CC peripherals.
local Peripheral = {};
local noSide = true;

local function instanceof(obj, class)
    return type(obj) == "table" and getmetatable(obj) == class;
end

---@param tab Peripheral[]
---@return Peripheral[]
local function removeSide(tab)
    local new = {};
    for _, periph in ipairs(tab) do
        if (not periph.address.isSide()) then
            table.insert(new, periph);
        end
    end
    return new;
end

--- <b>Whether to exclude peripherals on the sides.</b>
---@param value boolean
function Peripheral.setNoSide(value)
    noSide = value;
end

--- <b>Checks if an object is a peripheral.</b>
---@param obj any
---@return boolean
function Peripheral.isPeripheral(obj)
    if (type(obj) ~= "table") then return false; end
    local meta = getmetatable(obj);
    if (meta == nil) then return false; end
    return meta.__name == "peripheral";
end

--- <b>Checks if an object is an address.</b>
---@param obj any
---@return boolean
function Peripheral.isAddress(obj)
    return type(obj) == "string" and peripheral.wrap(obj) ~= nil;
end

--- <b>Converts an object to a peripheral.</b>
---@param obj any
---@return any
function Peripheral.asPeripheral(obj)
    local p = nil;
    if (Peripheral.isAddress(obj)) then p = peripheral.wrap(obj);
    elseif (Peripheral.isPeripheral(obj)) then p = obj; end
    return p;
end

--- <b>Converts an object to an address.</b>
---@param obj any
---@return string
function Peripheral.asAddress(obj)
    local a = nil;
    if (Peripheral.isAddress(obj)) then a = obj;
    elseif (Peripheral.isPeripheral(obj)) then a = peripheral.getName(obj); end
    return a;
end

--- <b>Wraps a peripheral.</b> <br>
--- *Modifies the original peripheral.*
---@param periph table|string
---@return Peripheral|nil
function Peripheral.wrap(periph)
    ---@class Peripheral
    ---@field type string
    periph = Peripheral.asPeripheral(periph);

    if (periph == nil) then return nil end

    _, periph.type = peripheral.getType(periph);
    periph.address = Address.new(peripheral.getName(periph));
    return periph;
end

--- <b>Creates a peripheral wrapper.</b>
--- @param periph table
function Peripheral.new(periph)
    local self = {};
    setmetatable(self, Peripheral);
    self.type = peripheral.getType(periph);
    self.address = Address.new(peripheral.getName(periph));
    self.invoker = periph;
    return self;
end

--- Get a peripheral by address and wraps it.
---@param address string
---@return table|nil Wrapper
function Peripheral.get(address)
    local original = peripheral.wrap(address);
    if (original == nil) then return nil; end
    return Peripheral.wrap(original);
end

--- Get a list of peripherals by type
---@param targetType string
---@return Peripheral[]
function Peripheral.findType(targetType)
    local out = {};
    for _, periph in pairs(peripheral.getNames()) do
        local name, type = peripheral.getType(periph);
        if (type == targetType) then
            table.insert(out, Peripheral.wrap(peripheral.wrap(periph)));
        end
    end
    return out;
end

function Peripheral.firstType(targetType)
    for _, periph in pairs(peripheral.getNames()) do
        local name, type = peripheral.getType(periph);
        if (type == targetType) then
            return Peripheral.wrap(peripheral.wrap(periph));
        end
    end
end

--- Get the first peripheral of the given name.
---@param name string
function Peripheral.first(name)
    local original = peripheral.find(name);
    if (original == nil) then return nil; end
    return Peripheral.wrap(original);
end

--- <b>Get all peripherals of the given name.</b> <br>
--- Removes peripherals on the sides if `noSide` is set.
---@param name string
---@return Peripheral[]|nil peripherals A list of wrapped peripherals.
function Peripheral.find(name)
    local original = {peripheral.find(name)};
    if (#original == 0) then return nil; end
    ---@type Peripheral[]
    local wrapped = {};
    for i = 1, #original do
        table.insert(wrapped, Peripheral.wrap(original[i]));
    end
    if (noSide) then return removeSide(wrapped);
    else return wrapped; end
end

return Peripheral;