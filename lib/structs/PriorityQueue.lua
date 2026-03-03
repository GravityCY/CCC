---@class PriorityQueue<T>
local PriorityQueue = {};

local function getParent(i)
    return math.floor(i / 2);
end

local function leftChild(i)
    return i * 2;
end

local function rightChild(i)
    return i * 2 + 1;
end

local function newPriorityNode(elem, priority)
    ---@class PriorityNode<T>
    local self = {elem=elem, priority=priority}
    return self;
end

---@param self PriorityQueue
---@param main PriorityNode
---@param other PriorityNode
local function isHigherPriority(self, main, other)
    if (self.data.min) then
        return main.priority < other.priority;
    else
        return main.priority > other.priority;
    end
end

---@param self PriorityQueue
---@param main PriorityNode
---@param other PriorityNode
local function isLowerPriority(self, main, other)
    return not isHigherPriority(self, other, main);
end

---@param self PriorityQueue
---@param indexA number
---@param indexB number
local function getHighestPriority(self, indexA, indexB)
    local a = self.data.heap[indexA];
    local b = self.data.heap[indexB];

    if (a == nil) then return b, indexB; end
    if (b == nil) then return a, indexA; end

    if (isHigherPriority(self, a, b)) then return a, indexA;
    else return b, indexB; end
end

---@param self PriorityQueue
---@param indexA number
---@param indexB number
local function getLowestPriority(self, indexA, indexB)
    local a = self.data.heap[indexA];
    local b = self.data.heap[indexB];

    if (a == nil) then return b, indexB; end
    if (b == nil) then return a, indexA; end

    if (isLowerPriority(self, a, b)) then return a, indexA;
    else return b, indexB; end
end

---@param self PriorityQueue
---@param indexA number
---@param indexB number
local function swap(self, indexA, indexB)
    local temp = self.data.heap[indexA];
    self.data.heap[indexA] = self.data.heap[indexB];
    self.data.heap[indexB] = temp;
end

---@param self PriorityQueue
local function bubbleUp(self)
    local index = #self.data.heap
    while (index > 1) do
        local childNode = self.data.heap[index];
        
        local parentIndex = getParent(index);
        local parentNode = self.data.heap[parentIndex];
        if (isHigherPriority(self, childNode, parentNode)) then break end
        swap(self, index, parentIndex);
        index = parentIndex;
    end
end

---@param self PriorityQueue
local function bubbleDown(self)
    local position = 1;
    local sourceNode = self.data.heap[position];

    local size = #self.data.heap;
    while true do

        local leftIndex = leftChild(position);
        local rightIndex = rightChild(position);
        if (leftIndex > size) then break end

        local lowestPriorityNode, lowestPriorityIndex = getLowestPriority(self, leftIndex, rightIndex)
        if (isLowerPriority(self, lowestPriorityNode, sourceNode)) then
            swap(self, position, lowestPriorityIndex);
            position = lowestPriorityIndex;
        else break end
    end
end

---@param min boolean true for min, false for max
function PriorityQueue.new(min)
    ---@class PriorityQueue<T>
    local self = {
        data = {
            ---@type PriorityNode<T>[]
            heap = {},
            min = min,
        }
    };

    return setmetatable(self, {__index=PriorityQueue});
end

---@param item T
function PriorityQueue:enqueue(item, priority)
    self.data.heap[#self.data.heap + 1] = newPriorityNode(item, priority);
    bubbleUp(self);
end

---@return T?
function PriorityQueue:dequeue()
    if (self:isEmpty()) then return end
    local size = self:size();
    local first = self.data.heap[1]
    local last = self.data.heap[size];
    self.data.heap[1] = last;
    self.data.heap[size] = nil;
    if (size ~= 1) then
        bubbleDown(self);
    end
    return first.elem
end

---@return boolean
function PriorityQueue:isEmpty()
    return #self.data.heap == 0;
end

---@return number
function PriorityQueue:size()
    return #self.data.heap;
end

function PriorityQueue:clear()
    self.data.heap = {};
end

function PriorityQueue:peek()
    if (self:isEmpty()) then return end
    return self.data.heap[1].elem;
end

return PriorityQueue;