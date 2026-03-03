---@class PeekableIterator<T>
local PeekableIterator = {};

---@param list T[]
---@param startIndex? integer
---@return PeekableIterator
function PeekableIterator.new(list, startIndex)
    ---@class PeekableIterator
    local self = {
        data = {
            list = list;
            index = startIndex or 1;
        }
    };

    return setmetatable(self, {__index = PeekableIterator});
end

function PeekableIterator:hasNext()
    return self.data.index <= #self.data.list;
end

---@return T
function PeekableIterator:next()
    if (not self:hasNext()) then return end
    local value = self.data.list[self.data.index];
    self.data.index = self.data.index + 1;
    return value;
end

function PeekableIterator:peek()
    return self.data.list[self.data.index];
end

return PeekableIterator;