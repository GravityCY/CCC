local Inventorio = require("lib.Inventorio");
local Table = require("lib.Table");
local Loggy = require("lib.Loggy");
local Queue = require("lib.Queue");
local Event = require("lib.Event");

Loggy.setHandler(Loggy.FileLogHandler.new("ae69.log", false));

local LOGGER = Loggy.get("ae69").setDebug(true);

local AE69 = {};

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
            ---@type string
            processorId = nil,
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

---@param processor string
---@return Recipe
function Recipe:setProcessor(processor)
    self.data.processorId = processor;
    return self;
end

AE69.Recipe = Recipe;

AE69.OnRunTasks = Event.new(false, false);
AE69.OnTaskComplete = Event.new(false, false);
AE69.OnTaskQueued = Event.new(false, false);
AE69.OnCraftStart = Event.new(false, false);
AE69.OnCraftRoot = Event.new(false, false);
AE69.OnCraftEnd = Event.new(false, false);

---@type Recipe[]
local recipes = {};

---@class Processor
---@field id string
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

--- Converts a crafting grid slot to a turtle slot
---@param slot number
---@return number
local function toTurtleSlot(slot)
    slot = slot - 1;
    local cx = slot % 3;
    local cy = math.floor(slot / 3);

    return cy * 4 + cx + 1;
end

local function newResult(success, err)
    ---@class Result
    local self = {
        success = success,
        err = err
    };

    return self;
end

---@param recipe Recipe
---@param amount number
---@param parent Task|nil
---@param processorId string
---@return Task
local function newTask(recipe, amount, parent, processorId)
    ---@class Task
    local self = {
        recipe = recipe,
        amount = amount,
        dependencyCount = 0,
        parent = parent;
        ---@type string
        processorId = processorId or "__turtle-crafter__",
    }

    return self;
end

---@param task Task
---@param queueMap table<string, Queue<Task>>
local function tryQueueTask(task, queueMap)
    AE69.OnTaskQueued:invoke(task, queueMap);
    if (task == nil or task.dependencyCount > 0) then return false end
    local queue = queueMap[task.processorId];
    if (queue == nil) then
        queue = Queue.new();
        queueMap[task.processorId] = queue;
    end

    queue:enqueue(task);
    LOGGER.debug("[%s] Queueing Task '%s' at position %d", task.processorId, task.recipe.data.name, queue:size());
    return true;
end

---@param task Task
---@param queueMap table<string, Queue<Task>>
local function completeTask(task, queueMap)
    AE69.OnTaskComplete:invoke(task, queueMap);
    if (task.parent == nil) then return end
    LOGGER.debug("[%s] Task '%s' completed", task.processorId, task.recipe.data.name);
    task.parent.dependencyCount = task.parent.dependencyCount - 1;
    tryQueueTask(task.parent, queueMap);
end

---@param recipeName string
---@param amount number
---@param parent Task|nil
---@param queueMap table<string, Queue<Task>>
---@param totals table<string, number>
local function buildTaskQueue(recipeName, amount, parent, queueMap, totals)
    local recipe = recipes[recipeName];

    if (parent ~= nil and totals[recipeName] ~= nil) then
        local available = totals[recipeName]
        local used = math.min(available, amount)
        totals[recipeName] = available - used
        amount = amount - used;
        if (amount <= 0) then
            LOGGER.debug("(BuildQueue) %s is fully satisfied by storage cutting edge...", recipeName);
            return
        elseif (recipe == nil) then
            error("Don't have enough of " .. recipeName .. ", need " .. amount ..".");
        end
    end

    if (recipe == nil) then
        LOGGER.debug("(buildTaskQueue) Missing recipe '%s'", recipeName);
        return
    end

    if (parent ~= nil) then
        parent.dependencyCount = parent.dependencyCount + 1;
    end

    local task = newTask(recipe, amount, parent, recipe.data.processorId);
    local craftIterations = math.ceil(amount / recipe.data.outputAmount);
    for materialName, need in pairs(recipe.data.materials) do
        buildTaskQueue(materialName, craftIterations * need, task, queueMap, totals);
    end

    if (task.dependencyCount == 0) then
        if (recipe.data.shaped or recipe.data.processorId ~= nil) then
            tryQueueTask(task, queueMap);
        else
            error("unknown processor for recipe " .. recipeName);
        end
    end
end

---@param recipe Recipe
---@param recipeAmount number
local function craftShaped(recipe, recipeAmount)
    local recipeName = recipe.data.name;
    local craftingIterations = math.ceil(recipeAmount / recipe.data.outputAmount);

    local stackIterations = math.ceil(craftingIterations / recipe.data.craftMax);
    LOGGER.debug("(Simple, Shaped) Stack iterations: %d", stackIterations);
    AE69.OnCraftStart:invoke(recipeName, recipeAmount, true);

    local craftsLeft = craftingIterations;
    for j = 1, stackIterations do
        LOGGER.debug("(Simple, Shaped) Pushing into turtle");
        local craftsSplit = math.min(craftsLeft, 64);
        for i = 1, 9 do
            local itemName = recipe.data.shape[i];
            if (itemName ~= nil) then
                buffer:pushName(localName, itemName, craftsSplit, toTurtleSlot(i));
            end
        end
        
        LOGGER.debug("(Simple, Shaped) Crafting...");
        workbench.craft(craftsSplit);

        craftsLeft = craftsLeft - craftsSplit;

        LOGGER.debug("(Simple, Shaped) Pulling out of turtle...");
        for i = 1, 16 do
            local item = turtle.getItemDetail(i);
            if (item == nil) then break end
            buffer:pull(localName, i);
        end
    end
end

---@param recipe Recipe
---@param recipeAmount number
local function craftProcessor(recipe, recipeAmount)
    local craftingIterations = math.ceil(recipeAmount / recipe.data.outputAmount);
    local recipeName = recipe.data.name;

    LOGGER.debug("(Simple, Shapeless) Shapeless recipe");
    AE69.OnCraftStart:invoke(recipeName, recipeAmount, false);
    -- TODO: add proper errors and stuff
    if (recipe.data.processorId == nil) then return false; end
    local processor = processors[recipe.data.processorId]
    if (processor == nil) then return false; end

    LOGGER.debug("(Simple, Shapeless) Pushing into processor '%s'", processor.input.peripheral.address.full);
    for name, amount in pairs(recipe.data.materials) do
        buffer:pushName(processor.input, name, craftingIterations * amount);
    end

    local left = recipeAmount;
    LOGGER.debug("(Simple, Shapeless) Pulling out of processor '%s'", processor.output.peripheral.address.full);
    while true do
        left = left - processor.output:pushName(buffer, recipeName, left)
        if (left <= 0) then break end
        sleep(0.5);
    end
end

--- Crafts a simple recipe 
---@param recipeName string
---@param recipeAmount number
---@return boolean
function AE69.craftSimple(recipeName, recipeAmount)
    if (buffer == nil) then error("buffer is nil") end
    local recipe = recipes[recipeName];
    if (recipe == nil) then return false; end

    LOGGER.debug("(Simple) Crafting x%d '%s'", recipeAmount, recipeName);

    if (recipe.data.shaped) then
        craftShaped(recipe, recipeAmount);
    else
        craftProcessor(recipe, recipeAmount);
    end

    AE69.OnCraftEnd:invoke(recipeName, recipeAmount, recipe.data.shaped);
    LOGGER.debug("(Simple) Done crafting %d %s", recipeAmount, recipeName);
    return true;
end

function AE69.getStockpiles()
    return stockpile;
end

function AE69.registerStock(recipeName, amount)
    stockpile[recipeName] = amount;
end

function AE69.removeStock(name)
    stockpile[name] = nil;
end

function AE69.getRecipes()
    return recipes;
end

---@param ... Recipe
function AE69.registerRecipes(...)
    for _, recipe in ipairs({...}) do
        recipes[recipe.data.name] = recipe;
    end
end

function AE69.removeRecipe(recipeName)
    recipes[recipeName] = nil;
end

function AE69.getProcessors()
    return processors;
end

function AE69.registerProcessor(id, inputAddr, outputAddr)
    local temp = {
        id = id,
        input = Inventorio.new(inputAddr),
        output = Inventorio.new(outputAddr)
    }
    if (temp.input == nil or temp.output == nil) then error("nil input or nil output") end

    processors[id] = temp;
end

function AE69.removeProcessor(id)
    processors[id] = nil;
end

--- Initializes AE3
---@param bufferAddr string
function AE69.init(bufferAddr)
    local temp = Inventorio.new(bufferAddr);
    if (temp == nil) then error("Buffer is nil") end
    buffer = temp;

    workbench = peripheral.find("workbench")
    modem = peripheral.find("modem");
    localName = modem.getNameLocal();
end

---@param recipeName string
---@param amount number
---@return Result success, table<string, Queue<Task>>|nil queueMap
function AE69.buildTaskQueue(recipeName, amount)
    local queueMap = {};
    LOGGER.debug("Building task queue");
    buildTaskQueue(recipeName, amount, nil, queueMap, buffer:getTotals());
    local success, err = pcall(buildTaskQueue, recipeName, amount, queueMap);
    if (not success) then return newResult(success, err) end
    return newResult(true), queueMap;
end

function AE69.canCraftSimple(recipeName, amount)
    if (buffer == nil) then error("Buffer is nil") end
    local recipe = recipes[recipeName];
    if (recipe == nil) then return false; end

    local craftingIterations = math.ceil(amount / recipe.data.outputAmount);
    for name, count in pairs(recipe.data.materials) do
        if (buffer:countName(name) < count * craftingIterations) then return false; end
    end

    return true;
end

--- TODO: DO EXPORTERS AND IMPORTERS

---@param queueMap table<string, Queue<Task>>
function AE69.runTasks(queueMap)
    local fns = {};
    AE69.OnRunTasks:invoke(queueMap);
    for queueName, queue in pairs(queueMap) do
        fns[#fns + 1] = function()
            LOGGER.debug("Running queue '%s'", queueName);
            while not queue:isEmpty() do
                local task = queue:dequeue();
                if (task == nil) then error("somehow nil shut up LSP") end

                LOGGER.debug("[%s] Executing task '%s', %d", queueName, task.recipe.data.name, 1);
                if (AE69.craftSimple(task.recipe.data.name, task.amount)) then
                    completeTask(task, queueMap);
                end
            end
        end
    end
    parallel.waitForAll(table.unpack(fns));
end

--- Crafts a recipe
---@param recipeName string
---@param amount number
---@return Result
function AE69.craft(recipeName, amount)
    LOGGER.debug("Crafting '%s'", recipeName);
    AE69.OnCraftRoot:invoke(recipeName, amount);
    local result, queueMap = AE69.buildTaskQueue(recipeName, amount);
    if (result.success and queueMap ~= nil) then
        AE69.runTasks(queueMap);
        return newResult(true);
    else return result; end
end

--- learns a recipe from the turtles inventory
---@param shaped boolean
---@param processorId string
---@return Recipe
function AE69.learn(shaped, processorId)
    local fns = {};

    local shape = nil;
    local materials = nil;
    local output = nil;

    if (shaped) then
        shape = {};
        for i = 1, 9 do
            fns[#fns+1] = function()
                shape[i] = turtle.getItemDetail(toTurtleSlot(i), true);
            end
        end
    else
        materials = {};
        for i = 1, 15 do
            fns[#fns+1] = function()
                local item = turtle.getItemDetail(i, true);
                if (item ~= nil) then
                    materials[item.name] = (materials[item.name] or 0) + item.count;
                end
            end
        end
    end
    fns[#fns+1] = function() output = turtle.getItemDetail(16, true) end
    
    parallel.waitForAll(table.unpack(fns));

    if (output == nil) then error("no output") end

    if (shaped) then
        return Recipe.new(output.name)
            :setShape(shape)
            :setOutputAmount(output.count)
            :setProcessor(processorId);
    else
        return Recipe.new(output.name)
            :setMaterials(materials)
            :setOutputAmount(output.count)
            :setProcessor(processorId);
    end
end

function AE69.craftAll(recipeList, amountList)
    local queueMap = {};

    local mutableTotals = buffer:getTotals()
    for index, material in pairs(recipeList) do
        local need = amountList[index];
        LOGGER.debug("[craftAll] Queueing %d %s", need, material);
        AE69.OnCraftRoot:invoke(material, need);
        buildTaskQueue(material, need, nil, queueMap, mutableTotals);
        -- local success, error = pcall(buildTaskQueue, material, need - count, nil, queueMap, mutableTotals);
        -- if (not success) then
        --     LOGGER.debug(error);
        --     return false;
        -- end
    end

    local exists = next(queueMap);
    if (exists == nil) then return end
    LOGGER.debug("Running tasks...");
    AE69.runTasks(queueMap);
end

function AE69.poll()
    local recipeList = {};
    local amountList = {};

    for material, need in pairs(stockpile) do
        local count = buffer:countName(material);
        if (count < need) then
            recipeList[#recipeList + 1] = material;
            amountList[#amountList + 1] = need - count;
        end
    end

    AE69.craftAll(recipeList, amountList);
end

function AE69.setRecipes(recipeMap)
    recipes = recipeMap
end

return AE69;