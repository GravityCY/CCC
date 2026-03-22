local Std = require("lib.Std");
local String = require("lib.String");
local Table  = require("lib.Table")
local Path   = require("lib.Path")

local SerialLib = {};
local CodecLib = {};

local Codec = {}; ---@class Codec
Codec.__index = Codec;
local Serial = {}; ---@class Serial

Serial.__name = "Serial";
Serial.__index = Serial;
Serial.__construct = SerialLib.new;

SerialLib.Codec = CodecLib;

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

---@param self Serial
---@param v any
local function getSerializer(self, v)
    for id, codec in pairs(self.codecs) do
        if (codec.serializer.predicate(v)) then
            return codec.serializer;
        end
    end

    if (self.parent ~= nil) then
        return getSerializer(self.parent);
    end
end

---@param self Serial
---@param v any
local function getDeserializer(self, v)
    for id, codec in pairs(self.codecs) do
        if (codec.deserializer.predicate(v)) then
            return codec.deserializer;
        end
    end

    if (self.parent ~= nil) then
        return getDeserializer(self.parent);
    end
end

function CodecLib.new(id)
    ---@class Codec
    local self = {
        id = id;
        serializer = {
            ---@type fun(value: any): boolean
            predicate = nil;
            ---@type fun(value: any): any
            converter = nil;
        };
        deserializer = {
            ---@type fun(value: any): boolean
            predicate = nil;
            ---@type fun(value: any): any
            converter = nil;
        }
    };
    
    return setmetatable(self, Codec);
end

function Codec:serialize(predicate, converter)
    self.serializer.predicate = predicate;
    self.serializer.converter = converter;
    return self;
end

function Codec:deserialize(predicate, converter)
    self.deserializer.predicate = predicate;
    self.deserializer.converter = converter;
    return self;
end

---@param namespace string
---@param id? string
---@return Serial
function SerialLib.new(namespace, id)
    id = id or namespace;

    local namespaceDir = Std.getAndMakeDirectory("serial", namespace);

    ---@class Serial
    local self = {
        namespace = namespace;
        id = id;
        path = Path.join(namespaceDir, id .. ".luaj");
        data = {};
        autosave = false;
        codecs = {}; ---@type table<string, Codec>
        modifications = 0;
        parent = nil;
    };

    return setmetatable(self, Serial);
end

function Serial:child(id)
    local child = SerialLib.new(self.namespace, id);
    child.parent = self;
    return child;
end

function Serial:classCodec(id, class, dataGetter)
    self:codec(id, SerialLib.Codec.new(id)
        :serialize(
            function(v) return type(v) == "table" and class == getmetatable(v) end,
            function(v) return {__name=class.__name, data=self:toSerializable(dataGetter(v))} end
        )
        :deserialize(
            function(v) return type(v) == "table" and v.__name == class.__name end,
            function(v) return class.__construct(self:toDeserializable(v.data)) end
        )
    );
end

--- @param codec Codec
function Serial:codec(id, codec)
    self.codecs[id] = codec;
end

--- Converts a serialized value back to its deserialzed value
---@param value any
---@return any
function Serial:toDeserializable(value)
    local deserializer = getDeserializer(self, value)
    if (deserializer) then return deserializer.converter(value); end
    if (type(value) ~= "table") then return value end

    local out = {};

    for k, v in pairs(value) do
        out[k] = self:toDeserializable(v);
    end

    return out;
end

--- Converts a value to a serializable value
---@param value any
---@return any
function Serial:toSerializable(value)
    if (type(value) == "function") then return nil; end

    local serializer = getSerializer(self, value)
    if (serializer ~= nil) then return serializer.converter(value); end
    if (type(value) ~= "table") then return value end

    local out = {};

    for k, v in pairs(value) do
        out[k] = self:toSerializable(v);
    end

    return out;
end

--- Only tries saving if there is any modifications
function Serial:trySave()
    if (self.modifications == 0) then return end
    self:save();
end

--- Saves the whole document
function Serial:save()
    local file = fs.open(self.path, "w");
    file.write(textutils.serialize(self:toSerializable(self.data)));
    file.close();
    self.modifications = 0;
end

--- Loads the whole document
function Serial:load()
    if (not fs.exists(self.path)) then return end

    local file = fs.open(self.path, "r");
    self.data = self:toDeserializable(textutils.unserialize(file.readAll()));
    file.close();
end

--- Automatically save after every modification
---@param value boolean? default is true
function Serial:auto(value)
    if (value == nil) then value = true; end
    self.autosave = value;
    return self;
end

--- Get a variable
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

--- Checks if a variable exists
---@param key string|string[]
---@return boolean
function Serial:exists(key)
    local keys = getKeyAsList(key);
    return self:get(keys) ~= nil;
end

--- Get a variable or set it if it doesn't exist
---@param key string|string[]
---@param value any
function Serial:getOrSet(key, value)
    local keys = getKeyAsList(key);

    local v = self:get(keys);
    if (v == nil) then self:set(keys, value); end
    return v or value;
end

--- Set a variable
---@param key string|string[]
---@param value any
---@return any prev
function Serial:set(key, value)
    local keys = getKeyAsList(key);
    local data, lkey = getOrMakeParent(self, keys);

    local prev = data[lkey];
    data[lkey] = value;
    
    if (self.autosave) then
        self:save();
    else
        self.modifications = self.modifications + 1;
    end
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

return SerialLib;