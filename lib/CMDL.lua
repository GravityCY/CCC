local String = require("lib.String");
local Table = require("lib.Table");
local PeekableIterator = require("lib.structs.PeekableIterator")
local Helper           = require("lib.Helper")

local CMDLLib = {};
---@class CMDL
local CMDLInstance = {};
---@class Command
local Command = {};

---@param argIt PeekableIterator<string>
function Command:run(argIt)
    return self.fn(argIt);
end

function CMDLLib.new()
    ---@class CMDL
    local self = {
        data = {
            commands = {};
            history = {};
        }
    };

    self = setmetatable(self, {__index = CMDLInstance});
    self:command("help", "helps you with with other commands", function(argIt) self:help(argIt:next()) end)

    return self;
end

function CMDLInstance:getHistory()
    return self.data.history;
end

---@param name string
---@param description string
---@param fn fun(argIt: PeekableIterator<string>): any
function CMDLInstance:command(name, description, fn)
    ---@class Command
    local command = {
        name = name;
        description = description;
        fn = fn;
    };

    self.data.commands[name] = setmetatable(command, {__index = Command});
end

function CMDLInstance:help(commandName)
    if (commandName == nil or commandName == "") then
        for name, cmd in pairs(self.data.commands) do self:help(name); end
        return;
    end

    local command = self.data.commands[commandName];
    if (command == nil) then
        print("Unknown command: " .. commandName);
        return;
    end

    print(string.format("%s: %s", command.name, command.description));
end

--- Runs a command
---@param args string|table
---@return any
function CMDLInstance:run(args)
    if (type(args) == "string") then args = String.split(args, "%s"); end
    local argStr = Table.toString(args)

    local argIt = PeekableIterator.new(args);

    local cmdInp = argIt:next();
    local cmd = self.data.commands[cmdInp];
    table.insert(self.data.history, argStr);
    if (#self.data.history > 10) then table.remove(self.data.history, 1); end
    if (cmd ~= nil) then
        return cmd:run(argIt);
    else
        print("Unknown command: '" .. (cmdInp or "nil") .. "'");
    end
end

return CMDLLib;