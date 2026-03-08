local EasyAddress = require("lib.EasyAddress");
local Inventorio  = require("lib.Inventorio")

local ADR = EasyAddress.new("soulguy");

local core = peripheral.find("automata");

local input = Inventorio.new(ADR.get("input", true));
local output = Inventorio.new(ADR.get("output", true));
local modem = peripheral.find("modem");
if (input == nil or output == nil) then error("no inventories") end
local localName = modem.getNameLocal();
if (localName == nil or localName == "") then error("turtle not connected..."); end

local function ensure()
    local cooldown = core.getCooldown("use");
    if (cooldown ~= 0) then
        local seconds = (cooldown + 50) / 1000;
        sleep(seconds);
    end
    core.use("block");
end

local function craft()
    if (input:countName("minecraft:soul_sand") < 4) then return false; end
    if (input:countName("turtlematic:soul_vial") < 1) then return false; end;
    input:pushName(localName, "minecraft:soul_sand", 4);
    input:pushName(localName, "turtlematic:soul_vial", 1);
    for i = 1, 4 do
        turtle.select(1);
        turtle.place();
        turtle.select(2);
        ensure();
        turtle.dig();
    end
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot);
        if (item ~= nil) then
            output:pull(localName, slot);
        end
    end
end

while true do
    if (not craft()) then
        sleep(5);
    end
end



