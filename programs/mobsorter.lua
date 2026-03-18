local Automata = require("lib.Turtlematic.Automata");
local EasyAddress = require("lib.EasyAddress");
local Relay    = require("lib.Relay")
local Ask      = require("lib.Ask")
local Serial = require("lib.Serial");
local Peripheral = require("lib.Peripheral")
local Inventorio = require("lib.Inventorio")
local Identifier = require("lib.Identifier")
local Serializable = require("lib.Serializers")

local data = Serial.new("mobsorter");

data:serializer(Serial.Serializer.new()
    :setPredicate(function(v) return Relay.instanceof(v) end)
    :setConverter(function(v) return {__name="relay", relay=data:toSerializable(v.data.relay)} end)
);

data:deserializer(Serial.Serializer.new()
    :setPredicate(function(v) return type(v) == "table" and v.__name == "relay" end)
    :setConverter(function(v) return Relay.wrap(data:toDeserializable(v.relay)) end)
);

data:serializer(Serial.Serializer.new()
    :setPredicate(Serializable.Serializers.isPeripheral)
    :setConverter(Serializable.Serializers.peripheral)
);

data:deserializer(Serial.Serializer.new()
    :setPredicate(Serializable.Deserializers.isPeripheral)
    :setConverter(Serializable.Deserializers.peripheral)
);

data:load();

local DETECTION_SLOWNESS = 0.2;
local TRY_CIRCULATE = data:getOrSet("TRY_CIRCULATE", 3);
local CIRCULATE_COOLDOWN = 1;

local automata = Automata.new(peripheral.wrap("right"))
local overflowRail = peripheral.wrap("front");

local buffer = Inventorio.new(peripheral.find("minecraft:chest"));
local hopper = Inventorio.new(peripheral.find("minecraft:hopper"));
local dispenser = Inventorio.new(peripheral.find("minecraft:dispenser"));
local myName = peripheral.find("modem").getNameLocal();

local dispenserRelay = data:get("dispenserRelay");
if (dispenserRelay == nil) then
    dispenserRelay = Relay.wrap(EasyAddress.wait("dispenserRelay", "Enable the dispenser relay!"));
    data:set("dispenserRelay", dispenserRelay);
end

local dequeueRelay = data:get("dequeueRelay");
if (dequeueRelay == nil) then
    dequeueRelay = Relay.wrap(EasyAddress.wait("dequeueRelay", "Enable the buffer relay!"));
    data:set("dequeueRelay", dequeueRelay);
end

local lastCirculation = 0;

---@cast dispenser ccTweaked.peripherals.Inventory
---@cast overflowRail turtlematic.peripheral.Rail

local defaultTowardsJunction = data:get("defaultTowardsJunction");
if (defaultTowardsJunction == nil) then
    defaultTowardsJunction = Ask.ask("Default minecart movement -> junction (y/n): ", Ask.yesNo());
    data:set("defaultTowardsJunction", defaultTowardsJunction);
end

local entities = {
    "minecraft:zombie",
    "minecraft:skeleton",
    "minecraft:creeper",
    "minecraft:enderman",
    "minecraft:witch",
    "minecraft:zombie_villager"
};

local liveThreads = {};

local stop = false;

---@type table<string, Chamber>
local chambers;

data:auto();

local function pprint(format, ...) print(string.format(format, ...)); end

local function newChamber(railAddr, dequeueAddr, entityName)
    ---@class Chamber
    local self = {
        ---@type turtlematic.peripheral.Rail
        rail = peripheral.wrap(railAddr);
        ---@type Relay
        dequeue = Relay.wrap(peripheral.wrap(dequeueAddr));
        entityName = entityName;
        expectedUuids = {};
        count = 0;
        limit = 5;
    }
    return self;
end

local function incrementData(id, n, min, max)
    min = min or -math.huge;
    max = max or math.huge;

    local old = (data:get(id) or 0);
    local new = math.max(math.min(old + n, max), min);

    data:set(id, new);
end

local function pushMinecart(rail, towardsJunction)
    rail.pushMinecarts(towardsJunction ~= defaultTowardsJunction);
end

---@return string?, any[]?
local function awaitMinecart(rail, lastUuid, timeout)
    timeout = timeout or math.huge;

    local start = os.clock();
    while ((os.clock() - start) < timeout) do
        local minecarts = rail.getMinecarts();
        
        local minecart = minecarts[1];
        if (minecart and minecart.uuid ~= lastUuid) then return minecart.uuid, minecarts; end
    end
end

local function awaitOverflow(pollCooldown, timeout)
    timeout = timeout or math.huge;
    pollCooldown = pollCooldown or 0;

    local overflow = data:get("overflowCount");
    local start = os.clock();
    if (overflow ~= 0) then
        repeat
            local push = hopper:pushName(buffer, "minecraft:minecart", overflow);
            if (push > 0) then
                incrementData("overflowCount", -push, 0);
            end
            if (pollCooldown ~= 0) then sleep(pollCooldown); end
        until (data:get("overflowCount") == 0 or (os.clock() - start) < timeout);
    end
end

local function sendChamber(entity, minecartUuid)
    print("Sending " .. entity.name);
    pushMinecart(overflowRail, false);

    local chamber = chambers[entity.name];
    chamber.expectedUuids[minecartUuid] = true;
    data:save();
end

local function sendOverflow(amount)
    pushMinecart(overflowRail, true);
    incrementData("circulating", -amount, 0);
    incrementData("overflowCount", amount, 0);
end

local function circulate(n)
    local toCirculate = math.min(TRY_CIRCULATE - data:get("circulating"), n);
    toCirculate = math.max(0, toCirculate);
    if (toCirculate == 0) then return false end

    for i = 1, toCirculate do
        if (stop) then return false; end
        local tts = math.max(CIRCULATE_COOLDOWN - (os.clock() - lastCirculation), 0);
        if (tts ~= 0) then sleep(tts); end
        if (buffer:pushName(dispenser, "minecraft:minecart", 1) == 0) then return false; end
        dispenserRelay:tick(nil, true, 0.1);
        
        lastCirculation = os.clock();
        incrementData("circulating", 1, 0)
    end

    return true;
end

local function circulateThread()
    if (not data:exists("circulating")) then data:set("circulating", 0); end

    repeat 
        if (not circulate(TRY_CIRCULATE - data:get("circulating"))) then
            sleep(0.05);
        end
    until (stop);
end

local function setup()
    ---@type KeyValue[]
    local chambersData = data:get("chambers");
    if (data:exists("chambers")) then
        chambers = data:get("chambers");
    else
        ---@type table<string, Chamber>
        chambers = {};

        for index, id in ipairs(entities) do
            local name = Identifier.getPrettyPath(id);
            local rail = EasyAddress.wait(name .. " Rail", "The rail of the chamber");
            local dequeue = EasyAddress.wait(name .. " Dequeue Relay", "The dequeue relay of the chamber");
            local chamber = newChamber(rail, dequeue, id);
            chambers[id] =  chamber;
        end
        data:set("chambers", chambers);
    end

    data:trySave();
    data:auto();
end

local function mainThread()
    liveThreads["main"] = true;

    do
        local minecarts = overflowRail.getMinecarts();
        if (#minecarts ~= 0) then
            sendOverflow(#minecarts);
            sleep(1);
        end
    end
    
    local lastUuid = nil;
    repeat
        if (data:get("circulating") ~= 0) then
            local newUuid, minecarts = awaitMinecart(overflowRail, lastUuid, 1);
            
            if (newUuid ~= nil and minecarts ~= nil) then
                local entity = automata:look("entity");
                if (entity == nil) then
                    sleep(DETECTION_SLOWNESS);
                    sendOverflow(#minecarts);
                else
                    local chamber = chambers[entity.name];
                    if (chamber ~= nil) then
                        if (chamber.count >= chamber.limit) then
                            sleep(DETECTION_SLOWNESS);
                            sendOverflow(#minecarts);
                        else
                            sleep(DETECTION_SLOWNESS);
                            sendChamber(entity, newUuid)
                            chamber.count = chamber.count + 1;
                            incrementData("circulating", -1, 0);
                            incrementData("highwayCount", 1)
                        end
                    else
                        sleep(DETECTION_SLOWNESS);
                        sendOverflow(#minecarts);
                    end
                end
            end
            lastUuid = newUuid;
        else
            sleep(5);
        end
    until (stop);

    
    local _, minecarts = awaitMinecart(overflowRail, lastUuid, 2);
    if (minecarts ~= nil) then
        sleep(DETECTION_SLOWNESS);
        print("[Scanner] Found leftover minecarts, sending to overflow");
        sendOverflow(#minecarts);
        awaitOverflow(0.5);
    else
        print("[Scanner] No leftover minecarts found")
    end

    liveThreads["main"] = false;
end

local function overflowThread()
    liveThreads["overflow"] = true;

    repeat
        local overflow = data:get("overflowCount");
        if (overflow ~= 0) then
            awaitOverflow();
        else
            sleep(1);
        end
    until (stop and not liveThreads["main"]);

    liveThreads["overflow"] = false;
end

local function stopThread()
    liveThreads["stop"] = true;
    repeat
        sleep(0.5);
    until redstone.getInput("left");

    print("Enabling stop flag...");
    stop = true;
    liveThreads["stop"] = false;
end

local function dequeueThread()
    liveThreads["dequeue"] = true;

    repeat
        if (data:get("circulating") ~= 0) then
            dequeueRelay:tick(nil, true, 0.1);
            sleep(CIRCULATE_COOLDOWN);
        else
            sleep(5);
        end
    until stop;

    liveThreads["dequeue"] = false;
end

---@param chamber Chamber
local function createRailWatcher(chamber)
    local lastUuid;
    
    return function()
        liveThreads["railWatcher:" .. chamber.entityName] = true;
        repeat
            if (data:get("highwayCount") ~= 0) then
                local minecart = chamber.rail.getMinecarts()[1];
                local newUuid = minecart and minecart.uuid;

                local pushIntoJunction = chamber.expectedUuids[newUuid] ~= nil;
                if (minecart ~= nil) then
                    pushMinecart(chamber.rail, pushIntoJunction);
                end

                if (chamber.expectedUuids[lastUuid] ~= nil) then
                    if (newUuid ~= lastUuid) then
                        chamber.expectedUuids[lastUuid] = nil;
                        pprint("Received 1 '%s' (%d/%d)", chamber.entityName, chamber.count, chamber.limit);
                        incrementData("highwayCount", -1, 0);
                    end
                end

                lastUuid = newUuid;
            else sleep(0.5); end
        until (stop and data:get("highwayCount") == 0);

        liveThreads["railWatcher:" .. chamber.entityName] = false;
    end
end

---@param chamber Chamber
local function createDequeueWatcher(chamber)
    return function()
        liveThreads["dequeueWatcher:" .. chamber.entityName] = true;
        repeat
            local any = chamber.dequeue:awaitSidePoll("back", 0.1, 1, 15);
            if (any ~= nil and chamber.count > 0) then
                chamber.dequeue:tick("front", true, 0.1);
                chamber.count = chamber.count - 1;
                pprint("Dequeueing 1 '%s' (%d/%d)", Identifier.getPrettyPath(chamber.entityName), chamber.count, chamber.limit);
                data:save();
            end
        until (stop);
        liveThreads["dequeueWatcher:" .. chamber.entityName] = false;
    end
end

local function createChamberThreads()
    local chamberThreads = {};
    for key, value in pairs(chambers) do
        table.insert(chamberThreads, createRailWatcher(value));
        table.insert(chamberThreads, createDequeueWatcher(value));
    end
    return chamberThreads;
end

local function resetData()
    for _, chamber in pairs(chambers) do
        chamber.count = 0;
        chamber.expectedUuids = {};
    end

    data:auto(false);
    data:set("circulating", 0);
    data:set("highwayCount", 0);
    data:set("overflowCount", 0);
    data:auto(true);

    data:save();
    
    print("Reset chamber data");
    print("Reset circulation data");
    print("Reset highway count data");
    print("Reset overflow count data");
end

setup();
local args = {...};
for i, v in ipairs(args) do
    if (v == "reset") then resetData(); end
    if (tonumber(v) ~= nil) then
        local num = tonumber(v);
        num = math.floor(num);

        data:set("TRY_CIRCULATE", num);
        TRY_CIRCULATE = num;
        print("Set TRY_CIRCULATE to " .. num);
    end
end
parallel.waitForAll(mainThread, overflowThread, circulateThread, stopThread, dequeueThread, table.unpack(createChamberThreads()));
