--- Title: Peripheral
--- Description: A library for working with peripherals.
--- Version: 0.2.5

local Helper = require("lib.Helper");
local Address = require("lib.Address");

local _def = Helper._def;
local _if = Helper._if;

--- A wrapper for CC peripherals.
local PeripheralLib = {};
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
function PeripheralLib.setNoSide(value)
    noSide = value;
end

--- <b>Checks if an object is a peripheral.</b>
---@param obj any
---@return boolean
function PeripheralLib.isPeripheral(obj)
    if (type(obj) ~= "table") then return false; end
    local meta = getmetatable(obj);
    if (meta == nil) then return false; end
    return meta.__name == "peripheral";
end

--- <b>Checks if an object is an address.</b>
---@param obj any
---@return boolean
function PeripheralLib.isAddress(obj)
    if (type(obj) ~= "string") then return false; end
    local str = obj;
    if (peripheral.isPresent(str)) then return true; end
    local modem = peripheral.find("modem");
    if (modem == nil) then return false; end
    return str == modem.getNameLocal();
end

--- <b>Converts an object to a peripheral.</b>
---@param obj string|ccTweaked.peripherals.wrappedPeripheral
---@return ccTweaked.peripherals.wrappedPeripheral
function PeripheralLib.asPeripheral(obj)
    local p = nil;
    if (PeripheralLib.isAddress(obj)) then
        ---@cast obj string
        p = peripheral.wrap(obj);
    elseif (PeripheralLib.isPeripheral(obj)) then
        p = obj;
    end
    ---@cast p ccTweaked.peripherals.wrappedPeripheral
    return p;
end

--- <b>Converts an object to an address.</b>
---@param obj any
---@return string
function PeripheralLib.asAddress(obj)
    local a = nil;
    if (PeripheralLib.isAddress(obj)) then a = obj;
    elseif (PeripheralLib.isPeripheral(obj)) then a = peripheral.getName(obj); end
    return a;
end

--- <b>Wraps a peripheral.</b> <br>
--- *Modifies the original peripheral.*
---@param periph table|string
function PeripheralLib.wrap(periph)
    ---@class Peripheral
    periph = PeripheralLib.asPeripheral(periph);

    if (periph == nil) then return nil end

    _, periph.type = peripheral.getType(periph);
    periph.address = Address.new(peripheral.getName(periph));
    return periph;
end

local function __index(self, key)
    local og = self.periph[key];
    local t = type(og);
    if (t ~= "function") then return og; end
    return function(_, ...) return og(...); end
end

--- <b>Creates a peripheral wrapper.</b>
--- @param periph string|ccTweaked.peripherals.wrappedPeripheral
function PeripheralLib.new(periph)
    local self = {};
    periph = PeripheralLib.asPeripheral(periph);
    self.type = peripheral.getType(periph);
    self.address = Address.new(peripheral.getName(periph));
    self.periph = periph;
    setmetatable(self, {__index=function(tab, key) end});
    return self;
end

--- Get a peripheral by address and wraps it.
---@param address string
---@return table|nil Wrapper
function PeripheralLib.get(address)
    local original = peripheral.wrap(address);
    if (original == nil) then return nil; end
    return PeripheralLib.wrap(original);
end

--- Get a list of peripherals by type
---@param targetType string
---@return Peripheral[]
function PeripheralLib.findType(targetType)
    local out = {};
    for _, periph in pairs(peripheral.getNames()) do
        local name, type = peripheral.getType(periph);
        if (type == targetType) then
            table.insert(out, PeripheralLib.wrap(peripheral.wrap(periph)));
        end
    end
    return out;
end

function PeripheralLib.firstType(targetType)
    for _, periph in pairs(peripheral.getNames()) do
        local name, type = peripheral.getType(periph);
        if (type == targetType) then
            return PeripheralLib.wrap(peripheral.wrap(periph));
        end
    end
end

function PeripheralLib.firstByPredicate(predicate)
    for _, name in pairs(peripheral.getNames()) do
        local p = peripheral.wrap(name);
        if (predicate(p)) then
            return PeripheralLib.wrap(p);
        end
    end
end

function PeripheralLib.findByPredicate(predicate)
    local out = {};

    for _, name in pairs(peripheral.getNames()) do
        local p = peripheral.wrap(name);
        if (predicate(p)) then
            table.insert(out, PeripheralLib.wrap(p));
        end
    end

    return out;
end

function PeripheralLib.findByKey(key)
    for _, periph in pairs(peripheral.getNames()) do
        if (peripheral.hasMethod(periph, key) ~= nil) then
            return PeripheralLib.wrap(peripheral.wrap(periph));
        end
    end
end

--- Get the first peripheral of the given name.
---@param name string
function PeripheralLib.first(name)
    local original = peripheral.find(name);
    if (original == nil) then return nil; end
    return PeripheralLib.wrap(original);
end

--- <b>Get all peripherals of the given name.</b> <br>
--- Removes peripherals on the sides if `noSide` is set.
---@param name string
---@return Peripheral[]|nil peripherals A list of wrapped peripherals.
function PeripheralLib.find(name)
    local original = {peripheral.find(name)};
    if (#original == 0) then return nil; end
    ---@type Peripheral[]
    local wrapped = {};
    for i = 1, #original do
        table.insert(wrapped, PeripheralLib.wrap(original[i]));
    end
    if (noSide) then return removeSide(wrapped);
    else return wrapped; end
end

return PeripheralLib;