local String = require("lib.String");
local Table = require("lib.Table");
local PeekableIterator = require("lib.PeekableIterator")

---@class CMDL
local CMDL = {};
---@class Command
local Command = {};

---@param argIt PeekableIterator<string>
function Command:run(argIt)
    return self.fn(argIt);
end

function CMDL.new()
    ---@class CMDL
    local self = {
        commands = {};
        history = {};
    };

    CMDL.command(self, "help", "helps you with with other commands", function(argIt) self:help(argIt:next()) end)

    return setmetatable(self, {__index = CMDL});
end

function CMDL:getHistory()
    return self.history;
end

---@param name string
---@param description string
---@param fn fun(argIt: PeekableIterator<string>): any
function CMDL:command(name, description, fn)
    ---@class Command
    local command = {
        name = name;
        description = description;
        fn = fn;
    };

    self.commands[name] = setmetatable(command, {__index = Command});
end

function CMDL:help(commandName)
    if (commandName == nil or commandName == "") then
        for name, cmd in pairs(self.commands) do self:help(name); end
        return;
    end

    local command = self.commands[commandName];
    if (command == nil) then
        print("Unknown command: " .. commandName);
        return;
    end

    print(string.format("%s: %s", command.name, command.description));
end

--- Runs a command
---@param args string|table
---@return any
function CMDL:run(args)
    if (type(args) == "string") then args = String.split(args, "%s"); end

    local argIt = PeekableIterator.new(args);

    local cmdInp = argIt:next();
    local cmd = self.commands[cmdInp];
    table.insert(self.history, cmdInp);
    if (#self.history > 10) then table.remove(self.history, 1); end
    if (cmd ~= nil) then
        return cmd:run(argIt);
    else
        print("Unknown command: '" .. (cmdInp or "nil") .. "'");
    end
end

return CMDL;