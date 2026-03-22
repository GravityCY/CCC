local Concurrent = {};

local function newThread(func)
    ---@class Concurrent.Thread
    local self = {
        routine = coroutine.create(func);
        filter = nil;
        dead = false;
    };

    return self;
end

---@param functions function[]
---@return Concurrent.Thread[]
local function createThreads(functions)
    local threads = {}
    for index, func in ipairs(functions) do
        if type(func) ~= "function" then
            error("bad argument #" .. index .. " (function expected, got " .. type(func) .. ")", 3)
        end

        table.insert(threads, newThread(func));
    end

    return threads
end

---@param threads Concurrent.Thread[]
---@param ensure integer
---@param terminateHandler? fun(): boolean A handler for the `terminate` event, should return whether to ignore the event for all other coroutines
local function runThreadsLimit(threads, ensure, terminateHandler)
    if (#threads < 1) then return 0; end
    local finished = 0;

    local event = { n = 0 };
    local ignoreTerminate = false;
    while true do
        for index, thread in ipairs(threads) do
            local shouldResume = not thread.dead and (thread.filter == nil or thread.filter == event[1] or event[1] == "terminate");
            if (shouldResume) then
                local args = event;
                if (event[1] == "terminate" and ignoreTerminate) then
                    args = { n = 0 };
                end
                local success, param = coroutine.resume(thread.routine, table.unpack(args, 1, args.n));

                if (not success) then error(param, 0) end
                
                if (coroutine.status(thread.routine) == "dead") then
                    thread.dead = true;
                    finished = finished + 1;
                    if (finished >= ensure) then return end
                end
                thread.filter = param;
            end
        end

        event = table.pack(os.pullEventRaw())
        if (terminateHandler ~= nil and event[1] == "terminate") then ignoreTerminate = terminateHandler(); end
    end
end

function Concurrent.options(terminateHandler, tasks)
    ---@class Concurrent.Options
    local self = {
        terminateHandler = terminateHandler;
        tasks = tasks;
    };

    return self;
end

---@param options Concurrent.Options
function Concurrent.awaitAll(options)
    local threads = createThreads(options.tasks);
    runThreadsLimit(threads, #threads, options.terminateHandler);
end

---@param options Concurrent.Options
function Concurrent.awaitAny(options)
    local threads = createThreads(options.tasks);
    runThreadsLimit(threads, 1, options.terminateHandler);
end

return Concurrent;