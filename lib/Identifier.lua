local String = require("lib.String");

local IdentifierLib = {};
---@class Identifier
local IdentifierInstance = {};

local IdentifierBuilder = {};

--- <b>Returns the namespace of the identifier.</b>
---@param key string
---@return string
function IdentifierLib.getNamespace(key)
    return key:match("(.+):")
end

--- <b>Returns the path of the identifier.</b>
---@param key string
---@return string
function IdentifierLib.getPath(key)
    return key:match(":(.+)")
end

--- <b>Returns a pretty path </b>
--- Eg. "minecraft:some_stick" -> "Some Stick"
--- @param key string
--- @return string
function IdentifierLib.getPrettyPath(key)
    return String.toWordCase(IdentifierInstance.getPath(key):gsub("_", " "));
end

--- <b>Creates an identifier builder.</b>
---@param namespace string
function IdentifierBuilder.new(namespace)
    local self = {
        namespace = namespace;
    }
    return setmetatable(self, {__index=IdentifierInstance.Builder});
end

--- <b>Returns an identifier</b>
---@param path string
---@return Identifier|string
function IdentifierBuilder:build(path)
    return IdentifierInstance.new(self.namespace, path);
end

--- <b>Returns a string identifier</b>
---@param path string
---@return string
function IdentifierBuilder:buildString(path)
    return self.namespace .. ":" .. path;
end

---@class Identifier
---@field namespace string
---@field path string
---@field key string

--- <b>Creates an identifier.</b>
--- @param namespace string
--- @param path string
--- @return Identifier
function IdentifierLib.new(namespace, path)
    assert(namespace ~= nil, "namespace is nil...");

    if (path == nil) then
        path = IdentifierLib.getPath(namespace);
        namespace = IdentifierLib.getNamespace(namespace);
    end

    local self = {
        namespace = namespace;
        path = path;
        key = namespace .. ":" .. path
    };

    setmetatable(self, {__index=IdentifierInstance});
    return self;
end

--- <b>Returns true if the identifier is equal to the key</b>
--- @param key string
--- @return boolean
function IdentifierInstance:is(key)
    return self.key == key;
end

--- <b>Returns true if the identifier is equal to the other identifier</b>
---@param other any
---@return boolean
function IdentifierInstance:equals(other)
    if (getmetatable(other) ~= IdentifierInstance) then return false; end
    return self.key == other.key;
end

return IdentifierLib;