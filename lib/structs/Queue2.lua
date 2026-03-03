local Table = require("lib.Table")
---@class Queue2
local Queue2 = {};
Queue2.__index = Queue2;

---@param self Queue2
---@param i number
local function positionToIndex(self, i)
    return (self.data.head + i - 1) % self.data.limit + 1;
end


---@param self Queue2
---@param i number
local function getAtPosition(self, i)
    return self.data.buffer[positionToIndex(self, i)];
end

---@param self Queue2
local function indexToPosition(self, i)
    return (i - self.data.head + self.data.limit) % self.data.limit + 1
end

function Queue2.new(initialSize)
    ---@class Queue2<T>
    local self = {
        data = {
            ---@type number
            head = 1,
            ---@type number
            rear = 1,
            ---@type number
            limit = initialSize,
            ---@type number
            size = 0,
            ---@type T[]
            buffer = {};
        }
    }

    return setmetatable(self, Queue2);
end

---@param self Queue2
local function resize(self)
    Table.shift(self.data.buffer, self.data.limit, self.data.limit - self.data.head + 1);
    self.data.limit = self.data.limit * 2;
end

---@param item T
function Queue2:enqueue2(item)
    self.data.buffer[self.data.rear] = item;
    self.data.rear = self.data.rear % self.data.limit + 1;
    self.data.size = self.data.size + 1;
    if (self.data.size == self.data.limit) then resize(self); end
end

---@return T?
function Queue2:dequeue2()
    if (self:isEmpty()) then return end
    local value = self.data.buffer[self.data.head];
    self.data.head = self.data.head % self.data.limit + 1;
    self.data.size = self.data.size - 1;
    return value;
end

---@return boolean
function Queue2:isEmpty()
    return self.data.size == 0;
end

---@return number
function Queue2:size()
    return self.data.size;
end

function Queue2:clear()
    self.data.size = 0;
    self.data.head = nil;
    self.data.rear = nil;
end

function Queue2:peek()
    if (self:isEmpty()) then return nil; end

    return self.data.buffer[self.data.head];
end

function Queue2:toArray()
    local arr = {};

    for i = 1, self.data.limit do
        table.insert(arr, getAtPosition(self, i));
    end

    return arr;
end

return Queue2;