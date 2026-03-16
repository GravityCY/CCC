local Peripheral = require("lib.Peripheral");
local Address = require("lib.Address");
local Helper = require("lib.Helper")

local _def = Helper._def;

local InventorioLib = {};
InventorioLib.Predicates = {};

---@class Inventorio
local Inventorio = {};

---@alias ItemPredicate fun(slot: number, item: table): boolean
---@alias PushPredicate fun(slot: number, item: table): boolean, number|nil, number|nil

--- Predicate that allows only matching item names...
---@param itemName string
---@return ItemPredicate
InventorioLib.Predicates.newItemNamePredicate = function(itemName)
    return function(slot, item)
        return item.name == itemName;
    end
end

--- Predicate that allows only matching item names...
---@param itemTag string
---@return ItemPredicate
InventorioLib.Predicates.newItemTagPredicate = function(itemTag)
    return function(slot, item)
        return item.tags[itemTag] ~= nil;
    end
end

InventorioLib.Predicates.newIgnoreSlotPredicate = function(predicate)
    return function(slot, item)
        return predicate(item); 
    end
end

InventorioLib.Predicates.ALWAYS_TRUE = function()
    return true;
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
---@return ccTweaked.peripherals.Inventory?
local function asInventory(obj)
    if (not isInventory(obj)) then return nil; end
    ---@diagnostic disable-next-line: return-type-mismatch
    return Peripheral.asPeripheral(obj);
end

---@class MergedInventory
local MergedInventory = {};

function MergedInventory.instanceof(obj)
    return type(obj) == "table" and instanceof(obj.peripheral, MergedInventory);
end

---@param addrs string[]
---@return Inventorio
function InventorioLib.merge(addrs)
    ---@class MergedInventory
    local self = {};

    local invs = {};
    local startOffsets = {};
    local endOffsets = {};
    local mergedSize = 0;

    ---@param glSlot integer
    ---@return integer invIndex, integer localSlot
    local function toLocalSlot(glSlot)
        assert(glSlot >= 1 and glSlot <= mergedSize, "Slot out of range");

        for i, inv in ipairs(invs) do
            local endOffset = endOffsets[i];
            if (glSlot <= endOffset) then return i, glSlot - startOffsets[i]; end
        end

        return -1, -1;
    end

    local function toGlobalSlot(index, slot)
        return startOffsets[index] + slot;
    end

    ---@param ... string
    function self.add(...)
        for _, addr in ipairs({...}) do
            local inv = peripheral.wrap(addr);
            ---@cast inv ccTweaked.peripherals.Inventory
            local size = inv.size();
            invs[#invs + 1] = inv;
            startOffsets[#startOffsets + 1] = mergedSize;
            endOffsets[#endOffsets + 1] = (mergedSize or 0) + size;
            mergedSize = mergedSize + size;
        end
    end

    ---@return number
    function self.size()
        return mergedSize;
    end

    ---@return table[]
    function self.list()
        local result = {};
        local tasks = {};

        for i, inv in ipairs(invs) do
            tasks[#tasks+1] = function()
                for slot, item in pairs(inv.list()) do
                    result[startOffsets[i] + slot] = item;
                end
            end
        end
        
        Helper.batch(tasks, false, 64);
        return result;
    end

    ---@param glSlot integer
    ---@param detail boolean|nil
    ---@return table
    function self.getItemDetail(glSlot, detail)
        local index, lcSlot = toLocalSlot(glSlot);
        return invs[index].getItemDetail(lcSlot, detail);
    end

    function self.pushItems(toAddr, fromSlot, amount, toSlot)
        local index, slot = toLocalSlot(fromSlot);
        return invs[index].pushItems(toAddr, slot, amount, toSlot);
    end

    ---@param fromSlot number
    ---@param amount number|nil
    ---@param toSlot number|nil
    ---@return number
    function self.pullItems(fromObj, fromSlot, amount, toSlot)
        local fromAddr = asAddress(fromObj);
        amount = amount or 64;

        local localIndex, localSlot = toLocalSlot(toSlot or 1);

        local pushed = 0;
        for si = localIndex, #invs do
            local inv = invs[si];

            ---@type number?
            local tempSlot = localSlot;
            if (si ~= localIndex or toSlot == nil) then tempSlot = nil; end

            pushed = pushed + inv.pullItems(fromAddr, fromSlot, amount - pushed, tempSlot);
            if (pushed >= amount) then break; end
        end
        return pushed;
    end

    function self.invs()
        return invs;
    end

    for _, addr in ipairs(addrs) do
        self.add(addr);
    end

    local inventorio = setmetatable({}, {__index=Inventorio});
    ---@diagnostic disable-next-line: assign-type-mismatch
    inventorio.peripheral = setmetatable(self, MergedInventory);

    inventorio.peripheral.type = "inventory";
    inventorio.peripheral.address = Address.new("inventorio:merged_inventory_0");

    return inventorio;
end

--- Creates a new Inventorio object.
---@param obj string|table an Address `String` | a `Peripheral` object.
---@return Inventorio
function InventorioLib.new(obj)
    local inv = asInventory(obj);
    assert(inv ~= nil, "Invalid inventory");

    Peripheral.wrap(inv);
    ---@cast inv +Peripheral

    ---@class Inventorio
    local self = {
        peripheral = inv;
        cache = nil;
        cacheDepth = 0
    };
    return setmetatable(self, {__index=Inventorio});
end

--- <b>Push an item to another inventory.</b>
---@param toObj string|table an Address `String` | a `Peripheral` object | an `Inventory` object.
---@param fromSlot integer The slot to transfer from
---@param toSlot integer? The slot to transfer to
---@param amount integer? The amount of items to transfer
---@return integer transferred Amount of items transferred
function Inventorio:push(toObj, fromSlot, toSlot, amount)
    if (MergedInventory.instanceof(toObj)) then
        ---@cast toObj MergedInventory
        return toObj.peripheral.pullItems(self, fromSlot, amount, toSlot);
    end
    local toAddr = asAddress(toObj);
    return self.peripheral.pushItems(toAddr, fromSlot, amount, toSlot);
end

--- <b>Push an item to another inventory.</b>
--- @param toAddr string|table an Address `String` | a `Peripheral` object | an `Inventory` object.
--- @param itemName string The name of the item to push.
--- @param amount integer def: `64` — The amount of items to transfer
--- @param toSlot integer? def: `1` — The slot to transfer to
--- @param reverse boolean? def: `false` — If true, the items will be pushed in reverse order
function Inventorio:pushName(toAddr, itemName, amount, toSlot, reverse)
    return self:pushAmountPredicate(toAddr, amount, toSlot, false, reverse, InventorioLib.Predicates.newItemNamePredicate(itemName))
end

--- <b>Push an item to another inventory.</b>
--- @param toAddr string|table an Address `String` | a `Peripheral` object | an `Inventory` object.
--- @param itemTag string The name of the item to push.
--- @param amount integer def: `64` — The amount of items to transfer
--- @param toSlot integer? def: `1` — The slot to transfer to
--- @param reverse boolean? def: `false` — If true, the items will be pushed in reverse order
function Inventorio:pushTag(toAddr, itemTag, amount, toSlot, reverse)
    return self:pushAmountPredicate(toAddr, amount, toSlot, true, reverse, InventorioLib.Predicates.newItemTagPredicate(itemTag));
end

--- Push a specific amount of items into an inventory by predicate
--- @param toAddr string|table The address to push items to.
---@param amount number the amount to push
---@param toSlot number? the slot to push to
---@param detail boolean? def: `false`
---@param reverse boolean? def: `false`
---@param itemPredicate ItemPredicate
---@return number pushed number of items succesfully pushed
function Inventorio:pushAmountPredicate(toAddr, amount, toSlot, detail, reverse, itemPredicate)
    local remaining = amount or 1;
    -- LOGGER.debug("Pushing %d items into %s", remaining, toAddr);

    return self:pushPredicate(toAddr, detail, reverse, function(slot, item)
        if (itemPredicate(slot, item)) then
            -- LOGGER.debug("checking slot %d for %s", slot, item.name);
            if (remaining <= 0) then return false; end
            local pushAmount = math.min(remaining, item.count);
            remaining = remaining - pushAmount;
            -- LOGGER.debug("pushing %d %s into %s at slot %d", pushAmount, item.name, toAddr, toSlot);
            return true, pushAmount, toSlot;
        end
        return false;
    end);
end

--- Pushes items from the inventory to a specified address based on a predicate.
---
--- @param toAddr string|table The address to push items to.
--- @param detail boolean? def: `false`
--- @param reverse boolean? def: `false`
--- @param predicate PushPredicate A function that takes an item and returns a boolean indicating whether the item is valid, the amount to push, and the slot to push to.
--- @return number pushed number of items succesfully pushed
function Inventorio:pushPredicate(toAddr, detail, reverse, predicate)
    if (detail == nil) then detail = false; end
    if (reverse == nil) then reverse = false; end

    local start = nil;
    local finish = nil;
    if (reverse) then 
        start = self:size();
        finish = 1;
    else
        start = 1; 
        finish = self:size();
    end

    local pushed = 0;
    local items = self:getItems(detail);
    for slot in Helper.iterate(start, finish) do
        local item = items[slot];
        if (item ~= nil) then
            local valid, amount, toSlot = predicate(slot, item);
            if (valid) then
                pushed = pushed + self:push(toAddr, slot, toSlot, amount);
            end
        end
    end
    return pushed;
end

--- <b>Pull an item to another inventory.</b>
---@param fromAddr string an Address `String` | a `Peripheral` object | an `Inventory` object.
---@param fromSlot integer The slot to transfer from
---@param toSlot integer? def: `1` — The slot to transfer to
---@param amount integer? def: `64` — The amount of items to transfer
---@return integer transferred Amount of items transferred
function Inventorio:pull(fromAddr, fromSlot, toSlot, amount)
    fromAddr = asAddress(_def(fromAddr, self.peripheral.address.full));

    return self.peripheral.pullItems(fromAddr, fromSlot, amount, toSlot);
end

--- check if it contains a specific item by name
---@param itemName string
---@return boolean
function Inventorio:containsName(itemName)
    return self:containsPredicate(InventorioLib.Predicates.newItemNamePredicate(itemName));
end

--- check if it contains a specific item
---@param predicate fun(slot: number, item: table): boolean
---@return boolean
function Inventorio:containsPredicate(predicate)
    for slot, item in pairs(self:getItems()) do
        if (predicate(slot, item)) then return true; end
    end
    return false;
end

--- count an item by name
---@param itemName string name
---@return integer
function Inventorio:countName(itemName)
    return self:countPredicate(false, InventorioLib.Predicates.newItemNamePredicate(itemName));
end

--- count an item by tag
---@param itemTag string tag
---@return integer
function Inventorio:countTag(itemTag)
    return self:countPredicate(true, InventorioLib.Predicates.newItemTagPredicate(itemTag));
end

--- Count items by predicate
---@param detail boolean? whether to include details
---@param predicate fun(slot: number, item: table): boolean
---@return integer
function Inventorio:countPredicate(detail, predicate)
    if (detail == nil) then detail = false; end

    local count = 0;
    for slot, item in pairs(self:getItems(detail)) do
        if (predicate(slot, item)) then count = count + item.count; end
    end
    return count;
end

--- Find all empty slots
---@param reverse boolean if true `end->start`, if false `start->end`, default: `false`
---@return integer[] slots
function Inventorio:findEmpty(reverse)
    return self:findPredicate(false, reverse, true, function(item, slot) return item == nil; end);
end

--- Find items by name
---@param reverse boolean if true `end->start`, if false `start->end`, default: `false`
---@return integer[] slots
function Inventorio:findName(name, reverse)
    return self:findPredicate(false, reverse, false, InventorioLib.Predicates.newItemNamePredicate(name));
end

--- Find items by tag
---@param reverse boolean if true `end->start`, if false `start->end`, default: `false`
---@return integer[] slots
function Inventorio:findTag(tag, reverse)
    return self:findPredicate(false, reverse, false, InventorioLib.Predicates.newItemTagPredicate(tag));
end

function Inventorio:findPredicate(detail, reverse, allowNils, predicate)
    if (detail == nil) then detail = false; end
    if (reverse == nil) then reverse = false; end
    if (allowNils == nil) then allowNils = false; end

    local start = nil;
    local finish = nil;
    if (reverse) then
        start = self:size();
        finish = 1;
    else
        start = 1;
        finish = self:size();
    end

    local ret = {};
    
    local items = self:getItems();
    for slot in Helper.iterate(start, finish) do
        local item = items[slot];
        local shouldTest = allowNils or item ~= nil;
        if (shouldTest and predicate(item, slot)) then table.insert(ret, slot) end
    end

    return ret;
end

--- size of inventory
---@return number
function Inventorio:size()
    return self.peripheral.size();
end

--- get all items
---@param detail boolean|nil include extra item data
---@return table[] items
function Inventorio:getItems(detail)
    if (self.cache ~= nil) then return self.cache; end

    return self:getItemsRaw(detail);
end

function Inventorio:getItemsRaw(detail)
    if (detail == nil) then detail = false; end

    if (detail) then
        local items = {};

        local fns = {};

        for i = 1, self.peripheral.size() do
            fns[#fns+1] = function() items[i] = self.peripheral.getItemDetail(i) end
        end

        parallel.waitForAll(table.unpack(fns));

        return items;
    end
    
    return self.peripheral.list();
end

function Inventorio:cacheItems(detail)
    self.cache = self:getItemsRaw(detail);
    return self.cache;
end

--- Any item IO will use this cache.<br>
--- <b>DOES NOT SIMULATE IO!<b>
---@param enable boolean?
---@param detail boolean?
---@return table?
function Inventorio:useCache(enable, detail, update)
    if (enable == nil) then enable = false; end
    if (detail == nil) then detail = false; end

    if (not enable) then
        self.cacheDepth = self.cacheDepth - 1;
        assert(self.cacheDepth >= 0, "cacheDepth cannot be less than 0");

        if (self.cacheDepth == 0) then
            self.cache = nil;
            return nil;
        end
        
        if (update) then self:cacheItems(detail); end
        return self.cache;
    end

    self.cacheDepth = self.cacheDepth + 1;

    if (self.cacheDepth == 1) then
        return self:cacheItems(detail);
    end

    return self.cache;
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

--- Get item at specific slot <br>
--- Be careful about using this as it asks Minecraft for a new list every time +50ms
---@param slot number
---@return table
function Inventorio:getAt(slot)
    return self:getItems()[slot];
end

--- <b>Returns whether the slot is empty.</b>
--- Be careful about using this as it asks Minecraft for a new list every time +50ms
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

    return self:runWithCache(false, true, function()
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
            self:push(self.peripheral, nonEmpty, empty);
        else
            local emptySlot = self:findEmpty(true)[1];
            if (emptySlot == nil) then return false; end
            self:push(self.peripheral, slotA, emptySlot);
            self:push(self.peripheral, slotB, slotA);
            self:push(self.peripheral, emptySlot, slotB);
        end

        return true;
    end);
end

--- Run a bunch of Inventorio functions using the cache
---@param detail boolean
---@param updatesCache boolean
---@param fn function
---@param ... any
---@return ... any
function Inventorio:runWithCache(detail, updatesCache, fn, ...)
    self:useCache(true, detail, updatesCache);
    local args = {pcall(fn, ...)}
    local ok = args[1];
    self:useCache(false, detail, updatesCache)
    if (not ok) then error(args[2]) end
    return table.unpack(args, 2)
end

function Inventorio:getItemOrder(detail, reverse, predicate)
    if (detail == nil) then detail = false end
    if (reverse == nil) then reverse = false end
    
    local order = {};

    local start, finish = 1, self:size();
    if (reverse) then start, finish = finish, start; end

    local items = self:getItems();
    local position = 1;
    for slot in Helper.iterate(start, finish) do
        local item = items[slot];
        if (predicate(item, slot)) then
            order[#order+1] = position;
        end

        if (item ~= nil) then position = position + 1; end
    end
    return order;
end

return InventorioLib;
