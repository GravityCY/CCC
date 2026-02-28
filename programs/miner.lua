local Tubby = require("lib.Tubby");
local Sides = require("lib.Sides");

local args = {...};

local mx, mz = nil, nil;

local function readNumber(message, error)
    while true do
        write(message);
        local num = tonumber(read());
        if (num ~= nil) then return num end
        print(error:format(num));
    end
end

if (args[1] == nil) then
    mx = readNumber("Enter Left/Right: ", "%s is not a number...");
else
    mx = tonumber(args[1]);
    if (mx == nil) then error(("%s is not a number..."):format(args[1])); end
end

if (args[2] == nil) then
    mz = readNumber("Enter Forward: " , "%s is not a number...");
else
    mz = tonumber(args[1]);
    if (mz == nil) then error(("%s is not a number..."):format(args[2])); end
end

local function onMove()
    Tubby.moveMine();
    Tubby.mine(Sides.UP);
    Tubby.mine(Sides.DOWN);
end

Tubby.iterateArea(mx, mz, onMove)