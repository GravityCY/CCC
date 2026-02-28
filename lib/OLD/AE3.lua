local Inventorio = require("lib.Inventorio");
local Table = require("lib.Table");
local Loggy = require("lib.Loggy");
local Queue = require("lib.Queue");

Loggy.setHandler(Loggy.FileLogHandler.new("ae3.log", true));

local LOGGER = Loggy.get("ae3").setDebug(true);

local AE3 = {};

---@class Recipe
local Recipe = {};
Recipe.__index = Recipe;

function Recipe.new(id)
    ---@class Recipe
    local self = {
        data = {
            ---@type string
            name = id,
            ---@type string[]
            shape = {},
            ---@type table<string, number>
            materials = {},
            outputAmount = 1,
            shaped = false,
            craftMax = 64,
            ---@type table<string, number>
            leftovers = {}
        }
    };

    return setmetatable(self, Recipe);
end

function Recipe:setOutputAmount(var)
    self.data.outputAmount = var;
    return self;
end

---@param shape string[]
---@return Recipe
function Recipe:setShape(shape)
    self.data.shape = shape;
    self.data.shaped = true;

    for slot, item in pairs(self.data.shape) do
        self.data.materials[item] = (self.data.materials[item] or 0) + 1;
    end

    return self;
end

---@param materials table<string, number>
---@return Recipe
function Recipe:setMaterials(materials)
    self.data.materials = materials;
    return self;
end

---@param value number
---@return Recipe
function Recipe:setCraftMax(value)
    self.data.craftMax = value;
    return self;
end

---@param var table<string, number>
---@return Recipe
function Recipe:setLeftovers(var)
    self.data.leftovers = var;
    return self;
end

AE3.Recipe = Recipe;

---@type Recipe[]
local recipes = {};

---@class Processor
---@field input Inventorio
---@field output Inventorio

---@type table<string, Processor>
local processors = {};

---@type table<string, number>
local stockpile = {};

---@type Inventorio
local buffer = nil;

local workbench = peripheral.find("workbench")
local modem = peripheral.find("modem");
local localName = modem.getNameLocal();

---@param ... Recipe
function AE3.register(...)
    for _, recipe in ipairs({...}) do
        recipes[recipe.data.name] = recipe;
    end
end

function AE3.init(bufferAddr)
    local temp = Inventorio.new(bufferAddr);
    if (temp == nil) then error("Buffer is nil") end
    buffer = temp;

    workbench = peripheral.find("workbench")
    modem = peripheral.find("modem");
    localName = modem.getNameLocal();
end

---@param recipeName string
---@param inputAddr string
---@param outputAddr string
function AE3.setProcessor(recipeName, inputAddr, outputAddr)
    local temp = {
        input=Inventorio.new(inputAddr),
        output=Inventorio.new(outputAddr)
    }
 
    if (temp.input == nil or temp.output == nil) then error("nil input or nil output") end

    processors[recipeName] = temp;
end

local function newTask(recipeName, amount, parent)
    ---@class Task
    local self = {
        recipe = recipeName,
        amount = amount,
        dependencyCount = 0,
        parent = parent;
    }

    return self;
end

---@param task Task
local function tryQueueTask(task, queueMap)
    if (task.dependencyCount > 0) then return false end
    local processor = processors[task.recipe]
    if (queueMap[processor] == nil) then queueMap[processor] = Queue.new(); end
    queueMap[processor]:enqueue(task);
end

---@param recipeName string
---@param amount number
---@param parent Task|nil
---@param queueMap table<string, Queue>
---@param totals table<string, number>
local function buildTaskQueue(recipeName, amount, parent, queueMap, totals)
    local recipe = recipes[recipeName];
    if (recipe == nil) then return end

    if (totals[recipeName] ~= nil) then
        local available = totals[recipeName]
        local used = math.min(available, amount)
        totals[recipeName] = available - used
        amount = amount - used;
        if (amount <= 0) then return end
    end

    local task = newTask(recipeName, amount, parent);

    local craftIterations = math.ceil(amount / recipe.data.outputAmount);

    for materialName, need in pairs(recipe.data.materials) do
        need = craftIterations * need;
        task.dependencyCount = task.dependencyCount + 1;
        buildTaskQueue(materialName, need, task, queueMap, totals);
    end

    if (task.dependencyCount == 0) then
        if (recipe == nil) then return false, "missing resources";
        else tryQueueTask(task, queueMap); end
    end
    
    return 1;
end

---@param recipeName string
---@param amount number
---@return table<string, Queue<Task>>
function AE3.buildTaskQueue(recipeName, amount)
    local queueMap = {};
    buildTaskQueue(recipeName, amount, nil, queueMap, buffer:getTotals());
    return queueMap;
end

local function calcOrder(recipeName, amount, totals, outOrderList)
    if (totals[recipeName] ~= nil) then
        local available = totals[recipeName]
        local used = math.min(available, amount)
        LOGGER.debug("Using %d of %s", used, recipeName)

        totals[recipeName] = available - used
        amount = amount - used
        if (amount == 0) then
            LOGGER.debug("%s is fully satisfied by storage cutting edge...", recipeName)
            return -1
        end
    end


    -- 1 is raw materials, 2 is first tier, etc
    local recipe = recipes[recipeName];
    local value = 1;
    if (recipe ~= nil) then
        local craftIterations = math.ceil(amount / recipe.data.outputAmount);
        for materialName, need in pairs(recipe.data.materials) do
            local temp = calcOrder(materialName, need * craftIterations, totals, outOrderList);
            if (temp ~= -1) then value = math.max(value, temp + 1); end
        end
        LOGGER.debug("Highest Depth of %s is %d", recipeName, value);
    end

    if (outOrderList[value] == nil) then outOrderList[value] = {}; end
    outOrderList[value][recipeName] = (outOrderList[value][recipeName] or 0) + amount;
    return value;
end

--- TODO: ADD TASK QUEUE SYSTEM SEPARATED BY PROCESSOR TYPE, ALL CRAFTING TASKS AND CUSTOM PROCESSOR TYPES CAN BE SEPARATED BY PARALLELISM
--- queueMap: a map of processor type -> queue
--- iterate recipe tree, queue tasks by processor at bottom with data of parent
--- parallel.waitForAll(craftingQueue, furnaceQueue, etc)
--- when done tell parent to queue task

--- Gets the order to craft things by depth, items at the bottom of the crafting tree come first <br>
--- Also cuts edges based on availability, so it's a true order list <br><br>
--- ***includes raw materials***
---@param recipeName string
---@param amount number the craft amount
---@param totals table<string, number> available items in storage
---@return table<string, number>[]
function AE3.calcOrder(recipeName, amount, totals)
    local orderList = {};
    LOGGER.setDebug(false);
    LOGGER.debug("Calculating order for %s", recipeName);
    calcOrder(recipeName, amount, totals, orderList);
    LOGGER.setDebug(true);
    return orderList;
end

function AE3.canCraftSimple(recipeName, amount)
    if (buffer == nil) then error("Buffer is nil") end
    local recipe = recipes[recipeName];
    if (recipe == nil) then return false; end

    local craftingIterations = math.ceil(amount / recipe.data.outputAmount);
    for name, count in pairs(recipe.data.materials) do
        if (buffer:countName(name) < count * craftingIterations) then return false; end
    end

    return true;
end

function AE3.stock(recipeName, amount)
    stockpile[recipeName] = amount;
end

function AE3.getMissingMaterials(orderList)
    local missing = {};
    LOGGER.debug("Getting missing materials...");
    
    local itemMap = orderList[1];
    for name, count in pairs(itemMap) do
        if (recipes[name] == nil) then
            table.insert(missing, {name=name, count=count})
        end
    end

    return missing;
end

function AE3.isOrderListRunnable(orderList)
    local itemMap = orderList[1];

    for name, count in pairs(itemMap) do
        if (recipes[name] == nil) then
            -- as calcOrder cuts off edges, any materials left with no recipes 
            -- are ones we don't have enough raw mats to craft things
            return false;
        end
    end

    return true;
end

local function convert(slot)
    slot = slot - 1;
    local cx = slot % 3;
    local cy = math.floor(slot / 3);

    return cy * 4 + cx + 1;
end

--- Crafts a simple recipe 
---@param recipeName string
---@param recipeAmount number
---@return boolean
function AE3.craftSimple(recipeName, recipeAmount)
    if (buffer == nil) then error("buffer is nil") end
    local recipe = recipes[recipeName];
    if (recipe == nil) then return false; end

    LOGGER.debug("(Simple) Crafting x%d '%s'", recipeAmount, recipeName);

    local craftingIterations = math.ceil(recipeAmount / recipe.data.outputAmount);
    if (recipe.data.shaped) then
        LOGGER.debug("Shaped recipe");
        local stackIterations = math.ceil(craftingIterations / recipe.data.craftMax);

        LOGGER.debug("Stack iterations: %d", stackIterations);
        for j = 1, stackIterations do
            LOGGER.debug("pushing shaped recipe into turtle");
            for i = 1, 9 do
                local itemName = recipe.data.shape[i];
                if (itemName ~= nil) then
                    LOGGER.debug("pushing %d %s into %s at slot %d", craftingIterations, itemName, localName, convert(i));
                    buffer:pushName(localName, itemName, craftingIterations, convert(i));
                end
            end
            
            LOGGER.debug("now crafting");
            workbench.craft(craftingIterations);
            
            LOGGER.debug("pulling things out");
            for i = 1, 16 do
                local item = turtle.getItemDetail(i);
                if (item == nil) then break end
                buffer:pull(localName, i);
            end
        end
    else
        LOGGER.debug("Shapeless recipe");
        -- TODO: add proper errors and stuff
        local processor = processors[recipeName];
        if (processor == nil) then return false; end

        LOGGER.debug("Pushing into processor input")
        for name, amount in pairs(recipe.data.materials) do
            LOGGER.debug("Pushing %d %s to %s", amount * craftingIterations, name, processor.input);
            buffer:pushName(processor.input, name, craftingIterations * amount);
        end

        local left = recipeAmount;
        LOGGER.debug("Pulling out of processor output");
        while true do
            left = left - processor.output:pushName(buffer, recipeName, left)
            if (left <= 0) then break end
            sleep(0.5);
        end
    end
    return true; 
end

--- Crafts a recipe
---@param recipeName string
---@param amount number
function AE3.craft(recipeName, amount)
    LOGGER.debug("Crafting '%s'", recipeName);
    local orderList = AE3.calcOrder(recipeName, amount, buffer:getTotals());

    local queueMap = AE3.buildTaskQueue(recipeName, amount);
    for queueName, queue in pairs(queueMap) do
        local task = queue:dequeue();
        if (AE3.craftSimple(task.recipe, task.amount)) then
            tryQueueTask(task, queue);
        end
    end

    local missing = AE3.getMissingMaterials(orderList);
    if (#missing > 0) then
        LOGGER.debug("Missing materials: ");
        for _, item in pairs(missing) do
            LOGGER.debug(" - " .. item.count .. " " .. item.name);
        end
        return false, missing;
    end

    LOGGER.debug("Time to start crafting...");
    for orderId = 1, #orderList do
        local itemMap = orderList[orderId];
        for name, count in pairs(itemMap) do
            if (recipes[name] ~= nil) then
                AE3.craftSimple(name, count);
            end
        end
    end
    return true;
end

function AE3.getRecipes()
    return recipes;
end

function AE3.setRecipes(recipeMap)
    recipes = recipeMap
end

function AE3.check()
    while true do
        for material, need in pairs(stockpile) do
            local count = buffer:countName(material);
            if (count < need) then
                AE3.craft(material, need - count);
            end
        end
        sleep(1);
    end
end

return AE3;