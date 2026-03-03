--- Title: TurtyBoy
--- Description: A library for working with turtles.
--- Version: 0.4.1

---@diagnostic disable: redundant-parameter

local Helper = require("lib.Helper");
local Sides = require("lib.Sides"); 
local Inventorio = require("lib.Inventorio")
local Peripheral = require("lib.Peripheral")

local _def = Helper._def;
local _if = Helper._if;

local facing = Sides.FORWARD;
local pos = vector.new(0, 0, 0);
local prevSlot = nil;

local Tubby = {};
Tubby.doBlacklist = true;

Errors = {
    DIG_IN_BLACKLIST="Trying to mine a block in the blacklist",

    DIG_UNBREAKABLE="Cannot break unbreakable block",
    DIG_TOOL="Cannot break block with this tool",
    PLACE_BLOCK="Cannot place block here",
    PLACE_PROTECTED="Cannot place in protected area",
    PLACE_ITEM="Cannot place item here",
    MOVE_OBSTRUCTED="Movement obstructed",
    MOVE_NO_FUEL="Out of fuel",
    MOVE_FAILED="Movement failed",
    MOVE_WORLD="Cannot leave the world",
    MOVE_PROTECTED="Cannot enter protected area",
    MOVE_LOADED_WORLD="Cannot leave loaded world",
    MOVE_WORLD_BORDER="Cannot pass the world border",
}

Tubby.Errors = Errors;

local Actions = {
    MOVE=0, MINE=1, PLACE=2, ATTACK=3, TURN=4, SUCK=5, DROP=6, INSPECT=7, COMPARE=8, length=9,
    "MOVE", "MINE", "PLACE", "ATTACK", "TURN", "SUCK", "DROP", "INSPECT", "COMPARE"
};

local baseActions = {
    [Actions.MOVE] = {
        [Sides.FORWARD] = turtle.forward,
        [Sides.BACK] = turtle.back,
        [Sides.UP] = turtle.up,
        [Sides.DOWN] = turtle.down
    },
    [Actions.MINE] = {
        [Sides.FORWARD] = turtle.dig,
        [Sides.UP] = turtle.digUp,
        [Sides.DOWN] = turtle.digDown,
    },
    [Actions.PLACE] = {
        [Sides.FORWARD] = turtle.place,
        [Sides.UP] = turtle.placeUp,
        [Sides.DOWN] = turtle.placeDown,
    },
    [Actions.ATTACK] = {
        [Sides.FORWARD] = turtle.attack,
        [Sides.UP] = turtle.attackUp,
        [Sides.DOWN] = turtle.attackDown,
    },
    [Actions.TURN] = {
        [Sides.RIGHT] = turtle.turnRight,
        [Sides.LEFT] = turtle.turnLeft,
        [Sides.BACK] = function() for i = 1, 2 do turtle.turnRight(); end end
    },
    [Actions.SUCK] = {
        [Sides.FORWARD] = turtle.suck,
        [Sides.UP] = turtle.suckUp,
        [Sides.DOWN] = turtle.suckDown,
    },
    [Actions.DROP] = {
        [Sides.FORWARD] = turtle.drop,
        [Sides.UP] = turtle.dropUp,
        [Sides.DOWN] = turtle.dropDown,
    },
    [Actions.INSPECT] = {
        [Sides.FORWARD] = turtle.inspect,
        [Sides.UP] = turtle.inspectUp,
        [Sides.DOWN] = turtle.inspectDown,
    },
    [Actions.COMPARE] = {
        [Sides.FORWARD] = turtle.compare,
        [Sides.UP] = turtle.compareUp,
        [Sides.DOWN] = turtle.compareDown
    }
}

local blacklist = {
    ["computercraft:turtle_normal"] = true,
}

--- <b>Converts a side to a peripheral</b>
---@param side integer Side Enum
---@return table|nil peripheral Peripheral Object
local function toPeripheral(side)
    local address = Sides.toPeripheralName(side);
    return peripheral.wrap(address);
end

local function itemDiffer(item1, item2)
    local anyNil = item1 == nil or item2 == nil;
    local areSame = item1 == item2;
    if (anyNil) then
        if (not areSame) then
            return true;
        end
    elseif ((item1.name ~= item2.name) or (item1.count ~= item2.count)) then
        return true;
    end
    return false;
end

local function itemValidator(item)
    return item ~= nil;
end

local function diff(fromItems, toItems)
    local ret = {
        itemDiff = {},
        sizeDiff = 0,
        different = false
    };

    local size1 = 0;
    local size2 = 0;

    for i = 1, 16 do
        if (fromItems[i] ~= nil) then size1 = size1 + 1; end
        if (toItems[i] ~= nil) then size2 = size2 + 1; end
        
        if (itemDiffer(fromItems[i], toItems[i])) then
            table.insert(ret.itemDiff, {index=i, from=fromItems[i], to=toItems[i]});
        end
    end

    ret.sizeDiff = size2 - size1;
    ret.different = ret.sizeDiff ~= 0 and #ret.itemDiff ~= 0;
    return ret;
end

function Tubby.getInventoryEvent()
    local previousState = Tubby.list();
    ---@diagnostic disable-next-line: undefined-field
    os.pullEvent("turtle_inventory");
    local newState = Tubby.list();
    return diff(previousState, newState);
end

--- <b>Executes an action</b>
---@param action integer Action Enum
---@param side integer|nil Side Enum
---@param ... any Arguments
---@return any
function Tubby.act(action, side, ...)
    side = _def(side, Sides.FORWARD);

    local fn = baseActions[action][side];
    if (fn == nil) then return end
    return fn(...);
end

--- <b>Moves the turtle</b>
---@param side number|nil
---@return boolean success Whether the turtle could successfully move.
---@return string|nil error The reason the turtle could not move.
function Tubby.move(side)
    side = side or Sides.FORWARD;

    local success, message = Tubby.act(Actions.MOVE, side);
    if (not success) then return success, message; end
    local facingVec = Sides.toVector(facing);

    if (Sides.isHorizontal(side)) then
        local scale = _if(side == Sides.FORWARD, 1, -1);
        pos.x = pos.x + facingVec.x * scale;
        pos.y = pos.y + facingVec.y * scale;
        pos.z = pos.z + facingVec.z * scale;
    else
        local sideVec = Sides.toVector(side);
        pos.y = pos.y + sideVec.y;
    end
    return success, message;
end

--- <b>Ensures a Move, by digging out an obstacle</b> <br>
--- Tries to move and if it can't, will mine the obstacle, and repeats...
---@param side number|nil
function Tubby.moveMine(side)
    while true do
        local block = Tubby.inspect(side);
        if (block ~= nil) then
            local success, error = Tubby.mine(side);
            if (not success and error == Errors.DIG_IN_BLACKLIST or error == Errors.DIG_UNBREAKABLE) then
                return false, error;
            end
        end
        if (Tubby.move(side)) then break; end
    end
    return true;
end

--- <b>Mines a block</b>
---@param side integer|nil
---@return boolean dug Whether a block was broken.
---@return string|nil error The reason no block was broken.
function Tubby.mine(side)
    if (Tubby.doBlacklist) then
        local block = Tubby.inspect(side);
        if (block ~= nil and blacklist[block.name] ~= nil) then return false, Errors.DIG_IN_BLACKLIST; end
    end
    return Tubby.act(Actions.MINE, side);
end

--- <b>Places an item</b>
---@param slot integer|nil Slot
---@param side integer Side Enum
---@return any
function Tubby.place(side, slot)
    side = side or Sides.FORWARD;
    
    if (slot ~= nil) then turtle.select(slot); end
    return Tubby.act(Actions.PLACE, side);
end

--- <b>Attacks an entity</b>
---@param side integer Side Enum
---@return any
function Tubby.attack(side)
    return Tubby.act(Actions.ATTACK, side);
end

--- <b>Turns the turtle</b>
---@param side integer Side Enum
---@return any
function Tubby.turn(side)
    side = _def(side, Sides.RIGHT);

    local offset = _if(side == Sides.RIGHT, 1, -1);
    facing = Sides.rotateUp(facing, offset);

    return Tubby.act(Actions.TURN, side);
end

--- <b>Faces the turtle</b>
---@param preferred integer Side Enum
function Tubby.face(preferred)
    if (preferred == facing) then return; end
    local distance = Sides.getDistance(preferred, facing);
    local turnSide = _if(distance < 0, Sides.RIGHT, Sides.LEFT);
    local turnCount = math.abs(distance);

    for i = 1, turnCount do Tubby.turn(turnSide); end
    facing = preferred;
end

--- <b>Moves the turtle to the specified position</b>
---@param x integer
---@param y integer
---@param z integer
---@return boolean
function Tubby.gotoPos(x, y, z, moveFn)
    if (pos.x == x and pos.y == y and pos.z == z) then
        return true;
    end

    local dx = x - pos.x;
    local dy = y - pos.y;
    local dz = z - pos.z;

    return Tubby.go(dx, dy, dz, moveFn, Tubby.face);
end

function Tubby.go(x, y, z, moveFn, turnFn)
    if (x == 0 and y == 0 and z == 0) then return true; end

    moveFn = _def(moveFn, Tubby.move);
    turnFn = _def(turnFn, Tubby.turn);

    local to = vector.new(x, y, z);

    local ax = math.abs(x);
    local ay = math.abs(y);
    local az = math.abs(z);

    local xDir = _if(x > 0, Sides.RIGHT, Sides.LEFT);
    local yDir = _if(y > 0, Sides.UP, Sides.DOWN);
    local zDir = _if(z > 0, Sides.FORWARD, Sides.BACK);

    -- Forward
    if (az ~= 0) then
        turnFn(zDir);
        Helper.rep(az, moveFn, Sides.FORWARD);
    end

    -- Right
    if (ax ~= 0) then
        turnFn(xDir);
        Helper.rep(ax, moveFn, Sides.FORWARD);
    end

    -- Up
    if (ay ~= 0) then
        Helper.rep(ay, moveFn, yDir);
    end

    return pos:equals(to);
end

--- <b> Sucks the first item in an inventory </b> <br>
--- @param side integer
--- @return any
function Tubby.suck(side, count)
    return Tubby.act(Actions.SUCK, side, count);
end

function Tubby.suckName(side, name, count)
    return Tubby.suckCb(side, count, function(item, slot) return item.name == name end);
end

function Tubby.suckCb(side, count, cb)
    local p = Inventorio.new(Sides.toPeripheralName(side));
    if (p == nil) then return 0; end
    local need = count;

    local tempSlot = p:findEmpty(true);
    if (tempSlot ~= nil) then p:swap(tempSlot, 1);
    else return 0; end


    -- TODO: THIS DOESNT WORK CLEANLY WITH THE COUNT NUMBER BECAUSE THE TURTLE DOESNT KNOW HOW MUCH IT SUCKED
    while true do
        local targetSlot = -1;
        for slot, item in pairs(p:getItems()) do
            if (cb(item, slot)) then
                targetSlot = slot;
                break;
            end
        end

        if (targetSlot == -1) then break end
        if (p:swap(targetSlot, 1)) then
            local suckAmount = math.min(math.max(need, 1), 64)
            if (Tubby.suck(side, suckAmount)) then
                need = need - suckAmount;
            end
        end
        if (need <= 0) then break end
    end

    p:swap(tempSlot, 1);
    return need;
end

--- <b>Sucks all items</b> <br>
--- Keeps going until there are no items left to suck.
---@param side any
---@return nil
function Tubby.suckAll(side)
    while true do
        local success, failReason = Tubby.suck(side);
        if (not success) then return failReason end
    end
end

--- <b>Drops an Item</b> <br>
--- Given a side enum drops the currently selected item in that direction.
---@param side number
---@return any
function Tubby.drop(side)
    return Tubby.act(Actions.DROP, side);
end

--- <b>Drops all items</b> <br>
--- Drops all items in the turtles inventory, and returns which slots it dropped.
---@param side number
---@return table slots A table of all the dropped slots.
function Tubby.dropAll(side)
    return Tubby.dropCB(side, function(item, slot) return true; end)
end

--- <b>Drops all items</b> <br>
--- Drops all items in the turtles inventory, and returns which slots it dropped.
--- @param side number
--- @param cb function(item, slot) A function that will return true if the item should be dropped.
--- @return table dropped A table of all the dropped items.
function Tubby.dropCB(side, cb)
    local dropped = {};
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot);
        if (item ~= nil and cb(item, slot)) then
            turtle.select(slot);
            Tubby.drop(side);
            table.insert(dropped, {slot=slot, item=item});
        end
    end
    return dropped;
end

--- <b>Inspect an item</b>
---@param side integer|nil
---@return table|nil
function Tubby.inspect(side)

    if (side == nil) then side = Sides.FORWARD; end

    local exists, block = Tubby.act(Actions.INSPECT, side);
    if (not exists or block == nil) then return nil; end

    local pName = Sides.toPeripheralName(side);
    if (peripheral.isPresent(pName)) then
        block.peripheral = Peripheral.wrap(pName);
    end

    return block;
end

--- <b>Compares an Item against block</b>
---@param side integer|nil Side Enum
---@return any 
function Tubby.compare(side)
    return Tubby.act(Actions.COMPARE, side)
end

--- <b>Navigates an area</b> <br>
--- Will go along the x axis then turn, go one forward and go along -x axis then repeat <br>
--- ```
--- S>>>>>>>>>
--- <<<<<<<<<<
--- >>>>>>>>>E
--- ```
---@param dx integer How many times to go left or right (Supports negative numbers)
---@param dz integer How many times to go forward
---@param onMoveFn function|nil A function defining how to move forward. Receives 2 optional `integer` arguments, of the current x and z coordinates, and can return false to cancel the iteration.
---@param onTurnFn function|nil A function defining how to turn. Receives 1 optional `integer` argument, of the current side
---@return boolean
function Tubby.iterateArea(dx, dz, onMoveFn, onTurnFn)
    onMoveFn = _def(onMoveFn, turtle.forward);
    onTurnFn = _def(onTurnFn, Tubby.turn);

    local ax = math.abs(dx);

    local turnSide = nil;
    if (dx > 0) then turnSide = Sides.RIGHT;
    else turnSide = Sides.LEFT; end

    if (onMoveFn(0, 0) == false) then return false; end
    for cx = 1, ax do
        for cz = 1, dz - 1 do
            if (onMoveFn(cx, cz) == false) then return false; end
        end
        if (cx ~= ax) then
            onTurnFn(turnSide);
            if (onMoveFn(cx, dz) == false) then return false; end
            onTurnFn(turnSide);
            turnSide = Sides.flip(turnSide);
        end
    end
    return true;
end

--- <b>Mines an area</b>
---@param dz integer forward
---@param dx integer right
---@return boolean
function Tubby.mineArea(dz, dx)

    local function forward(z, x)
        Tubby.moveMine(Sides.FORWARD);
        Tubby.mine(Sides.UP);
        Tubby.mine(Sides.DOWN);
        return true;
    end

    return Tubby.iterateArea(dz, dx, forward);
end

--- <b>Lists all Items in the turtles inventory</b>
---@param detail boolean|nil If true, will return the full item details (takes 50ms)
---@return table
function Tubby.list(detail)
    return Tubby.listCB(detail, function(slot, item) return true; end);
end

--- <b>Lists all Items in the turtles inventory</b> <br>
--- Given a callback function, will only return items that return true from the callback
---@param detail boolean|nil If true, will return the full item details (takes 50ms)
---@param cb function
---@return table
function Tubby.listCB(detail, cb)
    detail = _def(detail, false);

    local items = {};
    if (detail) then
        local fns = {};
        for slot = 1, 16 do
            fns[slot] = function()
                local item = turtle.getItemDetail(slot, true);
                if (item ~= nil and cb(slot, item)) then
                    items[slot] = item;
                end
            end
        end
        parallel.waitForAll(table.unpack(fns));
    else
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot);
            if (item ~= nil and cb(slot, item)) then
                items[slot] = item;
            end
        end
    end
    return items;
end

--- <b>Selects any non-null Item</b>
---@return integer
function Tubby.selectAny()
    local slot = Tubby.findAny();
    if (slot == nil) then return -1; end
    turtle.select(slot);
    return slot;
end

--- Selects a slot, if it is not already selected
---@param slot any The slot to select
---@return integer slot The selected slot or -1 if invalid
function Tubby.select(slot)
    if (slot < 0 or slot > 16) then return -1; end
    if (slot == turtle.getSelectedSlot()) then return slot; end

    turtle.select(slot);
    return slot;
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

function Tubby.selectEmpty()
    return Tubby.select(Tubby.findEmptySlot());
end

--- <b>Selects an Item by Name</b>
---@param itemName string Name of the item. eg. "minecraft:stick"
---@return number slot
function Tubby.selectName(itemName)
    return Tubby.select(Tubby.findItemName(itemName));
end

--- <b>Finds an item by callback</b> <br>
--- Given a function that accepts as arguments, an item object, and a slot number,
--- selects an item that the function returns true
---@param cb function Function that receives as arguments, an item object, and a slot number; returns boolean. 
---@return number slot
function Tubby.selectCB(cb)
    return Tubby.select(Tubby.findItemPredicate(cb));
end

--- <b>Find any non-null item</b>
---@return integer|nil slot The slot of the item
function Tubby.findAny()
    return Tubby.findItemPredicate(function(item, slot) return true end);
end

--- <b>Find an empty slot</b>
---@return integer|nil slot The slot of the empty slot or -1
function Tubby.findEmptySlot()
    return Tubby.findItemPredicate(function(item, slot) return item == nil end, true);
end

--- <b>Find any item by Name</b>
---@param itemName string Name of the item. eg. "minecraft:stick"
---@return integer|nil slot The slot of the item
function Tubby.findItemName(itemName)
    return Tubby.findItemPredicate(function(item, slot) return item.name == itemName end);
end

function Tubby.findItemTag(itemTag)
    return Tubby.findItemPredicate(function(item, slot, detail) return detail().tags[itemTag] ~= nil end);
end

--- <b>Find an item by callback</b> <br>
--- Given a function that accepts as arguments, an item object, and a slot number,
--- returns a slot number that the function returns as true.
---@param predicate function Function that receives as arguments, an item object, a slot number, and a function to request the item with more detail; returns boolean.
---@return integer|nil slot
function Tubby.findItemPredicate(predicate, allowNils)
    if (allowNils == nil) then allowNils = false; end

    local function detail(slot)
        return function()
            return turtle.getItemDetail(slot, true);
        end
    end

    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot);
        if (allowNils and predicate(item, slot)) then return slot; end
        if (not allowNils and item ~= nil and predicate(item, slot, detail(slot))) then return slot; end
    end

    return -1;
end

function Tubby.hasFreeSlots()
    return Tubby.countFreeSlots() > 0;
end

--- <b>Count free slots</b>
--- @return integer count The number of free slots
function Tubby.countFreeSlots()
    local total = 0;
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if (item == nil) then total = total + 1; end
    end
    return total;
end

--- <b> Count all Items</b> <br>
---@return integer count
function Tubby.countAll()
    return Tubby.countCB(function(item) return true end);
end

--- <b> Count an Item by Name</b> <br>
---@param itemName string Name of the item. eg. "minecraft:stick"
---@return integer count
function Tubby.countName(itemName)
    return Tubby.countCB(function(item) return item.name == itemName end);
end

--- <b>Count an Item by callback</b> <br>
--- Given a function that accepts as arguments, an item object, and a slot number,
--- returns a total count of items that return true from the function.
---@param cb function Function that receives as arguments, an item object, and a slot number; returns boolean.
---@return integer count
function Tubby.countCB(cb)
    local count = 0;
    for i = 1, 16 do
        local item = turtle.getItemDetail(i);
        if (item ~= nil and cb(item)) then
            count = count + item.count;
        end
    end
    return count;
end

function Tubby.compact()
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

--- <b>Get Selected Item</b>
--- @return table|nil item The selected item
function Tubby.getSelectedItem()
    return turtle.getItemDetail(turtle.getSelectedSlot());
end

--- <b>Get Facing</b>
--- @return integer facing The side the turtle is facing
function Tubby.getFacing()
    return facing;
end

local function copyVector(vec)
    return vector.new(vec.x, vec.y, vec.z);
end

--- <b>Get Position</b>
--- @return table pos The current position
function Tubby.getPos()
    return copyVector(pos);
end

function Tubby.setPos(newPos)
    pos.x = newPos.x;
    pos.y = newPos.y;
    pos.z = newPos.z;
end

function Tubby.setFacing(newFacing)
    facing = newFacing;
end

return Tubby;