--- Title: Address
--- Description: A library for working with addresses.
--- Version: 0.2.0

local Address = {};

local sideMap = {
    ["front"]   = true,
    ["right"]   = true,
    ["back"]    = true,
    ["left"]    = true,
    ["top"]     = true,
    ["bottom"]  = true
}

function Address.equals(a, b)
    return a.full == b.full;
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
function Address.new(full)
    local self = {};
    self.full = full;
    self.namespace = Address.getNamespace(full);
    self.type = Address.getType(full);
    self.index = Address.getIndex(full);

    function self.isSide()
        return sideMap[self.full] ~= nil;
    end

    function self.equals(other)
        return Address.equals(self, other);
    end

    function self.tostring()
        return self.full;
    end

    return self;
end

return Address;