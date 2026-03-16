local Automata = require("lib.Turtlematic.Automata");
local Ask = require("lib.Ask");
local Relay = require("lib.Relay");
local EasyAddress = require("lib.EasyAddress");
local Serial = require("lib.Serial")
local Peripheral = require("lib.Peripheral")
local Sides      = require("lib.Sides")
local Inventorio = require("lib.Inventorio")
local Redstone = Relay.wrap(redstone);

local function pprint(message, ...)
    print(message:format(...));
end

local ADR = EasyAddress.new("mobsorterv2");

---@return SorterRelay
local function newRelay(name)
    local junction = Relay.wrap(ADR.get(name .. "JunctionRelay", true));
    local dequeue = Relay.wrap(ADR.get(name .. "DequeueRelay", true));
    
    ---@class SorterRelay
    local self = {
        junction = junction,
        dequeue = dequeue
    }

    return self;
end

---@diagnostic disable-next-line: param-type-mismatch
local automata = Automata.new(Peripheral.firstByPredicate(function(p) return p.getCooldown ~= nil end));
if (automata == nil) then
    error("No automata peripheral found");
end

---@diagnostic disable-next-line: param-type-mismatch
local dispenser = peripheral.find("minecraft:dispenser");
if (dispenser == nil) then
    error("No dispenser peripheral found");
end

local myName = peripheral.find("modem").getNameLocal();
if (myName == nil or myName == "") then
    error("Turtle not connected");
end

local dispenserRelay = Relay.wrap(ADR.get("dispenserRelay", true));

local minecartBuffer = Inventorio.new(peripheral.find("minecraft:chest"));

---@type table<string, SorterRelay>
local relays = {
    ["minecraft:zombie"]=newRelay("zombie");
    ["minecraft:creeper"]=newRelay("creeper");
    ["minecraft:skeleton"]=newRelay("skeleton");
    ["minecraft:enderman"]=newRelay("enderman");
}

--- TODO: STORAGE CAPACITIES PER MOB
--- DONE: POP MOB OUT THE CHAMBER AND DECREMENT
--- EVERY PUSHED MOB SHOULD CIRCULATE A NEW MINECART
--- NEED A STORAGE OF #chamber_capacities minecarts
--- IF EVERYTHING IS FULL DONT CIRCULATE MINECARTS
--- EG. 36 TOTAL, 32 USED + CURRENTLY CIRCULATING, THEN 36 - 32 + CURRENTLY CIRCULATING FREE
--- ONLY CIRUCLATE A MAXIMUM OF N AT A TIME

local data = Serial.new("mobsorter"):auto();

local function isTowardsHighway()
    return not Ask.ask("Default rail direction -> highway? (y/n): ", Ask.yesNo());
end

if (not data:exists("towardsHighway")) then
    data:set("towardsHighway", isTowardsHighway());
end

local defaultTowardsHighway = data:get("towardsHighway");

local function getState(towardsJunction)
    return towardsJunction == defaultTowardsHighway;
end

local function setAll(towardsJunction)
    for _, relay in pairs(relays) do
        relay.junction:setOutput("front", getState(towardsJunction));
        relay.junction:setOutput("left", towardsJunction);
    end
end

local function set(relay, towardsJunction)
    setAll(not towardsJunction)
    relay:setOutput("front", getState(towardsJunction));
    relay:setOutput("left", towardsJunction);
end

local function increment(prev)
    return (prev or 0) + 1;
end

local function decrement(prev)
    return math.max(0, (prev or 0) - 1);
end

local circulating = data:getOrSet("circulating", 0);

local circleAmount = 4;

local lastCircle = os.clock()

local function circulate(n, f)
    local toCirculate = n;
    if (not f) then
        toCirculate = math.min(circleAmount - circulating, n);
        if (toCirculate == 0) then return end
    end

    pprint("Circulating %d", toCirculate);

    for i = 1, toCirculate do
        sleep(math.max(math.min(0.5 - os.clock() - lastCircle, 0.5), 0));
        minecartBuffer:pushName(dispenser, "minecraft:minecart", 1);
        dispenserRelay:tick(nil, true, 0.1);
    end
    
    if (not f) then
        circulating = circulating + toCirculate;
        data:setvar("circulating", circulating);
    end
end

-- TODO: ISSUES WITH THE EVENT QUEUE OR SOMETHING? I THINK I'M OVERFILLING THE EVENT QUEUE WITH TOO MANY EVENTS (256)
-- MANY RELAYS AWAITING FOR EVENTS, LOTS OF SLEEPS, IDEK


local function sortThread()
    circulate(circleAmount);
    while true do
        Redstone:tick("top", true, 0.1);
        sleep(0.6);

        local entity = automata:look("entity");
        if (entity == nil) then
            if (turtle.attack()) then
                minecartBuffer:pull(myName, 1);
                circulate(1, true);
            end
        else
            local relay = relays[entity.name];
            if (relay ~= nil) then
                print(("Found %s pushing to chamber"):format(entity.name));
                set(relay.junction, true);
                Redstone:tick("bottom", true, 0.1);
                relay.junction:awaitSidePoll("back", 15);

                data:modifyvar("stored", entity.name, increment);
                pprint("Stored %d %s", data:getvar("stored", entity.name), entity.name);
            end
            setAll(false);
            circulate(1, true);
        end
    end
end

local function dequeueThread()
    local tasks = {};

    for name, relay in pairs(relays) do
        table.insert(tasks, function()
            while true do
                local side, prev, new = relay.dequeue:awaitAnyPoll(0.1);
                if (side == Sides.DOWN and prev == 0 and new == 15) then
                    relay.dequeue:tick("front", true, 0.05);
                    data:modifyvar("stored", name, decrement);
                    pprint("Removed 1 %s. Is now %d", name, data:getvar("stored", name));
                end
            end
        end);
    end

    parallel.waitForAll(table.unpack(tasks));
end

parallel.waitForAll(sortThread, dequeueThread);