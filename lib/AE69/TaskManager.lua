local Queue = require("lib.Queue");

local Task = {};
Task.__index = Task;

---@param recipe Recipe
---@param amount number
---@param parent Task|nil
---@param root Task|nil
---@param processorId string
---@return Task
function Task.new(recipe, amount, parent, root, processorId)
    ---@class Task
    local self = {
        recipe = recipe,
        amount = amount,
        dependencyCount = 0,
        parent = parent,
        ---@type Task|nil
        root = root,
        ---@type string
        processorId = processorId or "__turtle-crafter__",
    }

    return self;
end

---@class TaskManager
local TaskManager = {};
TaskManager.__index = TaskManager;
TaskManager.Task = Task;

---@return TaskManager
function TaskManager.new()
    ---@class TaskManager
    local self = {};

    self.inFlight = {};
    ---@type table<Task, boolean>
    self.rootTasks = {};
    ---@type table<string, Queue<Task>>
    self.taskQueues = {};

    return setmetatable(self, TaskManager);
end

---@param task Task
function TaskManager.isRoot(task)
    return task.parent == nil and task.root == nil
end

---@param item string
function TaskManager:getInFlight(item)
    return self.inFlight[item] or 0;
end

---@param task Task
function TaskManager:queueTask(task)
    -- AE69.OnTaskQueued:invoke(task, queueMap);
    if (task == nil or task.dependencyCount > 0) then return false end
    local queue = self.taskQueues[task.processorId];
    if (queue == nil) then
        queue = Queue.new();
        self.taskQueues[task.processorId] = queue;
    end

    self:updateInFlight(task);

    queue:enqueue(task);
    return true;
end

---@param task Task
function TaskManager:completeTask(task)
    -- AE69.OnTaskComplete:invoke(task, queueMap);
    if (self:completeRoot(task)) then return end
    -- LOGGER.debug("[%s] Task '%s' completed", task.processorId, task.recipe.data.name);
    task.parent.dependencyCount = task.parent.dependencyCount - 1;
    self:queueTask(task.parent);
end

---@param task Task
function TaskManager:isRootQueued(task)
    return self.rootTasks[task] ~= nil
end

---@param task Task
function TaskManager:updateInFlight(task)
    local root = task.root or task;
    if (self:isRootQueued(root)) then return end
    local item = root.recipe.data.name;
    self.inFlight[item] = (self.inFlight[item] or 0) + root.amount;
    self.rootTasks[root] = true;
end

---@param task Task
function TaskManager:completeRoot(task)
    if (not TaskManager.isRoot(task)) then return false end
    if (not self:isRootQueued(task)) then return false end
    local name = task.recipe.data.name;
    self.inFlight[name] = math.max(0, self.inFlight[name] - task.amount);
    self.rootTasks[task] = nil;
    return true;
end

return TaskManager;