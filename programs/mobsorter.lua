local Concurrent = require("lib.Concurrent")
local Scanner = require("lib.Turtlematic.Scanner");
local EasyAddress = require("lib.EasyAddress");
local Relay    = require("lib.Relay")
local Ask      = require("lib.Ask")
local Serial = require("lib.Serial");
local Peripheral = require("lib.Peripheral")
local Inventorio = require("lib.Inventorio")
local Identifier = require("lib.Identifier")
local Serializable = require("lib.Serializers")
local Helper       = require("lib.Helper")
local Rail         = require("lib.Turtlematic.Rail")
local Redstone = Relay.wrap(redstone);

---@class Chamber
local Chamber = {};
Chamber.__name = "chamber";

local function newChamber(railAddr, relayAddr, dequeueAddr, entityName)
    ---@class Chamber
    local self = {
        ---@diagnostic disable-next-line: assign-type-mismatch
        rail = peripheral.wrap(railAddr); ---@type turtlematic.peripheral.Rail
        junctionRelay = Relay.wrap(peripheral.wrap(relayAddr)); ---@type Relay
        dequeueRelay = Relay.wrap(peripheral.wrap(dequeueAddr)); ---@type Relay
        entityName = entityName;
        expectedUuids = {};
        count = 0;
        limit = 5;
    }


    return setmetatable(self, Chamber);
end
Chamber.__construct = newChamber;

local data = Serial.new("mobsorter");

data:classCodec("inventorio", Inventorio.class(), function(inventory) return inventory.periph end);
data:classCodec("relay", Relay.class(), function(relay) return relay.data.relay end);

--- peripherals
data:codec("peripheral", Serial.Codec.new()
    :serialize(
        Serializable.Serializers.isPeripheral,
        Serializable.Serializers.peripheral
    )
    :deserialize(
        Serializable.Deserializers.isPeripheral,
        Serializable.Deserializers.peripheral
    )
);

data:load();

local function awaitModem(message, type, min, max)
    print(message);
    local addrs = EasyAddress.awaitModem();
    local new = {};
    if (type ~= nil) then
        for _, addr in ipairs(addrs) do
            if (peripheral.getType(addr) == type) then
                table.insert(new, addr);
            end
        end
    end

    min = min or 1;
    max = max or 1;

    if (#new == 1) then
        return new[1];
    else
        local selections = Ask.choose("Please choose " .. tostring(min), {byIndex=new, min=min, max=max});
        if (max == 1) then return selections[1].value; end
        local out = {};
        for _, selection in ipairs(selections) do
            table.insert(out, addrs[selection.index]);
        end
        return out;
    end
end

local function getPeripheral(name, type, wrapper)
    local periph = data:get(name);
    if (periph == nil) then
        periph = wrapper(awaitModem("Enable the '" .. name .. "' peripheral", type));
        data:set(name, periph);
    end
    return periph;
end

local DETECTION_SLOWNESS = 0.2;
local RAIL_SWITCHING_WAIT = 0.4;
local CIRCULATE_COOLDOWN = 0.5;
local TRY_CIRCULATE = data:getOrSet("TRY_CIRCULATE", 3);

---@diagnostic disable-next-line: param-type-mismatch
local scanner1 = Scanner.new(peripheral.wrap("left"))
---@diagnostic disable-next-line: param-type-mismatch
local scanner2 = Scanner.new(peripheral.wrap("right"))
local lastScannerLeft = false;
local detectorRail = Rail.wrap(peripheral.wrap("front")) ---@type Rail;

---@diagnostic disable-next-line: param-type-mismatch
local buffer = Inventorio.new(peripheral.find("minecraft:chest"));
---@diagnostic disable-next-line: param-type-mismatch
local hopper = Inventorio.new(peripheral.find("minecraft:hopper"));
---@diagnostic disable-next-line: param-type-mismatch
local dispenser = Inventorio.new(peripheral.find("minecraft:dispenser"));

local overflowRelay = getPeripheral("overflowRelay", "redstone_relay", Relay.wrap); ---@type Relay
local dispenserRelay = getPeripheral("dispenserRelay", "redstone_relay", Relay.wrap); ---@type Relay

local lastCirculation = 0;

local defaultTowardsJunction = data:get("defaultTowardsJunction");
if (defaultTowardsJunction == nil) then
    defaultTowardsJunction = Ask.ask("Default minecart movement -> junction (y/n): ", Ask.yesNo());
    data:set("defaultTowardsJunction", defaultTowardsJunction);
end

local entityRegistry = {
    "minecraft:zombie",
    "minecraft:skeleton",
    "minecraft:creeper",
    "minecraft:enderman",
    "minecraft:witch",
    "minecraft:zombie_villager",
    "minecraft:chicken_jockey",
    "minecraft:baby_zombie",
};

local liveThreads = {};

local shutdownFlag = false;

---@type table<string, Chamber>
local chambers;

local function pprint(format, ...) print(string.format(format, ...)); end

local function incrementData(id, n, min, max)
    min = min or -math.huge;
    max = max or math.huge;

    local old = (data:get(id) or 0);
    local new = math.max(math.min(old + n, max), min);

    data:set(id, new);
end

---@param relay Relay
---@param towardsJunction boolean
local function faceRail(relay, towardsJunction)
    relay:setOutput("top", towardsJunction ~= defaultTowardsJunction);
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
    print("Sending " .. entity);
    local chamber = chambers[entity];
    chamber.expectedUuids[minecartUuid] = true;
    chamber.count = chamber.count + 1;
    incrementData("highwayCount", 1)
    incrementData("circulating", -1, 0);
    data:save();
end

local function sendOverflow(amount)
    overflowRelay:tick("top", not defaultTowardsJunction, defaultTowardsJunction, RAIL_SWITCHING_WAIT);
    incrementData("circulating", -amount, 0);
    incrementData("overflowCount", amount, 0);
end

local function circulate(n)
    local toCirculate = math.min(TRY_CIRCULATE - data:get("circulating"), n);
    toCirculate = math.max(0, toCirculate);
    if (toCirculate == 0) then return false end

    for i = 1, toCirculate do
        if (shutdownFlag) then return false; end
        local tts = math.max(CIRCULATE_COOLDOWN - (os.clock() - lastCirculation), 0);
        if (tts ~= 0) then sleep(tts); end
        if (buffer:pushName(dispenser, "minecraft:minecart", 1) == 0) then return false; end
        dispenserRelay:tick(nil, true, false, 0.1);
        
        lastCirculation = os.clock();
        incrementData("circulating", 1, 0)
    end

    return true;
end

local function decideEntity(entityList)
    local a = entityList[1];
    local b = entityList[2];
    
    if (a ~= nil and a.name == "minecraft:zombie" and b ~= nil and b.name == "minecraft:chicken") then
        return "minecraft:chicken_jockey";
    end

    if (a ~= nil and a.name == "minecraft:chicken" and b ~= nil and b.name == "minecraft:zombie") then
        return "minecraft:chicken_jockey";
    end

    if (a ~= nil and a.name == "minecraft:zombie" and a.health == 20) then
        return "minecraft:baby_zombie";
    end
    
    return a and a.name;
end

local function markThreadActive(id, state)
    local shouldPrint = string.find(id, "Watcher") == nil;

    if (shouldPrint) then
        if (state) then
            print("[".. id .."] activated")
        else
            print("[".. id .."] shutdown")
        end
    end

    liveThreads[id] = state;
end

local function circulateThread()
    markThreadActive("circulate", true);

    if (not data:exists("circulating")) then data:set("circulating", 0); end

    repeat
        if (not circulate(TRY_CIRCULATE - data:get("circulating"))) then
            sleep(0.05);
        end
    until (shutdownFlag);

    markThreadActive("circulate", false);
end

local function mainThread()
    markThreadActive("main", true)

    overflowRelay:setOutput("top", defaultTowardsJunction);

    local lastUuid = nil;
    repeat
        if (data:get("circulating") ~= 0) then
            
            local scanner;
            if (lastScannerLeft) then scanner = scanner2;
            else scanner = scanner1; end
            scanner:await("portableUniversalScan");

            Redstone:tick("top", true, false, 0.1);
            local newUuid, minecarts = detectorRail:awaitMinecart(lastUuid, 0.75);

            if (newUuid ~= nil and minecarts ~= nil) then
                lastScannerLeft = not lastScannerLeft;
                local entities = scanner:scanArea("entity", 1, -1, 0, 1, 0, 0);
                local entityName = decideEntity(entities);
                if (entityName == nil) then
                    sendOverflow(#minecarts);
                else
                    local chamber = chambers[entityName];
                    if (chamber ~= nil) then
                        if (chamber.count >= chamber.limit) then
                            sendOverflow(#minecarts);
                        else
                            sendChamber(entityName, newUuid)
                        end
                    else
                        sendOverflow(#minecarts);
                    end
                end
            end
            lastUuid = newUuid;
        else
            sleep(5);
        end
    until (shutdownFlag);

    local _, minecarts = detectorRail:awaitMinecart(lastUuid, 2);
    if (minecarts ~= nil) then
        sleep(DETECTION_SLOWNESS);
        print("[Scanner] Found leftover minecarts, sending to overflow");
        sendOverflow(#minecarts);
        awaitOverflow(0.5);
    else
        print("[Scanner] No leftover minecarts found")
    end

    markThreadActive("main", false)
end

local function overflowThread()
    markThreadActive("overflow", true);

    repeat
        local overflow = data:get("overflowCount");
        if (overflow ~= 0) then
            awaitOverflow();
        else
            sleep(1);
        end
    until (shutdownFlag and not liveThreads["main"] and data:get("overflowCount") == 0);

    markThreadActive("overflow", false);
end

local function stopThread()
    markThreadActive("stop", true);

    repeat sleep(1);
    until shutdownFlag or redstone.getInput('left');
 
    if (not shutdownFlag) then
        print("Enabling stop flag...");
        shutdownFlag = true;
    end

    markThreadActive("stop", false);
end

-- local function dequeueThread()
--     markThreadActive("dequeue", true);

--     repeat
--         if (data:get("circulating") ~= 0) then
--             sleep(CIRCULATE_COOLDOWN);
--         else
--             sleep(1);
--         end
--     until shutdownFlag;

--     markThreadActive("dequeue", false);
-- end

---@param chamber Chamber
local function createRailWatcher(chamber)
    return function()
        markThreadActive("railWatcher:" .. chamber.entityName, true);
        
        local lastUuid;
        
        faceRail(chamber.junctionRelay, false);
        repeat
            if (data:get("highwayCount") ~= 0) then
                local minecart = chamber.rail.getMinecarts()[1];
                local newUuid = minecart and minecart.uuid;
                
                local intoJunction = chamber.expectedUuids[newUuid] ~= nil;
                if (minecart ~= nil and intoJunction) then
                    faceRail(chamber.junctionRelay, true)
                    sleep(RAIL_SWITCHING_WAIT);
                    faceRail(chamber.junctionRelay, false);
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
        until (shutdownFlag and data:get("highwayCount") == 0);

        markThreadActive("railWatcher:" .. chamber.entityName, false);
    end
end

---@param chamber Chamber
local function createDequeueWatcher(chamber)
    return function()
        markThreadActive("dequeueWatcher:" .. chamber.entityName, true);
        repeat
            local any = chamber.dequeueRelay:awaitSidePoll("back", 0.1, 1, 15);
            if (any ~= nil and chamber.count > 0) then
                chamber.dequeueRelay:tick("front", true, false, 0.1);
                chamber.count = chamber.count - 1;
                pprint("Dequeueing 1 '%s' (%d/%d)", Identifier.getPrettyPath(chamber.entityName), chamber.count, chamber.limit);
                data:save();
            end
        until (shutdownFlag);
        
        markThreadActive("dequeueWatcher:" .. chamber.entityName, false);
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

local function setup()
    ---@type KeyValue[]
    local chambersData = data:get("chambers");
    if (data:exists("chambers")) then
        chambers = data:get("chambers");
    else
        ---@type table<string, Chamber>
        chambers = {};

        for index, id in ipairs(entityRegistry) do
            local name = Identifier.getPrettyPath(id);
            pprint("'%s' chamber", name);

            local rail = awaitModem("Please enable the powered rail!", "minecraft:powered_rail");
            local relay = awaitModem("Please enable the junction relay!", "redstone_relay")
            local dequeue = awaitModem("Please enable the dequeue relay!", "redstone_relay");
            local chamber = newChamber(rail, relay, dequeue, id);
            chambers[id] =  chamber;
        end

        data:set("chambers", chambers);
    end

    data:trySave();
    data:auto();
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

---@return boolean ignoreTerminate
function onTerminate()
    if (shutdownFlag) then
        print("Force shutting down...");
        return false;
    end

    print("Enabling stop flag...");
    shutdownFlag = true;
    return true;
end

Concurrent.awaitAll({
    terminateHandler = onTerminate;
    tasks = { mainThread, overflowThread, circulateThread, stopThread, table.unpack(createChamberThreads()) }
});