local Scanner = require("lib.Turtlematic.Scanner");

local scanner = Scanner.new(peripheral.wrap("left"));

local function assertBlock(name, x, y, z)
    local ret = scanner:scanArea("block", x, y, z, x, y, z);
    assert(ret ~= nil, "ret is nil");
    assert(ret[1] ~= nil, "block is nil");
    assert(ret[1].name == name, "expected " .. name);
    print("passed test " .. name);
end

local ret = scanner:scanArea("entity", 1, -1, 0, 1, 0, 0);

assert(ret[1] ~= nil, "entity is nil");
assert(ret[1].name == "minecraft:skeleton", "not skeleton");

print("Passed all tests...");