local Math = require("lib.Math");
local Helper = require("lib.Helper")

local argFormatterMap = {}

function argFormatterMap.scan(...)
    return "portableUniversalScan", {...};
end

local ScannerLib = {};
---@class Scanner : turtlematic.peripheral.ScannerInstance
local ScannerInstance = {};

---@param self Scanner
---@param fn function
---@param op string
---@param ... any
---@return ...
local function wait(self, fn, op, ...)
    local cooldown = self.scanner.getCooldown(op);
    if (cooldown ~= nil and cooldown > 0) then
        sleep(cooldown / 1000);
    end
    return fn(...);
end

---@param self Scanner
---@param methodName string
---@param formatter? fun(...): string, table
local function makeBlocking(self, methodName, formatter)
    local og = self.scanner[methodName];

    return function(_, ...)
        local op = methodName
        local args = {...}

        if (formatter ~= nil) then
            op, args = formatter(...)
        end

        return wait(self, og, op, table.unpack(args))
    end
end

---@param self Scanner
---@param key string
---@return any
local function __index(self, key)
    if (ScannerInstance[key] ~= nil) then return ScannerInstance[key]; end

    local og = self.scanner[key];
    if (type(og) ~= "function") then return og; end

    local methodName = key;

    local formatter = argFormatterMap[methodName];
    if (formatter ~= nil) then
        self[methodName] = makeBlocking(self, methodName, formatter);
    else
        local cooldown = self.scanner.getCooldown(methodName);
        if (cooldown == nil) then
            self[methodName] = function(_, ...) return og(...) end;
        else
            self[methodName] = makeBlocking(self, methodName, nil);
        end
    end

    return self[methodName];
end

local function within(v, v1, v2)
    return v >= v1 and v <= v2;
end

ScannerInstance.__index = __index;

---@param obj turtlematic.peripheral.Scanner|string
---@return Scanner
function ScannerLib.new(obj)
    if (type(obj) == "string") then
        ---@diagnostic disable-next-line: cast-local-type
        obj = peripheral.wrap(obj);
    end

    if (obj == nil) then error("invalid Scanner") end

    ---@class Scanner
    local self = {
        ---@type turtlematic.peripheral.Scanner
        ---@diagnostic disable-next-line: assign-type-mismatch
        scanner = obj;
    };

    return setmetatable(self, ScannerInstance);
end

function ScannerInstance:await(op)
    local cooldown = self.scanner.getCooldown(op);
    if (cooldown ~= nil and cooldown > 0) then
        sleep(cooldown / 1000);
    end
end

--- Scan a radius while including air blocks
--- @param mode turtlematic.ScanType
--- @param radius integer
function ScannerInstance:scanAir(mode, radius)
    local tab = self:scan(mode, radius); ---@type turtlematic.scan.Block[]
    local out = {};

    local size = radius * 2 + 1;
    local offset = radius + 1;

    for i, block in pairs(tab) do
        local x = block.x + offset;
        local y = block.y + offset;
        local z = block.z + offset;

        --- turtlematic returns z -> y -> x
        --- function returns x -> z -> y
        local index3D = Math.get3D1D(z, x, y, size, size, size);
        out[index3D] = block;
    end

    return out;
end

function ScannerInstance:scanArea(mode, x1, y1, z1, x2, y2, z2)
    local radius = math.max(
        math.abs(x1), math.abs(x2),
        math.abs(y1), math.abs(y2),
        math.abs(z1), math.abs(z2)
    )

    local tab;
    if (mode == "block") then
        tab = self:scanAir(mode, radius);
    else
        tab = self:scan(mode, radius);
    end

    local out = {};

    if (mode == "block") then
        local size = radius * 2 + 1;
        local offset = radius + 1;

        for x in Helper.iterate(x1 + offset, x2 + offset) do
            for y in Helper.iterate(y1 + offset, y2 + offset) do
                for z in Helper.iterate(z1 + offset, z2 + offset) do
                    local index3D = Math.get3D1D(x, y, z, size, size, size);
                    table.insert(out, tab[index3D]);
                end
            end
        end
    else
        for _, entity in ipairs(tab) do
            if (within(entity.x, x1, x2) and within(entity.y, y1, y2) and within(entity.z, z1, z2)) then
                table.insert(out, entity);
            end
        end
    end

    return out;
end

function ScannerInstance:scanBlock(mode, x, y, z)
    return self:scanArea(mode, x, y, z, x, y, z);
end

function ScannerInstance:getConfiguration(arg)
    if (arg == nil) then return self.scanner.getConfiguration(); end

    return self.scanner.getConfiguration()[arg];
end

return ScannerLib;