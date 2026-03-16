--- Title: Address
--- Description: A library for working with addresses.
--- Version: 0.2.0

local Address = {};
local AddressInstance = {};

local sideMap = {
    ["front"]   = true,
    ["right"]   = true,
    ["back"]    = true,
    ["left"]    = true,
    ["top"]     = true,
    ["bottom"]  = true
}

function Address.equals(a, b)
    return getmetatable(a) == getmetatable(b) and a.full == b.full;
end

---@param address string
---@return string
function Address.getNamespace(address)
    return address:match("(.+):");
end

---@param address string
---@return string
function Address.getType(address)
    return address:match(":(.+)_")
end

---@param address string
---@return number|nil
function Address.getIndex(address)
    return tonumber(address:match("_(%d+)"));
end

---@param full string
---@return Address
function Address.new(full)
    ---@class Address
    local self = {
        full = full;
        namespace = Address.getNamespace(full);
        type = Address.getType(full);
        index = Address.getIndex(full);
        isSide = sideMap[full] ~= nil;
    };

    return setmetatable(self, AddressInstance);
end

return Address;