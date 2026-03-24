local String = require "lib.String"
local PeekableIterator = require "lib.structs.PeekableIterator"
local ArguerLib = {};

---@class Arguer
local Arguer = {};
Arguer.__index = Arguer;

---@class Arguer.Command
local Command = {};
Command.__index = Command;

---@class Arguer.OptionalArgument
local OptionalArgument = {};
OptionalArgument.__index = OptionalArgument;

---@param arg Arguer.OptionalArgument
---@param it structs.PeekableIterator<string>
local function parseValue(arg, it)
    if (it:peek() == "=") then
        it:skip();
        local value = it:next(); ---@cast value string
        if (not String.startsWith(value, "-")) then
            if (arg.data.typeFormatter ~= nil) then
                value = arg.data.typeFormatter(value);
                if (value == nil) then
                    error("invalid value for " .. arg.data.name .. " expected a " .. arg.data.expectedType, 0);
                end
            end
            return value;
        else
            error("expected a value right after... instead got another argument?", 0);
        end
    else
        print("expected '='");
    end
end

---@param arg Arguer.OptionalArgument
---@param it structs.PeekableIterator<string>
---@param input string
---@param data Arguer.Args
local function parseOpt(arg, it, input, data)
    local result;
    if (it:peek() == "=") then
        local res = {pcall(parseValue, arg, it)};

        if (not res[1]) then
            error(input ..": " .. res[2], 0);
        end
        result = res[2];
    elseif (arg.data.hasDefault) then
        result = arg.data.default;
    end

    data.optional[arg.data.name] = result;
end

local function tokenize(str)
    local spacedOut = String.split(str, " ");

    local tokens = {};

    for _, str2 in ipairs(spacedOut) do
        local equaledOut = String.split(str2, "=", true);
        for _, token in ipairs(equaledOut) do
            table.insert(tokens, token);
        end
    end

    return tokens;
end

function OptionalArgument:needsArg(v)
    self.data.needsValue = v;
    return self;
end

function OptionalArgument:description(v)
    self.data.description = v;
    return self;
end

function OptionalArgument:short(v)
    self.data.shortName = v;
    return self;
end

function OptionalArgument:default(v)
    self.data.hasDefault = true;
    self.data.default = v;
    return self;
end

function OptionalArgument:register()
    self.data.parent.argRegistry[self.data.name] = self;
    if (self.data.shortName ~= nil) then
        self.data.parent.shortRegistry[self.data.shortName] = self;
    end
end

---@param name string
---@return Arguer.OptionalArgument
function Command:optional(name, expectedType)
    ---@class Arguer.OptionalArgument
    local optional = {
        data = {
            name = name;
            expectedType = expectedType;
            typeFormatter = nil; ---@type fun(v: any): any
            shortName = nil; ---@type string
            description = nil; ---@type string
            hasDefault = false;
            default = nil;
            parent = self; ---@type Arguer.Command
        }
    };

    if (expectedType == "number") then
        optional.data.typeFormatter = tonumber;
    elseif (expectedType == "boolean") then
        optional.data.typeFormatter = function(v)
            if (v == "true") then return true;
            elseif (v == "false") then return false; end
        end;
    end

    return setmetatable(optional, OptionalArgument);
end

---@param name string
---@param index integer
---@param description string
function Command:default(name, expectedType, index, description)
    ---@class Arguer.DefaultArgument
    local default = {
        data = {
            ---@type string
            name = name;
            ---@type string
            expectedType = expectedType;
            ---@type fun(v: string): any
            typeFormatter = nil;
            ---@type integer
            index = index;
            ---@type string
            description = description;
        }
    };

    if (expectedType == "number") then
        default.data.typeFormatter = tonumber;
    elseif (expectedType == "boolean") then
        default.data.typeFormatter = function(v)
            if (v == "true") then return true;
            elseif (v == "false") then return false; end
        end
    end

    index = index or (#self.defaultRegistry + 1);
    self.defaultRegistry[index] = default;
end

---@param it structs.PeekableIterator<string>
function Command:parse(it)
    ---@class Arguer.Args
    local data = {
        defaults = {};
        optional = {};
    };

    local totalDefaults = #self.defaultRegistry;
    local defaultsAdded = 0;

    while (it:hasNext()) do
        local cur = it:next();
        ---@cast cur string

        local isShort = String.startsWith(cur, "-");
        local isFull = String.startsWith(cur, "--");

        if (isShort or isFull) then
            local key;
            if (isFull) then key = cur:sub(3);
            else key = cur:sub(2); end

            local arg;
            if (isFull) then
                arg = self.argRegistry[key];
            else
                arg = self.shortRegistry[key];
            end

            if (arg ~= nil) then
                parseOpt(arg, it, cur, data);
            else
                error("unknown argument " .. key, 0);
            end
        else
            local value = cur;
            local index = defaultsAdded + 1;
            local arg = self.defaultRegistry[index];
            if (arg.data.typeFormatter ~= nil) then
                value = arg.data.typeFormatter(value);
                if (value == nil) then
                    error("invalid value for " .. arg.data.name .. " expected a " .. arg.data.expectedType, 0);
                end
            end
            defaultsAdded = defaultsAdded + 1;
            data.defaults[arg.data.name] = value;
        end
    end

    if (defaultsAdded ~= totalDefaults) then
        local start = math.max(defaultsAdded + 1, 1);
        for i = start, #self.defaultRegistry do
            local default = self.defaultRegistry[i];
            error("missing default argument '" .. default.data.name .. "'", 0);
        end
    end

    self.runFunc(data);
end

function ArguerLib.new()
    ---@class Arguer
    local self = {
        commandRegistry = {}; ---@type table<string, Arguer.Command>
    };
    return setmetatable(self, Arguer);
end

---@param name string
---@param runFunc fun(data: Arguer.Args)
---@return Arguer.Command
function Arguer:command(name, runFunc)
    ---@class Arguer.Command
    local command = {
        name = name;
        argRegistry = {}; ---@type table<string, Arguer.OptionalArgument>
        shortRegistry = {}; ---@type table<string, Arguer.OptionalArgument>
        defaultRegistry = {}; ---@type Arguer.DefaultArgument[]
        runFunc = runFunc;
    };
    
    command = setmetatable(command, Command);

    self.commandRegistry[name] = command;
    return command;
end

function Arguer:parse(str)
    local it = PeekableIterator.new(tokenize(str), 1); ---@type structs.PeekableIterator<string>

    if (not it:hasNext()) then
        print("expected a command...");
        return false;
    end

    while (it:hasNext()) do
        local cur = it:next();
        if (self.commandRegistry[cur] ~= nil) then
            local cmd = self.commandRegistry[cur]; ---@type Arguer.Command
            local success, err = pcall(cmd.parse, cmd, it);
            if (not success) then
                print(err);
                return false;
            end
        else
            print("unknown command " .. cur);
            return false;
        end
    end

    return true;
end

return ArguerLib;