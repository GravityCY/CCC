local Peripheral = require("lib.Peripheral");

local autoPeriph = Peripheral.firstByPredicate(function(p) return p.getCooldown ~= nil end);

if (autoPeriph == nil) then return nil; end

local Automata = {};

---@param fn function
---@param op string
---@param ... any
---@return any
local function wait(fn, op, ...)
    local cooldown = autoPeriph.getCooldown(op);
    if (cooldown ~= nil and cooldown > 0) then
        sleep(cooldown / 1000);
    end
    return fn(...);
end

---@param methodName string
---@param formatter fun(...): op: string, table
local function makeBlocking(methodName, formatter)
    local method = autoPeriph[methodName];

    return function(...)
        local op = methodName
        local args = {...}

        if (formatter ~= nil) then
            op, args = formatter(...)
        end

        return wait(method, op, table.unpack(args))
    end
end

local formatterMap = {}

function formatterMap.scan(scanType, ...)
    local operation;
    if (scanType == "item") then
        operation = "scanItems";
    elseif (scanType == "block") then
        operation = "scanBlocks";
    elseif (scanType == "entity") then
        operation = "scanEntities";
    end

    assert(operation, "invalid scan type");

    return operation, {...};
end

for methodName, method in pairs(autoPeriph) do
    if (type(method) ~= "function") then goto continue; end

    local formatter = formatterMap[methodName];
    if (formatter) then
        Automata[methodName] = makeBlocking(methodName, formatterMap[methodName]);
    else
        local cooldown = autoPeriph.getCooldown(methodName);
        if (cooldown == nil) then
            Automata[methodName] = method;
        else
            Automata[methodName] = makeBlocking(methodName, formatterMap[methodName]);
        end
    end
    ::continue::
end

function Automata.getConfiguration(arg)
    return autoPeriph.getConfiguration()[arg];
end

return Automata;