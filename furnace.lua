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

while true do
    local itemName, itemCount = next(input:getTotals())
    if (itemName ~= nil) then
        local itemSplit = itemCount / #furnaces;
        local requiredFuel = math.ceil(itemCount / 8);
        local fuelSplit = math.ceil(requiredFuel / #furnaces);

        for _, furnace in ipairs(furnaces) do
            furnace:push(output, 3, nil, 64);
        end

        local fuelName, storedFuel = next(fuel:getTotals());
        if (fuelName ~= nil and storedFuel >= requiredFuel) then
            for _, furnace in ipairs(furnaces) do
                input:pushName(furnace, itemName, itemSplit, 1);
                fuel:pushName(furnace, fuelName, fuelSplit, 2)
            end
        end

        print("sleeping for " .. itemSplit * 10 .. " seconds till things are smelted...");
        sleep(itemSplit * 10);
        
        for _, furnace in ipairs(furnaces) do
            furnace:push(output, 3, nil, 64);
        end
    end
end