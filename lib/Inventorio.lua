local Peripheral = require("Peripheral");
local Helper = require("Helper")

local _def = Helper.def;

---@class Inventorio
local Inventorio = {};
Inventorio.__index = Inventorio;
Inventorio.PREDICATES = {};

Inventorio.PREDICATES.ITEM_NAME_PREDICATE = function(itemName, amount, toSlot)
    local remaining = amount;
    return function(item)
        if (item.name == itemName) then
            remaining = remaining - item.count;
            return remaining > 0, math.min(remaining, item.count), toSlot;
        end
        return false;
    end
end

local function instanceof(obj, class)
    return type(obj) == "table" and getmetatable(obj) == class;
end

local function asAddress(obj)
    if (instanceof(obj, Inventorio)) then
        return obj.peripheral.address.full;
    end
    return Peripheral.asAddress(obj);
end

local function isInventory(obj)
    if (obj == nil) then return false; end
    local _, type = peripheral.getType(obj);
    return type == "inventory";
end

--- Tries to convert any object to a peripheral.
---@param obj any
---@return nil
local function asInventory(obj)
    if (not isInventory(obj)) then return nil; end
    return Peripheral.asPeripheral(obj);
end

function Inventorio.new(obj)
    local self = {};
    local inv = asInventory(obj);
    if (inv == nil) then return; end

    Peripheral.wrap(inv);
    ---@cast inv +Peripheral

    self.peripheral = inv;
    return setmetatable(self, Inventorio);
end

--- <b>Push an item to another inventory.</b>
---@param toAddr string|table|nil def: `this.address`— an Address `String` | a `Peripheral` object | an `Inventory` object.
---@param fromSlot integer|nil def: `1` — The slot to transfer from
---@param toSlot integer|nil def: `1` — The slot to transfer to
---@param amount integer|nil def: `64` — The amount of items to transfer
---@return integer transferred Amount of items transferred
function Inventorio:push(toAddr, fromSlot, toSlot, amount)
    toAddr = _def(toAddr, self.peripheral.address.full);
    toAddr = asAddress(toAddr);
    fromSlot = _def(fromSlot, 1);

    return self.peripheral.pushItems(toAddr, fromSlot, amount, toSlot);
end

--- <b>Push an item to another inventory.</b>
--- @param toAddr string|table|nil def: `this.address`— an Address `String` | a `Peripheral` object | an `Inventory` object.
--- @param itemName string The name of the item to push.
--- @param amount integer|nil def: `64` — The amount of items to transfer
--- @param toSlot integer|nil def: `1` — The slot to transfer to
function Inventorio:pushName(toAddr, itemName, amount, toSlot)
    local remaining = amount;
    self:pushPredicate(toAddr, function(slot, item)
        if (item.name == itemName) then
            if (remaining <= 0) then return false; end
            local pushAmount = math.min(remaining, item.count);
            remaining = remaining - pushAmount;
            return true, pushAmount, toSlot;
        end
        return false;
    end);
end

--- Pushes items from the inventory to a specified address based on a predicate.
---
--- @param toAddr string|table|nil The address to push items to.
--- @param predicate function A function that takes an item and returns a boolean indicating whether the item is valid, the amount to push, and the slot to push to.
---
---   local function predicate(item)
---     -- example predicate function
---     return true, 1, 1
---   end
---   Inventorio:pushCB("address", predicate)
function Inventorio:pushPredicate(toAddr, predicate)
    for slot, item in pairs(self:getItems()) do
        local valid, amount, toSlot = predicate(slot, item);
        if (valid) then
            self:push(toAddr, slot, toSlot, amount);
        end
    end
end

--- <b>Pull an item to another inventory.</b>
---@param fromAddr string|table|nil def: `this.address`— an Address `String` | a `Peripheral` object | an `Inventory` object.
---@param fromSlot integer|nil def: `1` — The slot to transfer from
---@param toSlot integer|nil def: `1` — The slot to transfer to
---@param amount integer|nil def: `64` — The amount of items to transfer
---@return integer transferred Amount of items transferred
function Inventorio:pull(fromAddr, fromSlot, toSlot, amount)
    fromAddr = asAddress(_def(fromAddr, self.peripheral.address.full));
    fromSlot = _def(fromSlot, 1);

    return self.peripheral.pullItems(fromAddr, fromSlot, amount, toSlot);
end

function Inventorio:contains(itemName)
    return self:containsCB(function(item) return item.name == itemName; end);
end

function Inventorio:containsCB( predicate)
    for _, item in pairs(self:getItems()) do
        if (predicate(item)) then return true; end
    end
    return false;
end

function Inventorio:count(itemName)
    return self:countCB(function(item) return item.name == itemName; end);
end

function Inventorio:countCB(predicate)
    local count = 0;
    for _, item in pairs(self:getItems()) do
        if (predicate(item)) then count = count + item.count; end
    end
    return count;
end

function Inventorio:findEmpty(reverse)
    if (reverse == nil) then reverse = true; end

    local start = nil;
    if (reverse) then
        start = self:size();
    else
        start = 1;
    end

    local finish = nil;
    if (reverse) then
        finish = 1;
    else
        finish = self:size();
    end

    for i in Helper.iterate(start, finish) do
        if (self:isEmptyAt(i)) then return i; end
    end
end

function Inventorio:size()
    return self.peripheral.size();
end

function Inventorio:getItems()
    return self.peripheral.list();
end

--- Gets a map of items to total counts
---@return table<string, number> totals a map of item names -> totals
function Inventorio:getTotals()
    local totals = {};

    for slot, item in pairs(self:getItems()) do
        totals[item.name] = (totals[item.name] or 0) + item.count;
    end

    return totals;
end

function Inventorio:getAt(slot)
    return self:getItems()[slot];
end

--- <b>Returns whether the slot is empty.</b>
---@param slot integer
---@return boolean
function Inventorio:isEmptyAt(slot)
    return self:getAt(slot) == nil;
end

--- <b>Swaps two slots.</b> <br>
--- If one of the slots are empty, the item is pushed to the other slot. <br>
--- If neither are empty, then tries to swap using a temporary empty slot.
---@param slotA integer
---@param slotB integer
---@return boolean success Whether the swap was successful
function Inventorio:swap(slotA, slotB)
    if (slotA == slotB) then return true; end

    local emptyA, emptyB = self:isEmptyAt(slotA), self:isEmptyAt(slotB);
    if (emptyA and emptyB) then return true; end

    if (emptyA or emptyB) then
        local nonEmpty = nil;
        local empty = nil;
        if (emptyA) then
            nonEmpty = slotB;
            empty = slotA;
        else
            nonEmpty = slotA;
            empty = slotB;
        end
        self:push(nil, nonEmpty, empty);
    else
        local emptySlot = self:findEmpty(true);
        if (emptySlot == nil) then return false; end
        self:push(nil, slotA, emptySlot);
        self:push(nil, slotB, slotA);
        self:push(nil, emptySlot, slotB);
    end

    return true;
end

return Inventorio;
