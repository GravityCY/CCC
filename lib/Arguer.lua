local String = require "lib.String"
local PeekableIterator = require "lib.structs.PeekableIterator"
local ArguerLib = {};

---@class Arguer
local Arguer = {};
Arguer.__index = Arguer;

---@class Arguer.Command
local Command = {};
Command.__index = Command;

---@param name string
---@param shortName string
---@param description string
function Command:optional(name, shortName, description)
    ---@class Arguer.OptionalArgument
    local optional = {
        name = name;
        shortName = shortName;
        description = description;
    };

    self.argRegistry[name] = optional;
    if (shortName ~= nil) then
        self.shortRegistry[shortName] = optional;
    end
end

---@param name string
---@param index integer
---@param description string
function Command:default(name, index, description)
    ---@class Arguer.DefaultArgument
    local default = {
        name = name;
        index = index;
        description = description;
    };

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
                if (it:hasNext()) then
                    local value = it:next(); ---@cast value string
                    if (not String.startsWith(value, "-")) then
                        data.optional[arg.name] = value;
                    else
                        error(cur..": expected a value right after... instead got another argument?", 0);
                    end
                else
                    error(cur..": expected a value right after...", 0);
                end
            else
                error("unknown argument " .. key, 0);
            end
        else
            data.defaults[#data.defaults + 1] = cur;
        end
    end

    if (#data.defaults ~= #self.defaultRegistry) then
        local start = math.max(#data.defaults + 1, 1);
        for i = start, #self.defaultRegistry do
            local default = self.defaultRegistry[i];
            error("missing default argument '" .. default.name .. "'", 0);
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

---comment
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

function Arguer:parse(...)
    local it = PeekableIterator.new({...}, 1); ---@type structs.PeekableIterator<string>
    
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

function Arguer:parseString(str)
    local args = String.split(str, " ");
    self:parse(table.unpack(args));
end

return ArguerLib;