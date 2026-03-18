local HashMap = {};
---@class HashMap<T, Y>
local HashMapInstance = {};
HashMapInstance.__index = HashMapInstance;

function HashMap.instanceof(obj)
    return type(obj) == "table" and getmetatable(obj) == HashMapInstance;
end

function HashMap.new()
    ---@class HashMap<T, Y>
    local self = {
        data = {
            map = {};
            size = 0;
        }
    };

    return setmetatable(self, HashMapInstance);
end

---@param key T
---@param value Y
function HashMapInstance:put(key, value)
    self.data.map[key] = value;
    if (value == nil) then
        self.data.size = self.data.size - 1;
    else
        self.data.size = self.data.size + 1;
    end
end

---@param key T
---@return Y
function HashMapInstance:get(key)
    return self.data.map[key];
end

---@param key T
---@param value Y
function HashMapInstance:getOrCreate(key, value)
    if (not self:exists(key)) then self:put(key, value); end
    return self.data.map[key];
end

---@param key T
---@return boolean
function HashMapInstance:remove(key)
    if (not self:exists(key)) then return false end

    self.data.map[key] = nil;
    self.data.size = self.data.size - 1;
    return true;
end

---@param key T
---@return boolean
function HashMapInstance:exists(key)
    return self.data.map[key] ~= nil;
end

---@return integer
function HashMapInstance:size()
    return self.data.size;
end

---@return KeyValue
local function newPair(key, value)
    ---@class KeyValue
    local self = {
        key = key,
        value = value
    };
    return self;
end

---@return KeyValue[]
function HashMapInstance:toArray()
    local arr = {};
    for key, value in pairs(self.data.map) do
        arr[#arr + 1] = newPair(key, value);
    end
    return arr;
end

return HashMap;