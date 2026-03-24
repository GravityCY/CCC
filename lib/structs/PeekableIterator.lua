---@class structs.PeekableIterator<T>
local PeekableIterator = {};

---@param list T[]
---@param startIndex? integer
---@return structs.PeekableIterator
function PeekableIterator.new(list, startIndex)
    ---@class structs.PeekableIterator
    local self = {
        data = {
            list = list;
            index = startIndex or 1;
        }
    };

    return setmetatable(self, {__index = PeekableIterator});
end

---@return boolean
function PeekableIterator:hasNext()
    return self.data.index <= #self.data.list;
end

---@return T?
function PeekableIterator:next()
    if (not self:hasNext()) then return end
    local value = self.data.list[self.data.index];
    self.data.index = self.data.index + 1;
    return value;
end

---@param n integer?
function PeekableIterator:skip(n)
    n = n or 1;

    self.data.index = self.data.index + n;
end

---@return T
function PeekableIterator:peek()
    return self.data.list[self.data.index];
end

return PeekableIterator;