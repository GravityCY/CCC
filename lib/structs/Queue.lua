
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
            head = nil,
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
    if (self.data.head == nil) then
        self.data.head = node;
        self.data.rear = node;
    else
        self.data.rear.next = node;
        self.data.rear = node;
    end

    self.data.size = self.data.size + 1;
end

---@param other Queue
function Queue:merge(other)
    if (other.data.head == nil) then return end

    if (self.data.head == nil) then
        self.data.head = other.data.head
        self.data.rear = other.data.rear
    else
        self.data.rear.next = other.data.head
        self.data.rear = other.data.rear
    end

    self.data.size = self.data.size + other.data.size
end

---@return T|nil
function Queue:dequeue()
    if (self.data.head == nil) then return nil; end

    local value = self.data.head.value;

    self.data.head = self.data.head.next;
    self.data.size = self.data.size - 1;

    if (self.data.head == nil) then
        self:clear();
    end

    return value;
end

function Queue:isEmpty()
    return self.data.head == nil;
end

function Queue:size()
    return self.data.size;
end

function Queue:clear()
    self.data.head = nil;
    self.data.rear = nil;
    self.data.size = 0;
end

function Queue:peek()
    if (self:isEmpty()) then return nil; end

    return self.data.head.value;
end

function Queue:toArray()
    local arr = {};
    local node = self.data.head;
    while (node ~= nil) do
        arr[#arr + 1] = node.value
        node = node.next;
    end

    return arr;
end

return Queue;