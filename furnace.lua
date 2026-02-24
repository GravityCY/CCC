local EASY = require("EasyAddress");
local Peripheral = require("Peripheral")
local Inventorio = require("Inventorio");

local translations = EASY.load("smelter");
local first = translations.fuel == nil;

translations.fuel = translations.fuel or EASY.wait("fuel", "The fuel inventory")
translations.input = translations.input or EASY.wait("input", "The input inventory")
translations.output = translations.output or EASY.wait("output", "The output inventory")

if (first) then
    EASY.save("smelter", translations)
end

local furnaces = Peripheral.find("minecraft:furnace");
for i, v in ipairs(furnaces) do
    furnaces[i] = Inventorio.new(v);
end

---@cast furnaces Inventorio[]

local fuel = Inventorio.new(translations.fuel);
local input = Inventorio.new(translations.input);
local output = Inventorio.new(translations.output);
if (fuel == nil) then error("No fuel storage") end
if (input == nil) then error("No input storage") end
if (output == nil) then error("No output storage") end

while true do
    local itemName, itemCount = next(input:getTotals())
    if (itemName ~= nil and itemCount ~= nil) then
        local realItemCount = math.min(itemCount, #furnaces * 64);

        local fuelName, storedFuel = next(fuel:getTotals());
        if (fuelName ~= nil and storedFuel >= #furnaces) then
            local smeltableTotal = storedFuel * 8;
            local itemSplit = nil;
            local fuelSplit = nil;
            if (smeltableTotal < realItemCount) then
                itemSplit = math.ceil(smeltableTotal / #furnaces);
                fuelSplit = math.ceil(storedFuel / #furnaces);
            else
                local requiredFuel = math.ceil(realItemCount / 8);
                itemSplit = math.ceil(realItemCount / #furnaces);
                fuelSplit = math.ceil(requiredFuel / #furnaces);
            end

            for _, furnace in ipairs(furnaces) do
                furnace:push(output, 3, nil, 64);
            end

            for _, furnace in ipairs(furnaces) do
                input:pushName(furnace, itemName, itemSplit, 1);
                fuel:pushName(furnace, fuelName, fuelSplit, 2)
            end

            print("sleeping for " .. itemSplit * 10 .. " seconds till things are smelted...");
            sleep(itemSplit * 10);
            
            for _, furnace in ipairs(furnaces) do
                furnace:push(output, 3, nil, 64);
            end
        else
            print("Need at least", #furnaces, " fuel to smelt ", itemCount);
        end
    end
end