local Std = require("lib.Std");
local String = require("lib.String");
local Table  = require("lib.Table")
local Path   = require("lib.Path")

---@class Serial
local Serial = {};

--- Summary: serialize / deserialize
--- By default given an id will just give back a table
--- If present on the file system will try to load
--- Allow custom paths

local dir = Std.getAndMakeDirectory("serial");

---@param key string|string[]
local function getKeyAsList(key)
    local t = type(key);
    assert(t == "string" or t == "table", "key must be a string or table");

    if (t == "string") then
        return String.split(key, ".");
    end

    return key;
end

---@param self Serial
---@param keys string[]
local function getOrMakeParent(self, keys)
    local data = self.data;

    for i = 1, #keys - 1 do
        local key = keys[i];
        if (data[key] == nil) then data[key] = {}; end
        data = data[key];
    end

    return data, keys[#keys];
end

local function getKeysAndValue(...)
    local args = {...};

    local keys = {};
    local value = args[#args];

    for i = 1, #args - 1 do
        table.insert(keys, args[i]);
    end

    return keys, value;
end

---@param namespace string
---@param id? string
function Serial.new(namespace, id)
    id = id or namespace;

    local namespaceDir = Std.getAndMakeDirectory("serial", namespace);

    ---@class Serial
    local self = {
        path = Path.join(namespaceDir, id .. ".luaj");
        data = {};
        autosave = false;
    };

    self = setmetatable(self, {__index = Serial});

    self:load();

    return self;
end

function Serial:save()
    local file = fs.open(self.path, "w");
    file.write(textutils.serialize(self.data));
    file.close();
end

function Serial:load()
    if (not fs.exists(self.path)) then return end

    local file = fs.open(self.path, "r");
    self.data = textutils.unserialize(file.readAll());
    file.close();
end

--- Automatically save every modification
function Serial:auto()
    self.autosave = true;
    return self;
end

---@param key string|string[]
---@return any
function Serial:get(key)
    local keys = getKeyAsList(key);

    local tab = self.data;
    for _, key2 in ipairs(keys) do
        if (tab == nil) then return nil; end
        tab = tab[key2];
    end

    return tab;
end

---@param key string|string[]
---@return boolean
function Serial:exists(key)
    local keys = getKeyAsList(key);
    return self:get(keys) ~= nil;
end

function Serial:getOrSet(key, value)
    local keys = getKeyAsList(key);

    local v = self:get(keys);
    if (v == nil) then self:set(keys, value); end
    return v or value;
end

---@param key string|string[]
---@param value any
---@return any prev
function Serial:set(key, value)
    local keys = getKeyAsList(key);
    local data, lkey = getOrMakeParent(self, keys);

    local prev = data[lkey];
    data[lkey] = value;
    
    if (self.autosave) then self:save(); end
    return prev;
end

--- Modify a value <br>
--- eg. self:modify("a.b.c.d", function(prev) return (prev or 0) + 1 end)
---@param key string|string[]
---@param modifier fun(prev: any): any
function Serial:modify(key, modifier)
    local keys = getKeyAsList(key);
    return self:set(keys, modifier(self:get(keys)));
end

--- Get a variable by vararg keys <br>
function Serial:getvar(...)
    local args = {...};
    return self:get(args);
end

--- Set a variable by vararg keys and last argument value<br>
--- 1 to n-1 are the keys, n is the value
---@param ... any
function Serial:setvar(...)
    local keys, value = getKeysAndValue(...);
    self:set(keys, value);
end

--- Set a variable by vararg keys and last argument modifier<br>
--- 1 to n-1 are the keys, n is the modifier
---@param ... any
function Serial:modifyvar(...)
    local keys, value = getKeysAndValue(...);
    self:modify(keys, value);
end

return Serial;