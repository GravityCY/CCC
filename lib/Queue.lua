
---@class Queue
local Queue = {};
Queue.__index = Queue;

local function newNode(elem)
    ---@class Node<T>
    local self = {
        value = elem,
        next = nil
    }

    return self;
end

function Queue.new()
    ---@class Queue<T>
    local self = {
        data = {
            ---@type Node
            front = nil,
            ---@type Node
            rear = nil,
            ---@type number
            size = 0
        }
    }

    return setmetatable(self, Queue);
end

---@param item T
function Queue:enqueue(item)
    local node = newNode(item);
    if (self.data.front == nil) then
        self.data.front = node;
        self.data.rear = node;
    else
        self.data.rear.next = node;
        self.data.rear = node;
    end

    self.data.size = self.data.size + 1;
end

---@return T|nil
function Queue:dequeue()
    if (self.data.front == nil) then return nil; end

    local value = self.data.front.value;

    self.data.front = self.data.front.next;
    self.data.size = self.data.size - 1;

    if (self.data.front == nil) then
        self:clear();
    end

    return value;
end

function Queue:isEmpty()
    return self.data.front == nil;
end

function Queue:size()
    return self.data.size;
end

function Queue:clear()
    self.data.front = nil;
    self.data.rear = nil;
    self.data.size = 0;
end

function Queue:peek()
    if (self:isEmpty()) then return nil; end

    return self.data.front.value;
end

function Queue:toArray()
    local arr = {};
    local node = self.data.front;
    while (node ~= nil) do
        arr[#arr + 1] = node.value
        node = node.next;
    end

    return arr;
end

return Queue;