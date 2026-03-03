local Tubby = require("lib.Tubby");
local Sides = require("lib.Sides");
local Std = require("lib.Std");

local arg = ...;

local homeMarker = nil;
local goHomeMarker = nil;
local leftMarker = nil;
local rightMarker = nil;

local saplingsTag = "minecraft:saplings";
local logsTag = "minecraft:logs";

local stats = {
    lifetime = 0,
    logs = 0,
    moves = 0,
    replants = 0,
}

local Actions = {}
Actions.END = 1;
Actions.GO_HOME = 2;
Actions.TURN_LEFT = 3;
Actions.TURN_RIGHT = 4;

local function equals(blocka, blockb)
    if (blocka == blockb) then return true; end
    if ((blocka == nil) ~= (blockb == nil)) then return false; end
    if (blocka.name ~= blockb.name) then return false; end
    local astate = blocka.state;
    local bstate = blockb.state;

    for k, v in pairs(astate) do
        if (bstate[k] ~= v) then return false; end
    end

    return true;
end

local function hasTag(obj, tag)
    return obj ~= nil and obj.tags[tag] ~= nil;
end

local function placeSapling()
    local slot = Tubby.findItemTag(saplingsTag);
    if (slot == -1) then return false; end
    local originalSlot = turtle.getSelectedSlot();
    turtle.select(slot);
    turtle.placeDown();
    turtle.select(originalSlot);
end

local function getAction()
    local block = Tubby.inspect(Sides.DOWN);

    if (equals(block, goHomeMarker)) then
        return Actions.GO_HOME;
    elseif (equals(block, leftMarker)) then
        return Actions.TURN_LEFT;
    elseif (equals(block, rightMarker)) then
        return Actions.TURN_RIGHT;
    elseif (equals(block, homeMarker)) then
        return Actions.END;
    end

    return nil;
end

local function timber()
    Tubby.moveMine()
    Tubby.mine(Sides.DOWN);

    local failed = 0;
    local moves = 0;
    while moves < 32 do
        local block = Tubby.inspect(Sides.UP);
        if (not hasTag(block, logsTag)) then failed = failed + 1; end
        if (failed == 2) then break end
        Tubby.moveMine(Sides.UP);
        moves = moves + 1;
    end

    for i = 1, moves do
        Tubby.moveMine(Sides.DOWN);
    end

    return moves - failed - 1, placeSapling();
end

local function getSerializableBlock(block)
    return {
        name=block.name,
        state=block.state,
    }
end

local function setup()
    local saveDirectory = Std.getAndMakeDirectory("autochopper");
    local saveFile = saveDirectory .. "/" .. "markers.json"

    if (arg == "--reset") then fs.delete(saveFile); end

    if (fs.exists(saveFile)) then
        local f = fs.open(saveFile, "r");
        local data = textutils.unserialise(f.readAll());
        f.close();
        
        homeMarker = data.homeMarker;
        goHomeMarker = data.goHomeMarker;
        leftMarker = data.leftMarker;
        rightMarker = data.rightMarker;

        return;
    end

    homeMarker = Tubby.inspect(Sides.DOWN);
    turtle.back();
    goHomeMarker = Tubby.inspect(Sides.DOWN);
    turtle.back();
    leftMarker = Tubby.inspect(Sides.DOWN);
    turtle.back();
    rightMarker = Tubby.inspect(Sides.DOWN);

    local json = textutils.serialise({
        homeMarker=getSerializableBlock(homeMarker),
        goHomeMarker=getSerializableBlock(goHomeMarker),
        leftMarker=getSerializableBlock(leftMarker),
        rightMarker=getSerializableBlock(rightMarker)
    });

    local f = fs.open(saveFile, "w");
    f.write(json);
    f.close();

    turtle.forward();
    turtle.forward();
    turtle.forward();
end

local function hasEnoughFuel(distance)
    return turtle.getFuelLevel() > distance;
end

local function refuel()
    local slot = Tubby.findItemName("minecraft:charcoal");
    if (slot == -1) then return false; end
    Tubby.tempSelect(slot);
    local success = turtle.refuel(64);
    Tubby.tempSelect()
    return success;
end

local function saveStats()

end

local function main()
    while true do
        local homeMode = false;
        
        local tempStats = {
            moves = 0,
            logCount = 0,
            replants = 0,
            startTime = os.clock()
        }

        while true do
            if (not hasEnoughFuel(tempStats.moves) and not refuel()) then
                homeMode = true;
                turtle.turnRight();
                turtle.turnRight();
            end

            local action = getAction();
            if (action == Actions.TURN_LEFT) then
                if (homeMode) then
                    turtle.turnRight();
                else
                    turtle.turnLeft();
                end
            elseif (action == Actions.TURN_RIGHT) then
                if (homeMode) then
                    turtle.turnLeft();
                else
                    turtle.turnRight();
                end
            elseif (action == Actions.GO_HOME) then
                homeMode = true;
                turtle.turnRight();
                turtle.turnRight();
            elseif (action == Actions.END) then
                if (homeMode or tempStats.moves ~= 0) then
                    turtle.turnRight();
                    turtle.turnRight();
                    Tubby.dropCB(Sides.DOWN, function(item) return item.name ~= "minecraft:charcoal" and not hasTag(item, saplingsTag) end);
                    Tubby.compactv2();
                    break;
                end
            end

            local block = Tubby.inspect(Sides.FORWARD);
            if (block ~= nil) then
                if (hasTag(block, logsTag)) then 
                    local logsCut, replanted = timber();
                    tempStats.logCount = tempStats.logCount + logsCut;
                    tempStats.replants = tempStats.replants + ((replanted and 1) or (replanted or 0));
                else turtle.dig(); end
            end
            turtle.forward();
            if (not homeMode) then
                tempStats.moves = tempStats.moves + 1;
            end
        end

        local time = os.clock() - tempStats.startTime;
        term.clear();
        term.setCursorPos(1, 1);
        print(("Hey I got %s logs during that run. Cool right?"):format(tempStats.logCount))
        print(("It also took me %.2f seconds to get them, that's %.2f per second! Cool right?"):format(time, tempStats.logCount / time));
        print(("I also travelled %d blocks, without me coming back home :)"):format(tempStats.moves));
        print("I'm gonna go to sleep now for 3 minutes. Nap time!")
        
        stats.lifetime = stats.lifetime + time;
        stats.logs = stats.logs + tempStats.logCount;
        stats.moves = stats.moves + tempStats.moves;
        stats.replants = stats.replants + tempStats.replants;

        saveStats();

        for i = 1, 180 do
            term.write("z")
            if (i % 4 == 0) then
                term.clearLine();
                local _, y = term.getCursorPos();
                term.setCursorPos(1, y);
            end

            sleep(1);
        end
    end
end

setup();
main();