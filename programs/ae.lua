local AE69 = require("lib.AE69");
local Std = require("lib.Std");
local Helper = require("lib.Helper");
local Path = require("lib.Path");
local EasyAddress = require("lib.EasyAddress");
local CMDL = require("lib.CMDL");
local Ask  = require("lib.Ask")
local Recipe = AE69.Recipe;

local dataDirectoryPath = Path.new(Std.getAndMakeDirectory("ae69"));
local recipesFilePath = Path.join(dataDirectoryPath, "recipes.luaj");
local processorsFilePath = Path.join(dataDirectoryPath, "processors.luaj");
local stockpilesFilePath = Path.join(dataDirectoryPath, "stockpiles.luaj");
local buffersFilePath = Path.join(dataDirectoryPath, "buffers.luaj");

local function setup()
    local recipes = Helper.load(recipesFilePath);
    local processors = Helper.load(processorsFilePath);
    local stockpiles = Helper.load(stockpilesFilePath);
    local buffers = Helper.load(buffersFilePath);

    if (recipes ~= nil) then
        print("Loading recipe definitions...");
        for _, recipe in pairs(recipes) do
            AE69.registerRecipes(recipe);
        end
    end

    if (processors ~= nil) then
        print("Loading processor definitions...");
        for _, processor in ipairs(processors) do
            AE69.registerProcessor(processor.id, processor.input, processor.output);
        end
    end

    if (stockpiles ~= nil) then
        print("Loading stockpile definitions...");
        for recipeName, amount in pairs(stockpiles) do
            AE69.registerStock(recipeName, amount);
        end
    end

    print("Initializing AE69...\n");
    if (buffers == nil) then
        buffers = {};
        buffers[1] = EasyAddress.wait("buffer", "The AE69 buffer with all the items");
        Helper.save(buffersFilePath, buffers);
    end

    AE69.init(buffers[1]);
end

local function onCraftRoot(name, count)
    print("Queueing " .. count .. " " .. name .. " to be crafted...");
end

AE69.OnCraftRoot:listen(onCraftRoot);

local function getAnyItem()
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if (item ~= nil) then return item end
    end
end

local function processorCmd(args)
    if (args[1] == "add") then
        local id = args[2] or Ask.ask("Choose a unique name for this processor: ");
        ---@cast id string

        local input = EasyAddress.wait(id .. " input", "The processors input inventory")
        local output = EasyAddress.wait(id .. " output", "The processors output inventory")
        AE69.registerProcessor(id, input, output);
        Helper.save(processorsFilePath, AE69.getProcessors());
    elseif (args[1] == "remove") then
        local id = args[2] or Ask.ask("Choose the name of the processor to remove: ");
        ---@cast id string

        AE69.removeProcessor(id);
        Helper.save(processorsFilePath, AE69.getProcessors());
    end
end

local function recipeCmd(args)
    if (args[1] == "add") then
        local ready = Ask.ask("Input stuff in the turtle and please type (y/n) when done:", Ask.yesNo())
        if (not ready) then return end

        local isShaped = Ask.ask("Is this ready a shaped recipe or shapeless (y/n): ", Ask.yesNo());
        ---@cast isShaped boolean
        local processorId = nil;

        if (not isShaped) then
            processorId = Ask.ask("Enter the name of the processor this should go to: ");
            ---@cast processorId string
        end

        local item = turtle.getItemDetail(16);
        if (item == nil) then
            print("No output item in slot 16 (bottom right)! Put the the result of the recipe in this slot, with the exact amount the recipe outputs!");
            return
        end

        local recipe = AE69.learn(isShaped, processorId);

        print("name:", recipe.data.name);
        print("output amount:", recipe.data.outputAmount);
        print("processor:",  recipe.data.processorId);

        local confirm = Ask.ask("Do you want to save this recipe? (y/n): ", Ask.yesNo());
        if (not confirm) then return end

        AE69.registerRecipes(recipe);
        Helper.save(recipesFilePath, AE69.getRecipes());
    elseif (args[1] == "remove") then
        if (args[2] == nil) then
            local item = nil;
            for i = 1, 16 do
                item = turtle.getItemDetail(i);
                if (item ~= nil) then break end
            end

            if (item == nil) then
                print("Couldn't find any item in the turtles inventory...");
                return;
            end

            AE69.removeRecipe(item.name);
            Helper.save(recipesFilePath, AE69.getRecipes());
        end

    else
        print("expected 'add' or 'remove'");
    end
end

local function stockpileCmd(args)
    if (args[1] == "set") then
        local name = args[2];
        local amount = args[3];

        if (name ~= nil) then
            if (amount ~= nil) then
                amount = tonumber(amount);
            end
        else
            local ready = Ask.ask("Input the item you want to stockpile in the turtle (y/n)", Ask.yesNo())
            if (not ready) then return end
    
            local item = getAnyItem();
    
            if (item == nil) then
                print("Couldn't find any item in the turtles inventory...");
                return;
            end

            name = item.name;
        end
        amount = amount or Ask.ask("Enter the amount of " .. name .. " you want to stockpile: ", Ask.num(1));

        local confirm = Ask.ask("Are you sure you want to stockpile " .. amount .. " " .. name .. " (y/n): ", Ask.yesNo())
        if (not confirm) then return end

        AE69.registerStock(name, amount);
        Helper.save(stockpilesFilePath, AE69.getStockpiles());
    elseif (args[1] == "remove") then
        if (args[2] ~= nil) then
            name = args[2];
        else
            local ready = Ask.ask("Input the item you want to stockpile in the turtle (y/n)", Ask.yesNo())
            if (not ready) then return end
    
            local item = getAnyItem();
    
            if (item == nil) then
                print("Couldn't find any item in the turtles inventory...");
                return;
            end

            name = item.name;
        end

        local confirm = Ask.ask("Are you sure you want to remove the stockpile for " .. name .. " (y/n): ", Ask.yesNo())
        if (not confirm) then return end

        AE69.removeStock(name);
        Helper.save(stockpilesFilePath, AE69.getStockpiles());
    else
        print("expected 'add' or 'remove'");
    end
end

setup();
local CMDI = CMDL.new();

CMDI:command("processor", "modify processors", processorCmd);
CMDI:command("recipe", "modify recipes", recipeCmd);
CMDI:command("stockpile", "modify stockpile data", stockpileCmd);

local function commandThread()
    while true do
        CMDI:run(read());
    end
end


local function pollThread()
    while true do
        AE69.poll()
        sleep(1);
    end
end


parallel.waitForAll(commandThread, pollThread);