local EASY = require("lib.EasyAddress");
local Peripheral = require("lib.Peripheral")
local Inventorio = require("lib.Inventorio");

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

--- TODO: ROUND ROBIN MODE COMPARED TO JUST SYMMETRICAL SPLIT MODE

while true do
    local itemName, itemCount = next(input:getTotals())
    local furnaceCount = #furnaces;
    if (itemName ~= nil and itemCount ~= nil) then
        local realItemCount = math.min(itemCount, furnaceCount * 64);

        local fuelName, storedFuel = next(fuel:getTotals());
        if (fuelName ~= nil and storedFuel >= furnaceCount) then
            local canSmeltAmount = storedFuel * 8;
            local itemSplit = nil;
            local fuelSplit = nil;
            if (canSmeltAmount < realItemCount) then
                itemSplit = math.ceil(canSmeltAmount / furnaceCount);
                fuelSplit = math.ceil(storedFuel / furnaceCount);
            else
                itemSplit = math.ceil(realItemCount / furnaceCount);
                fuelSplit = math.ceil(itemSplit / 8);
            end

            for _, furnace in ipairs(furnaces) do
                furnace:push(output, 3, nil, 64);
            end

            for _, furnace in ipairs(furnaces) do
                input:pushName(furnace, itemName, itemSplit, 1, true);
                fuel:pushName(furnace, fuelName, fuelSplit, 2, true)
            end

            print("sleeping for " .. itemSplit * 10 .. " seconds till things are smelted...");
            sleep(itemSplit * 10);
            
            for _, furnace in ipairs(furnaces) do
                furnace:push(output, 3, nil, 64);
                furnace:push(fuel, 2, nil, 64);
            end
        else
            print("Need at least", furnaceCount, " fuel to smelt ", itemCount);
        end
    end
end