local AutomataLib = {};
---@class Automata : turtlematic.AutomataInstance
local AutomataInstance = {};

local argFormatterMap = {}

function argFormatterMap.scan(scanType, ...)
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

---@param self Automata
---@param fn function
---@param op string
---@param ... any
---@return ...
local function wait(self, fn, op, ...)
    local cooldown = self.automata.getCooldown(op);
    if (cooldown ~= nil and cooldown > 0) then
        sleep(cooldown / 1000);
    end
    return fn(...);
end

---@param self Automata
---@param methodName string
---@param formatter? fun(...): string, table
local function makeBlocking(self, methodName, formatter)
    local og = self.automata[methodName];

    return function(_, ...)
        local op = methodName
        local args = {...}

        if (formatter ~= nil) then
            op, args = formatter(...)
        end

        return wait(self, og, op, table.unpack(args))
    end
end

---@param self Automata
---@param key string
---@return any
local function __index(self, key)
    if (AutomataInstance[key] ~= nil) then return AutomataInstance[key]; end

    local og = self.automata[key];
    if (type(og) ~= "function") then return og; end

    local methodName = key;

    local formatter = argFormatterMap[methodName];
    if (formatter ~= nil) then
        self[methodName] = makeBlocking(self, methodName, formatter);
    else
        local cooldown = self.automata.getCooldown(methodName);
        if (cooldown == nil) then
            self[methodName] = function(_, ...) return og(...) end;
        else
            self[methodName] = makeBlocking(self, methodName, nil);
        end
    end

    return self[methodName];
end

---@param obj turtlematic.Automata|string
---@return Automata
function AutomataLib.new(obj)
    if (type(obj) == "string") then
        ---@diagnostic disable-next-line: cast-local-type
        obj = peripheral.wrap(obj);
    end

    if (obj == nil) then error("invalid automata") end

    ---@class Automata
    local self = {
        ---@type turtlematic.Automata
        ---@diagnostic disable-next-line: assign-type-mismatch
        automata = obj;
    };

    return setmetatable(self, {__index = __index});
end

function AutomataInstance:getConfiguration(arg)
    if (arg == nil) then return self.automata.getConfiguration(); end

    return self.automata.getConfiguration()[arg];
end

return AutomataLib;