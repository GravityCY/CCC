local EasyAddress = require("lib.EasyAddress");
local Inventorio  = require("lib.Inventorio")

local Schmopper = {};

local ATT = nil;

---@type table<string, Inventorio>
local inventories = {};

---@type Import[]
local importList = {};
---@type Export[]
local exportList = {};

local Rule = {};
Schmopper.Rule = Rule;

function Rule.Import()
    ---@class Import
    local self = {};
    self.data = {};
    self.data.source = nil;
    self.data.target = nil;
    self.data.predicate = Inventorio.Predicates.ALWAYS_TRUE;
    self.data.detailed = false;
    self.data.upto = nil;

    --- Assign 1 source
    ---@param sourceName string
    ---@return Import
    function self.source(sourceName)
        self.data.source = sourceName;
        return self;
    end

    --- Assign 1 target
    ---@param targetName string
    ---@return Import
    function self.target(targetName)
        self.data.target = targetName;
        return self;
    end

    --- Import by item name
    ---@param name string
    ---@return Import
    function self.name(name)
        self.data.predicate = Inventorio.Predicates.newItemNamePredicate(name);
        return self;
    end

    --- Import by item tag
    ---@param tag string
    ---@return Import
    function self.tag(tag)
        self.data.predicate = Inventorio.Predicates.newItemTagPredicate(tag);
        self.data.detailed = true;
        return self;
    end

    --- Import by predicate
    ---@param predicate fun(slot: number, item: table): boolean
    ---@param detailed boolean whether to show all item data
    function self.predicate(predicate, detailed)
        self.data.predicate = predicate;
        self.data.detailed = detailed;
    end

    --- The max amount to store
    --- @param uptoAmount number
    function self.upto(uptoAmount)
        self.data.upto = uptoAmount;
        return self;
    end

    --- Run rule
    ---@return boolean succcess
    function self.execute()
        local sourceInventory = inventories[self.data.source];
        local targetInventory = inventories[self.data.target];
        local pull = math.huge;

        if (self.data.upto ~= nil) then
            local stored = targetInventory:countPredicate(self.data.predicate, self.data.detailed);
            if (stored >= self.data.upto) then return false; end
            pull = self.data.upto - stored;
        end

        sourceInventory:pushAmountPredicate(targetInventory, nil, pull, self.data.detailed, self.data.predicate);
    end

    --- Register to list of import rules
    function self.register()
        importList[#importList+1] = self;
    end

    return self;
end

function Rule.Export()
    ---@class Export
    local self = {};
    self.data = {};
    self.data.source = nil;
    self.data.targets = nil;
    self.data.percents = nil;
    self.data.order = nil;
    self.data.predicate = Inventorio.Predicates.ALWAYS_TRUE;
    self.data.detailed = false;
    self.data.keep = nil;

    --- The source inventory
    ---@param sourceName string
    ---@return Export
    function self.source(sourceName)
        self.data.source = sourceName;
        return self;
    end

    --- The list of targets
    ---@param ... string
    ---@return Export
    function self.targets(...)
        self.data.targets = {...};
        return self;
    end

    --- The order of targets priority
    ---@param ... number
    ---@return Export
    function self.order(...)
        self.data.order = {...};
        return self;
    end

    --- The percentage of items the targets will receive
    ---@param ... number 0-100
    ---@return Export
    function self.percents(...)
        self.data.percents = {...};
        return self;
    end

    --- Export by item name
    ---@param name string
    ---@return Export
    function self.name(name)
        self.data.predicate = Inventorio.Predicates.newItemNamePredicate(name);
        return self;
    end

    --- Export by item tag
    ---@param tag string
    ---@return Export
    function self.tag(tag)
        self.data.predicate = Inventorio.Predicates.newItemTagPredicate(tag);
        self.data.detailed = true;
        return self;
    end

    --- Export by predicate
    ---@param predicate fun(slot: number, item: boolean): boolean
    ---@param detailed boolean whether to show all item data
    function self.predicate(predicate, detailed)
        self.data.predicate = predicate;
        self.data.detailed = detailed;
    end

    --- Keep this amount of items before exporting
    ---@param atleast number
    ---@return Export
    function self.keep(atleast)
        self.data.keep = atleast;
        return self;
    end

    --- Run export rule
    ---@return boolean
    function self.execute()
        local sourceInventory = inventories[self.data.source];
        local available = sourceInventory:countPredicate(self.data.predicate, self.data.detailed);
        if (self.data.keep ~= nil) then
            if (available <= self.data.keep) then return false; end
            available = available - self.data.keep;
        end

        if (self.data.order ~= nil and #self.data.order ~= #self.data.targets) then
            error("The order you want to fill targets up needs to be the same amount as there is targets...");
        end

        local left = available;
        local percentageTotal = 100;
        for iteration = 1, #self.data.targets do
            local invIndex = (self.data.order and self.data.order[iteration]) or iteration;
            local targetName = self.data.targets[invIndex];
            local targetInventory = inventories[targetName];
            local tempPush = left;
            if (self.data.percents ~= nil) then
                local iterationsLeft = #self.data.targets - iteration + 1;
                local percent = self.data.percents[invIndex] or (percentageTotal / iterationsLeft);
                percentageTotal = percentageTotal - percent;
                tempPush = math.ceil(available * percent / 100);
            end
            left = left - sourceInventory:pushAmountPredicate(targetInventory, nil, tempPush, self.data.detailed, self.data.predicate);
            if (left <= 0) then break end
        end
        return true;
    end

    function self.register()
        exportList[#exportList+1] = self;
    end

    return self;
end

function Schmopper.start(sleepTime)
    sleepTime = sleepTime or 1;

    while true do
        for _, export in ipairs(exportList) do
            export.execute();
        end

        for _, import in ipairs(importList) do
            import.execute();
        end
        sleep(sleepTime);
    end
end

function Schmopper.init(id)
    ATT = EasyAddress.new("smopper-"..id);
end

function Schmopper.inventory(name)
    if (ATT == nil) then error("Not initialized...") end

    inventories[name] = Inventorio.new(ATT.get(name, true));
end

return Schmopper;