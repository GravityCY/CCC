local Relay = require "lib.Relay"
local Arguer= require "lib.Arguer"
local String= require "lib.String"

local Redstone = Relay.wrap(redstone);

local arguer = Arguer.new();

---@param args Arguer.Args
local function onSet(args)
    local input = Redstone;
    local output = Redstone;

    local opt = args.optional;
    local defaults = args.defaults;

    local side = defaults.side;
    local level = defaults.level;

    local length = opt.length;

    if (side == nil) then
        error("missing side...", 0);
    elseif (level == nil) then
        error("missing level", 0);
    end

    if (opt.input ~= nil) then
        local modem = peripheral.wrap(opt.input); ---@cast modem ccTweaked.peripherals.WiredModem
        input = Relay.wrap(modem.getNamesRemote()[1])
    end

    if (opt.output ~= nil) then
        local modem = peripheral.wrap(opt.output); ---@cast modem ccTweaked.peripherals.WiredModem
        output = Relay.wrap(modem.getNamesRemote()[1]);
    end

    local repeatTimes = opt["repeat"] or 1;
    
    local i = 1;
    while true do
        if (opt.on ~= nil) then
            if (opt.cooldown ~= nil) then
                sleep(opt.cooldown);
            end
            local split = String.split(opt.on, ":");
            local side2 = split[1];
            local level2 = tonumber(split[2]);
            input:awaitSide(side2, level2);
        end

        if (opt.after ~= nil) then
            local wait = opt.after;
            if (wait == nil) then
                error("expected a number for --after", 0);
            end
            sleep(wait);
        end

        if (length ~= nil) then
            local ticks = opt.ticks or 1;
            for j = 1, ticks do
                output:tick(side, level, 0, length);
                sleep(length);
            end
        else
            output:setOutput(side, level);
        end

        if (repeatTimes ~= -1) then
            if (i >= repeatTimes) then break end
            i = i + 1;
        end
    end
end

local setCommand = arguer:command("set", onSet)

setCommand:default("side", "string", 1, "the side to output the redstone");
setCommand:default("level", "number", 2, "the redstone level to output");

setCommand:optional("cooldown", "number"):short("c"):description("the cooldown from the redstone input events"):register();
setCommand:optional("on", "string"):description("when to set the redstone side"):register();
setCommand:optional("input", "string"):short("i"):description("the side to look for a relay for the input"):register();
setCommand:optional("output", "string"):short("o"):description("the side to look for a relay for the output"):register();
setCommand:optional("after", "number"):short("a"):description("run after x seconds"):register();
setCommand:optional("ticks", "number"):short("t"):description("how many ticks to output"):register();
setCommand:optional("length", "number"):short("l"):description("tick for x seconds"):register();
setCommand:optional("repeat", "number"):default(-1):short("r"):description("whether to repeat"):register();

arguer:parse(table.concat({...}, " "));