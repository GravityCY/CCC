local Tubby = {};

local Sides = {};
Sides.FORWARD = 1;
Sides.RIGHT = 2;
Sides.BACK = 3;
Sides.LEFT = 4;
Sides.UP = 5;
Sides.DOWN = 6;

Tubby.Sides = Sides;

local sideToStrMap = {}
sideToStrMap[Sides.FORWARD] = ""
sideToStrMap[Sides.RIGHT] = "Right"
sideToStrMap[Sides.BACK] = nil
sideToStrMap[Sides.LEFT] = "Left"
sideToStrMap[Sides.UP] = "Up"
sideToStrMap[Sides.DOWN] = "Down"

local Actions = {}
Actions.INSPECT = 1;
Actions.DROP = 2;

local actionsToStrMap = {}
actionsToStrMap[Actions.INSPECT] = "inspect";
actionsToStrMap[Actions.DROP] = "drop";

local function action(actionId, side, ...)
    local actionStr = actionsToStrMap[actionId];
    local sideStr = sideToStrMap[side];
    
    if (actionStr == nil) then return "no such action" end
    if (sideStr == nil) then return "no such side" end

    local fn = turtle[actionStr..sideStr]
    if (fn == nil) then return "no such fn"; end
    return fn(...);
end

function Tubby.inspect(side)
    local exists, block = action(Actions.INSPECT, side);
    if (exists) then return block; end
    return nil; 
end

function Tubby.tempSelect(slot)
    if (prevSlot ~= nil) then
        turtle.select(prevSlot);
        prevSlot = nil;
        return;
    end
    
    prevSlot = turtle.getSelectedSlot();
    if (slot ~= nil) then turtle.select(slot); end
end

function Tubby.select(slot)
    local old = turtle.getSelectedSlot();
    turtle.select(slot);
    return old;
end

function Tubby.hasBlockTag(str, side)
    local block = Tubby.inspect(side);
    if (block == nil) then return false; end
    return block.tags[str];
end

function Tubby.findItemPredicate(predicate)
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if (item ~= nil) then
            item = turtle.getItemDetail(i, true);
            if (predicate(item)) then return i; end
        end
    end

    return -1;
end

function Tubby.findItemByName(name)
    return Tubby.findItemPredicate(
        function(item)
            return item.name == name;
        end
    )
end

function Tubby.findItemByTag(tag)
    return Tubby.findItemPredicate(
        function(item)
            return item.tags[tag] ~= nil
        end
    )
end

function Tubby.dropAll(side, whitelistPredicate)
    Tubby.tempSelect();
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if (item ~= nil) then
            item = turtle.getItemDetail(i, true);
            if (whitelistPredicate == nil or whitelistPredicate(item)) then
                turtle.select(i);
                action(Actions.DROP, side, 64);
            end
        end
    end
    Tubby.tempSelect();
end

function Tubby.compact()
    local empty = nil;
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if (empty == nil and item == nil) then
            empty = i;
        elseif (item ~= nil) then
            if (empty ~= nil) then
                turtle.select(i);
                turtle.transferTo(empty)
                empty = empty + 1;
            end
        end
    end
end

function Tubby.compactv2()
    local min = 1;
    for i = 16, 1, -1 do
        local item = turtle.getItemDetail(i);
        if (item ~= nil) then
            for j = min, i do
                item = turtle.getItemDetail(j);
                if (item == nil) then
                    turtle.select(i);
                    turtle.transferTo(j);
                    min = j + 1;
                    if (min > i) then return end
                    break;
                end
            end
        end
    end
end

return Tubby;