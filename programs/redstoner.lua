local Relay = require "lib.Relay"
local Arguer= require "lib.Arguer"

local Redstone = Relay.wrap(redstone);

local arguer = Arguer.new();

---@param args Arguer.Args
local function onSet(args)
    local opt = args.optional;
    local side = args.defaults[1];
    local level = tonumber(args.defaults[2]);

    local length = tonumber(opt.length);

    if (side == nil) then
        error("missing side...");
    elseif (level == nil) then
        error("missing level");
    end

    if (opt.every ~= nil) then
        local wait = tonumber(opt.every);
        if (wait == nil) then
            error("expected a number for --every");
        end

        local tickTime = length or wait;

        while true do
            Redstone:tick(side, level, 0, tickTime);
            sleep(wait);
        end

        return;
    end

    if (opt.after ~= nil) then
        local wait = tonumber(opt.after);
        if (wait == nil) then
            error("expected a number for --after");
        end
        sleep(wait);
    end

    if (length ~= nil) then
        Redstone:tick(side, level, 0, length);
    else
        Redstone:setOutput(side, level);
    end
end

local setCommand = arguer:command("set", onSet)

setCommand:default("side", 1, "the side to output the redstone");
setCommand:default("level", 2, "the redstone level to output");

setCommand:optional("every", "e", "run every x seconds");
setCommand:optional("after", "a", "run after x seconds");
setCommand:optional("length", "l", "tick for x seconds");

arguer:parse(...);