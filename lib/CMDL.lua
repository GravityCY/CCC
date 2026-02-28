local String = require("lib.String");
local Table = require("lib.Table");

local CMDL = {};
local Command = {};
CMDL.__index = CMDL;
Command.__index = Command;

function Command:run(subargs)
    return self.fn(subargs);
end

function CMDL.new()
    local self = setmetatable({commands = {}}, CMDL);
    self:command("help", "help", function(subargs) self:help(subargs[1]) end)
    return self;
end


function CMDL:command(name, description, fn)
    self.commands[name] = setmetatable({name = name, description = description, fn = fn}, Command);
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

    local cmd = self.commands[args[1]];
    local subargs = Table.range(args, 2);
    if (cmd ~= nil) then
        return cmd:run(subargs);
    else
        print("Unknown command: " .. args[1]);
    end
end

return CMDL;