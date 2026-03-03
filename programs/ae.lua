local AE69 = require("lib.AE69.AE69");
local Std = require("lib.Std");
local Helper = require("lib.Helper");
local Path = require("lib.Path");
local EasyAddress = require("lib.EasyAddress");
local CMDL = require("lib.CMDL");
local Ask  = require("lib.Ask")
local Inventorio = require("lib.Inventorio")
local Identifier = require("lib.Identifier")
local Porter = AE69.Porter;
local Recipe = AE69.Recipe;

-- TODO: MONITOR DISPLAYS, MAYBE AE69 NEEDS TO ADD FUNCTIONALITY TOO IDK

local dataDirectoryPath = Path.new(Std.getAndMakeDirectory("ae69"));
local recipesFilePath = Path.join(dataDirectoryPath, "recipes.luaj");
local processorsFilePath = Path.join(dataDirectoryPath, "processors.luaj");
local stockpilesFilePath = Path.join(dataDirectoryPath, "stockpiles.luaj");
local buffersFilePath = Path.join(dataDirectoryPath, "buffers.luaj");
local importsFilePath = Path.join(dataDirectoryPath, "imports.luaj");
local exportsFilePath = Path.join(dataDirectoryPath, "exports.luaj");

local function setup()
    local recipes = AE69.Deserializers.recipes(Helper.load(recipesFilePath));
    local processors = AE69.Deserializers.processors(Helper.load(processorsFilePath));
    local stockpiles = AE69.Deserializers.stockpiles(Helper.load(stockpilesFilePath));
    local buffers = AE69.Deserializers.buffers(Helper.load(buffersFilePath));
    local importers = AE69.Deserializers.importers(Helper.load(importsFilePath));
    local exporters = AE69.Deserializers.exporters(Helper.load(exportsFilePath));

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
        for _, stockpile in pairs(stockpiles) do
            AE69.registerStock(stockpile.name, stockpile.amount);
        end
    end

    if (importers ~= nil) then
        for _, importer in ipairs(importers) do
            AE69.registerImporter(importer.data.source.peripheral.address.full, importer);
        end
    end

    if (exporters ~= nil) then
        for _, exporter in ipairs(exporters) do
            AE69.registerExporter(exporter.data.target.peripheral.address.full, exporter);
        end
    end

    print("Initializing AE69...\n");
    if (buffers == nil) then
        buffers = EasyAddress.waitList("buffer", "The AE69 buffers with all the items");
        Helper.serialize(buffersFilePath, buffers);
    end

    AE69.buffer(table.unpack(buffers));
end

local function getAnyItem(detail)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if (item ~= nil) then
            if (detail) then return turtle.getItemDetail(i, true); end
            return item;
        end
    end
end

---@param porter Porter
local function porterFilterForm(porter)
    local itemMember;
    local predicate;
    local filterType = Ask.choose("Item Filter: ", {byIndex={"By Name", "By Item Tag", "Any Item"}})
    print();
    if (filterType == 1) then
        local itemName = Ask.ask("Item Name (blank to find): ", Ask.options():allowBlank(nil));
        ---@cast itemName string
    
        if (itemName == nil) then
            local item = getAnyItem();
            if (item == nil) then
                print("Couldn't find any item...");
                return false;
            end
            itemName = item.name;
        end
    
        predicate = Porter.PredicateRegistry.ITEM_NAME:create(itemName);
        itemMember = itemName;
    elseif (filterType == 2) then
        local itemTag = Ask.ask("Item Tag (blank to find): ", Ask.options():allowBlank(nil));
        ---@cast itemTag string
    
        if (itemTag == nil) then
            local item = getAnyItem(true);
            if (item == nil) then
                print("Couldn't find any item...");
                return;
            end
            if (item.tags == nil) then
                print("Item doesn't have any item tags...");
                return false;
            end
            local _, value = Ask.choose("Item Tags: ", {byKey=item.tags})
            print();
            itemTag = value;
        end

        predicate = Porter.PredicateRegistry.ITEM_TAG:create(itemTag);
        itemMember = itemTag;
    end
    if (not Ask.ask(("Only allow items with name '%s' (y/n): "):format(itemMember), Ask.yesNo())) then return end
    porter:filter(predicate);
    return true;
end

---@param args PeekableIterator<string>
local function processorCmd(args)
    if (not args:hasNext()) then
        print("Expected: add, remove, list");
        return;
    end

    local cmd = args:next();
    if (cmd == "add") then
        local id = args:next() or Ask.ask("Choose a unique name for this processor: ");
        ---@cast id string

        local input = EasyAddress.wait(id .. " input", "The processors input inventory")
        local output = EasyAddress.wait(id .. " output", "The processors output inventory")
        AE69.registerProcessor(id, input, output);
        Helper.save(processorsFilePath, AE69.Serializers.processors());
    elseif (cmd == "remove") then
        local id = args:next() or Ask.ask("Choose the name of the processor to remove: ");
        ---@cast id string

        AE69.removeProcessor(id);
        Helper.save(processorsFilePath, AE69.Serializers.processors());
    elseif (cmd == "list") then
        local filter = args:next();
        for name, processor in pairs(AE69.getProcessors()) do
            if (filter == nil or name:find(filter)) then
                print(name);
            end
        end
    else
        print("Unknown command: " .. cmd, "Expected: add, remove, list");
    end
end

---@param args PeekableIterator<string>
local function recipeCmd(args)
    if (not args:hasNext()) then
        print("Expected: add, remove, list");
        return;
    end

    local cmd = args:next();
    if (cmd == "add") then
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
        Helper.serialize(recipesFilePath, AE69.getRecipes());
    elseif (cmd == "remove") then
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
            Helper.serialize(recipesFilePath, AE69.getRecipes());
        end

    elseif (cmd == "list") then
        local filter = args:next();
        for name, recipe in pairs(AE69.getRecipes()) do
            if (filter == nil or name:find(filter)) then
                print(name);
            end
        end
    else
        print("Unknown command '" .. cmd .. "' Expected: add, remove, list");
    end
end

---@param args PeekableIterator<string>
local function stockpileCmd(args)
    if (not args:hasNext()) then
        print("Expected: set, remove, list");
        return;
    end

    local cmd = args:next();
    if (cmd == "set") then
        -- local name = args:next();
        -- local amount = args:next();
        local name = nil;
        local amount = nil;
        if (args:hasNext()) then
            name = args:next();
            if (args:hasNext()) then
                amount = tonumber(args:next());
                if (amount == nil) then
                    print(amount .. " is not a number!");
                    return
                end
            end
        else
            local ready = Ask.ask("Put stockpile item in turtle (y/n): ", Ask.yesNo())
            if (not ready) then return end
    
            local item = getAnyItem();
    
            if (item == nil) then
                print("Couldn't find any item in the turtles inventory...");
                return;
            end

            name = item.name;
        end

        amount = amount or Ask.ask("Enter amount of '" .. name .. "' you want to stockpile: ", Ask.num(1));
        ---@cast amount number

        local confirm = Ask.ask("Stockpile " .. amount .. " '" .. name .. "'? (y/n): ", Ask.yesNo())
        if (not confirm) then return end

        AE69.registerStock(name, amount);
        Helper.save(stockpilesFilePath, AE69.Serializers.stockpiles());
    elseif (cmd == "remove") then
        local name = nil;
        if (args:hasNext()) then
            name = args:next();
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

        local confirm = Ask.ask("Remove '" .. name .. "' stockpile? (y/n): ", Ask.yesNo())
        if (not confirm) then return end

        AE69.removeStock(name);
        Helper.save(stockpilesFilePath, AE69.Serializers.stockpiles());
    elseif (cmd == "list") then
        local filter = args:next();
         for name, amount in pairs(AE69.getStockpiles()) do
            if (filter == nil or name:find(filter)) then
                print(name .. ": " .. amount);
            end
        end
    else
        print("Unknown command: " .. cmd, "Expected: set, remove, list");
    end
end

---@param args PeekableIterator<string>
local function importCmd(args)
    if (not args:hasNext()) then
        print("Expected: add, remove, list");
        return;
    end

    local cmd = args:next();
    if (cmd == "add") then
        local srcAddr = EasyAddress.wait("importer", "The inventory to import items from");
        local srcInv = peripheral.wrap(srcAddr);
        local importer = Porter.Importer.new();
        if (not porterFilterForm(importer)) then return end

        local keep = Ask.ask("Keep in inventory (blank for none): ", Ask.num(0):allowBlank(0))
        importer:keep(keep);
        local slot = Ask.ask("Source slot (blank for any): ", Ask.num(1, srcInv.size()):allowBlank());
        importer:slot(slot)

        AE69.registerImporter(srcAddr, importer);
        Helper.save(importsFilePath, AE69.Serializers.importers());
    elseif (cmd == "remove") then
        AE69.pause(true);
        local importers = AE69.getImporters();
        local addr = EasyAddress.wait("importer to remove", "The importer to remove");
        if (importers[addr] == nil) then 
            print("That's not an importer...");
            AE69.pause()
            return
        end
        
        print("Found valid importer: " .. addr);
        print("Item Filter: " .. importers[addr].data.itemFilter.args[1]);
        
        if (not Ask.ask("Sure? (y/n): ", Ask.yesNo())) then return end
        AE69.removeImporter(addr);
        Helper.save(importsFilePath, AE69.Serializers.importers());
        AE69.pause();
    elseif (cmd == "list") then
        for addr, importer in pairs(AE69.getImporters()) do
            print(addr .. " (".. Identifier.getPrettyPath(importer.data.itemFilter.args[1]) ..")");
        end
    else
        print("Unknown command: " .. cmd, "Expected: add, remove, list");
    end
end

---@param args PeekableIterator<string>
local function exportCmd(args)
    if (not args:hasNext()) then
        print("Expected: add, remove, list");
        return;
    end

    AE69.pause();

    local cmd = args:next();
    if (cmd == "add") then
        local dstAddr = EasyAddress.wait("exporter", "The inventory to export items to");
        local dstInv = peripheral.wrap(dstAddr);
        local exporter = Porter.Exporter.new();
        if (not porterFilterForm(exporter)) then return end

        local stock = Ask.ask("Export stock amount (blank for infinite): ", Ask.num(1):allowBlank(math.huge))
        exporter:stock(stock);
        local keep = Ask.ask("Keep in network (blank for none): ", Ask.num(0):allowBlank())
        exporter:keep(keep);
        local slot = Ask.ask("Output slot (blank for any): ", Ask.num(1, dstInv.size()):allowBlank());
        exporter:slot(slot)

        AE69.registerExporter(dstAddr, exporter);
        Helper.save(exportsFilePath, AE69.Serializers.exporters());
    elseif (cmd == "remove") then
        AE69.pause(true);
        local exporters = AE69.getExporters();
        local addr = EasyAddress.wait("exporter to remove", "The exporter to remove");
        if (exporters[addr] == nil) then
            print("That's not an exporter...");
            AE69.pause()
            return
        end
        
        print("Found valid Exporter: " .. addr);
        print("Item Filter: " .. exporters[addr].data.itemFilter.args[1]);
        
        if (not Ask.ask("Confirm (y/n): ", Ask.yesNo())) then return end
        AE69.removeExporter(addr);
        Helper.save(exportsFilePath, AE69.Serializers.exporters());
        AE69.pause();
    elseif (cmd == "list") then
        for addr, exporter in pairs(AE69.getExporters()) do
            local prettyAddr = Identifier.getPrettyPath(addr);
            local prettyItem = Identifier.getPrettyPath(exporter.data.itemFilter.args[1]);
            print(prettyAddr .. " (".. prettyItem ..")");
        end
    else
        print("Unknown command: " .. cmd, "Expected: add, remove, list");
    end
end

setup();
local CMDI = CMDL.new();

CMDI:command("processor", "modify processors", processorCmd);
CMDI:command("recipe", "modify recipes", recipeCmd);
CMDI:command("craft", "craft items", stockpileCmd);
CMDI:command("stockpile", "modify stockpile data", stockpileCmd);
CMDI:command("import", "import items from a specific inventory", importCmd);
CMDI:command("export", "export items to a specific inventory", exportCmd);
--- TODO: implement below
CMDI:command("cancraft", "check if you can craft a recipe", exportCmd);
CMDI:command("materials", "get needed materials for recipe", exportCmd);
CMDI:command("total", "get total items in buffer", exportCmd);

local function commandThread()
    term.clear();
    term.setCursorPos(1, 1);
    CMDI:help();
    while true do
        write("Enter a command: ");
        CMDI:run(read(nil, CMDI:getHistory()));
    end
end

local function pollThread()
    while true do
        AE69.pollTasks()
        sleep(1);
    end
end

local function taskThread()
    local allWorkers = {};

    local craftWorkers = AE69.getTaskWorkers();
    local porterWorkers = AE69.getPorterWorkers();

    for index, worker in ipairs(craftWorkers) do
        table.insert(allWorkers, worker);
    end

    for index, worker in ipairs(porterWorkers) do
        table.insert(allWorkers, worker);
    end

    parallel.waitForAll(table.unpack(allWorkers));
end

local function onCraftRoot(name, count)
    print("Queueing " .. count .. " " .. name .. " to be crafted...");
end

AE69.OnCraftRoot:listen(onCraftRoot);


parallel.waitForAny(commandThread, pollThread, taskThread);