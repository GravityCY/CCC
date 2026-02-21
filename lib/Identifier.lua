local String = require("String");

local Identifier = {};
Identifier.__index = Identifier;

Identifier.Builder = {};
Identifier.Builder.__index = Identifier.Builder;

--- <b>Returns the namespace of the identifier.</b>
---@param key string
---@return string
function Identifier.getNamespace(key)
    return key:match("(.+):")
end

--- <b>Returns the path of the identifier.</b>
---@param key string
---@return string
function Identifier.getPath(key)
    return key:match(":(.+)")
end

function Identifier.getPrettyPath(key)
    return String.toWordCase(Identifier.getPath(key):gsub("_", " "));
end

--- <b>Creates an identifier builder.</b>
---@param namespace string
function Identifier.Builder.new(namespace)
    return setmetatable({namespace = namespace}, Identifier.Builder);
end

--- <b>Returns an identifier</b>
---@param path string
---@return Identifier|string
function Identifier.Builder:build(path)
    return Identifier.new(self.namespace, path);
end

    --- <b>Returns a string identifier</b>
    ---@param path string
    ---@return string
function Identifier.Builder:buildString(path)
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
function Identifier.new(namespace, path)
    local self = {};
    self.namespace = namespace;
    self.path = path;

    local function _new1(_namespace, _path)
        self.namespace = _namespace;
        self.path = _path;
        self.key = self.namespace .. ":" .. self.path;
    end

    local function _new2(_key)
        local _namespace, _path = Identifier.getNamespace(_key), Identifier.getPath(_key);
        _new1(_namespace, _path);
    end

    if (namespace ~= nil and path ~= nil) then
        _new1(namespace, path);
    elseif (namespace ~= nil and path == nil) then
        _new2(namespace);
    end

    setmetatable(self, Identifier);
    return self;
end

--- <b>Returns true if the identifier is equal to the key</b>
--- @param key string
--- @return boolean
function Identifier:is(key)
    return self.key == key;
end

--- <b>Returns true if the identifier is equal to the other identifier</b>
---@param other any
---@return boolean
function Identifier:equals(other)
    if (getmetatable(other) ~= Identifier) then return false; end
    return self.key == other.key;
end

return Identifier;