---@class HashMap<T, Y>
local HashMap = {};

function HashMap.new()
    ---@class HashMap<T, Y>
    local self = {
        data = {
            ---@type table<T, Y>
            map = {};
        }
    };

    return setmetatable(self, {__index=HashMap});
end

function HashMap:put(key, value)
    self.data.map[key] = value;
    if (value == nil) then
        self.data.size = self.data.size - 1;
    else
        self.data.size = self.data.size + 1;
    end
end

function HashMap:get(key)
    return self.data.map[key];
end

function HashMap:getOrCreate(key, value)
    if (not self:exists(key)) then self:put(key, value); end
    return self.data.map[key];
end

function HashMap:exists(key)
    return self.data.map[key] ~= nil;
end

function HashMap:size()
    return self.data.size;
end

function HashMap:toArray()
    local arr = {};
    for key, value in pairs(self.data.map) do
        arr[#arr + 1] = {key=key, value=value};
    end
    return arr;
end

return HashMap;