local Inventorio = require("lib.Inventorio");

local PorterLib = {};

---@class PorterPredicate
local PorterPredicate = {};

---@return PorterPredicate
function PorterPredicate.deserialize(text)
    ---@type SerializedPredicate
    local obj = textutils.unserialize(text);
    return PorterLib.PredicateRegistry[obj.id]:create(table.unpack(obj.args));
end

---@return string
function PorterPredicate:serialize(compact)
    ---@class SerializedPredicate
    local obj = {
        id = self.id;
        args = self.args
    }

    return textutils.serialize(obj, {compact=compact});
end

---@class PorterPredicateFactory
local PredicateFactory = {};

function PredicateFactory.new(id, detailed, factory)
    ---@class PorterPredicateFactory
    local self = {
        ---@type string
        id = id;
        ---@type boolean
        detailed = detailed,
        ---@type fun(...): fun(slot: number, item: table): boolean
        factory = factory;
    };

    return setmetatable(self, {__index=PredicateFactory});
end

function PredicateFactory:create(...)
    ---@class PorterPredicate
    local predicate = {
        ---@type string
        id = self.id;
        args = {...};
        ---@type fun(slot: number, item: table): boolean
        _cache = self.factory(...);
    };

    return setmetatable(predicate, {__index=PorterPredicate});
end

---@type table<string, PorterPredicateFactory>
PorterLib.PredicateRegistry = {
    ITEM_NAME = PredicateFactory.new("ITEM_NAME", false, Inventorio.Predicates.newItemNamePredicate);
    ITEM_TAG = PredicateFactory.new("ITEM_TAG", true, Inventorio.Predicates.newItemTagPredicate);
};

---@class Porter
local Porter = {};

function Porter.new()
    ---@class Porter
    local self = {
        data = {
            ---@type PorterPredicate
            itemFilter = nil,
            -- ---@type fun(): boolean
            -- condition = nil,
            
            ---@type number
            slot = nil,
            ---@type number
            stock = math.huge,
            ---@type number
            leave = 0
        }
    };

    return self;
end

-- function Porter:condition(predicate)
--     self.data.condition = predicate;
--     return self;
-- end

---@param predicate PorterPredicate
function Porter:filter(predicate)
    self.data.itemFilter = predicate;
    return self;
end

function Porter:slot(slot)
    self.data.slot = slot;
    return self;
end

function Porter:stock(amount)
    self.data.stock = amount;
    return self;
end

function Porter:leave(amount)
    self.data.leave = amount;
    return self;
end

function Porter:shouldRun()
    return true -- self.data.condition == nil or self.data.condition();
end

---@class Importer : Porter
local Importer = setmetatable({}, {__index=Porter});
Importer.super = Porter;

--- Importer first, so check for self:shouldRun in Importer, it doesn't exist therefore run Porter:shouldRun

function Importer.new()
    ---@class Importer
    local self = Porter.new();
    ---@type Inventorio
    self.data.source = nil;

    return setmetatable(self, {__index=Importer});
end

function Importer.deserialize(text)
    local obj = textutils.unserialize(text);
    ---@cast obj SerializedImporter

    return Importer.new()
        :source(Inventorio.new(obj.data.source))
        :filter(PorterPredicate.deserialize(obj.data.itemFilter))
        :slot(obj.data.slot)
        :stock(obj.data.stock)
        :leave(obj.data.leave);
end

function Importer:serialize(compact)
    ---@class SerializedImporter
    local obj = {
        data = {
            ---@type string
            source = self.data.source.peripheral.address.full;
            itemFilter = self.data.itemFilter and self.data.itemFilter:serialize(true);
            slot = self.data.slot;
            stock = self.data.stock;
            leave = self.data.leave
        }
    }

    return textutils.serialize(obj, {compact=compact});
end

function Importer:source(inv)
    self.data.source = inv;
    return self;
end

---@param target Inventorio
function Importer:run(target)
    if (not self:shouldRun()) then return end

    local predicate = (self.data.itemFilter and self.data.itemFilter._cache) or Inventorio.Predicates.ALWAYS_TRUE;

    if (self.data.slot ~= nil) then
        local slot = self.data.source:getAt(self.data.slot);
        if (slot == nil) then return end
        self.data.source:push(target, self.data.slot, nil, slot.count);
        return;
    end

    local available = self.data.source:countPredicate(predicate, false);
    if (available <= self.data.leave) then return end
    available = available - self.data.leave;

    local have = target:countPredicate(predicate, false);
    local need = self.data.stock - have;
    if (need <= 0) then return end

    if (self.data.slot ~= nil) then
        local items = self.data.source:getItems();
        if (predicate(self.data.slot, items[self.data.slot])) then
            self.data.source:push(target, self.data.slot, nil, need);
        end
    else
        self.data.source:pushAmountPredicate(target, nil, need, false, predicate);
    end
end

---@class Exporter : Porter
local Exporter = setmetatable({}, {__index=Porter});

function Exporter.new()
    ---@class Exporter
    local self = Porter.new();
    ---@type Inventorio
    self.data.target = nil;

    return setmetatable(self, {__index=Exporter});
end

function Exporter.deserialize(text)
    local obj = textutils.unserialize(text);
    ---@cast obj SerializedExporter

    return Exporter.new()
        :target(Inventorio.new(obj.data.target))
        :filter(PorterPredicate.deserialize(obj.data.itemFilter))
        :slot(obj.data.slot)
        :stock(obj.data.stock)
        :leave(obj.data.leave);
end

function Exporter:serialize(compact)
    ---@class SerializedExporter
    local obj = {
        data = {
            ---@type string
            target = self.data.target.peripheral.address.full;
            itemFilter = self.data.itemFilter and self.data.itemFilter:serialize(true);
            slot = self.data.slot;
            stock = self.data.stock;
            leave = self.data.leave
        }
    }

    return textutils.serialize(obj, {compact=compact});
end

function Exporter:target(inv)
    self.data.target = inv;
    return self;
end

---@param source Inventorio
function Exporter:run(source)
    if (not self:shouldRun()) then return end
    local predicate = (self.data.itemFilter and self.data.itemFilter._cache) or Inventorio.Predicates.ALWAYS_TRUE;
    local count = source:countPredicate(predicate, false);
    local need = self.data.stock - count;
    if (need <= 0) then return end
    source:pushAmountPredicate(self.data.target, self.data.slot, need, false, predicate);
end

PorterLib.Importer = Importer;
PorterLib.Exporter = Exporter;

return PorterLib;