local Inventorio = require("lib.Inventorio");
local Table = require("lib.Table");
local Loggy = require("lib.Loggy");
local Queue = require("lib.Queue");
local Event = require("lib.Event");

Loggy.setHandler(Loggy.FileLogHandler.new("ae69.log", false));

local LOGGER = Loggy.get("ae69").setDebug(true);

--- TODO: IMPORTERS AND EXPORTERS
--- TODO: RETURN MISSING MATERIALS


local AE69 = {};

local TaskManager = require("lib.AE69.TaskManager");
local Recipe = require("lib.AE69.Recipe");
local Task = TaskManager.Task;
AE69.Recipe = Recipe;

AE69.OnRunTasks = Event.new(false, false);
AE69.OnTaskComplete = Event.new(false, false);
AE69.OnTaskQueued = Event.new(false, false);
AE69.OnCraftStart = Event.new(false, false);
AE69.OnCraftRoot = Event.new(false, false);
AE69.OnCraftEnd = Event.new(false, false);

---@class Processor
---@field id string
---@field input Inventorio
---@field output Inventorio

local workbench = peripheral.find("workbench")
local modem = peripheral.find("modem");
local localName = modem.getNameLocal();

---@type table<string, Recipe>
local recipes = {};

---@type Inventorio
local buffer = nil;

---@type table<string, Processor>
local processors = {};

---@type table<string, number>
local stockpile = {};

local taskManager = TaskManager.new();
taskManager.taskQueues["__turtle-crafter__"] = Queue.new();

--- Converts a crafting grid slot to a turtle slot
---@param slot number
---@return number
local function toTurtleSlot(slot)
    slot = slot - 1;
    local cx = slot % 3;
    local cy = math.floor(slot / 3);

    return cy * 4 + cx + 1;
end

---@param recipeName string
---@param amount number
---@param parent Task|nil
---@param totals table<string, number>
local function buildTasks(recipeName, amount, parent, totals)
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

    local root = parent and parent.root;
    if (root == nil) then root = parent; end

    local task = Task.new(recipe, amount, parent, root, recipe.data.processorId);
    local craftIterations = math.ceil(amount / recipe.data.outputAmount);
    for materialName, need in pairs(recipe.data.materials) do
        buildTasks(materialName, craftIterations * need, task, totals);
    end

    if (task.dependencyCount == 0) then
        if (recipe.data.shaped or recipe.data.processorId ~= nil) then
            taskManager:queueTask(task);
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
            if (item ~= nil) then
                buffer:pull(localName, i);
            end
        end
    end
    return true;
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
    assert(temp.input ~= nil, "nil input");
    assert(temp.output ~= nil, "nil output");

    processors[id] = temp;
    taskManager.taskQueues[id] = Queue.new();
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

---@param recipeName string
---@param amount number
---@return boolean success, string|nil err
function AE69.buildTasks(recipeName, amount)
    LOGGER.debug("Building task queue");
    return pcall(buildTasks, recipeName, amount, buffer:getTotals());
end

--- Crafts a recipe
---@param recipeName string
---@param amount number
---@return boolean success, string|nil err
function AE69.craft(recipeName, amount)
    LOGGER.debug("Crafting '%s'", recipeName);
    AE69.OnCraftRoot:invoke(recipeName, amount);
    local success, err = AE69.buildTasks(recipeName, amount);
    if (success) then
        AE69.getWorkerTasksForAll();
        return true;
    end
    return false, err;
end

--- learns a recipe from the turtles inventory
---@param shaped boolean
---@param processorId string
---@return Recipe
function AE69.learn(shaped, processorId)
    local shape = nil;
    local materials = nil;
    local output = nil;

    if (shaped) then
        shape = {};
        for i = 1, 9 do
            local item = turtle.getItemDetail(toTurtleSlot(i));
            if (item ~= nil) then shape[i] = item.name; end
        end
    else
        materials = {};
        for i = 1, 15 do
            local item = turtle.getItemDetail(i);
            if (item ~= nil) then
                materials[item.name] = (materials[item.name] or 0) + item.count;
            end
        end
    end
    output = turtle.getItemDetail(16, true)
    if (output == nil) then error("no output") end

    if (shaped) then
        ---@cast shape string[]
        return Recipe.new(output.name)
            :setShape(shape)
            :setOutputAmount(output.count)
            :setProcessor(processorId);
    else
        ---@cast materials table<string, number>
        return Recipe.new(output.name)
            :setMaterials(materials)
            :setOutputAmount(output.count)
            :setProcessor(processorId);
    end
end

function AE69.queueAll(recipeList, amountList)
    local mutableTotals = buffer:getTotals()
    for index, material in pairs(recipeList) do
        local need = amountList[index];
        LOGGER.debug("[craftAll] Queueing %d %s", need, material);
        AE69.OnCraftRoot:invoke(material, need);
        buildTasks(material, need, nil, mutableTotals);
        -- local success, error = pcall(buildTaskQueue, material, need - count, nil, queueMap, mutableTotals);
        -- if (not success) then
        --     LOGGER.debug(error);
        --     return false;
        -- end
    end
end

function AE69.pollTasks()
    local recipeList = {};
    local amountList = {};

    for material, need in pairs(stockpile) do
        local stored = buffer:countName(material) + (taskManager:getInFlight(material));
        if (stored < need) then
            recipeList[#recipeList + 1] = material;
            amountList[#amountList + 1] = need - stored;
        end
    end

    AE69.queueAll(recipeList, amountList);
end

function AE69.getTaskWorkers()
    local workers = {};
    -- AE69.OnRunTasks:invoke(taskMap);
    for queueName, taskQueue in pairs(taskManager.taskQueues) do
        workers[#workers + 1] = function()
            while true do
                LOGGER.debug("Running queue '%s'", queueName);
                local task = nil;
                while true do
                    task = taskQueue:dequeue();
                    if (task ~= nil) then break end
                    sleep(1);
                end
                ---@cast task Task
                LOGGER.debug("[%s] Executing task '%s', %d", queueName, task.recipe.data.name, 1);
                if (AE69.craftSimple(task.recipe.data.name, task.amount)) then
                    taskManager:completeTask(task);
                end
            end
        end
    end

    return workers;
end

return AE69;