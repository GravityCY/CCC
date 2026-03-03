--- Title: Helper
--- Description: A general utility library.
--- Version: 0.4.0

local Helper = {};
local executeLimit = 128;

function Helper.toBool(string, tru, fals)
    tru = Helper._def(tru, "true");
    fals = Helper._def(fals, "false");

    if (string == tru) then return true;
    elseif (string == fals) then return false; end
end

--- <b>Pulls multiple of the same event.</b> <br>
--- Example: A `peripheral` event but with multiple peripherals on the same modem, this will return all of them.
---@param name string Event
---@return any[][] args The arguments received from each of the events
function Helper.pullRepeat(name)
    local ret = {};
    local queued = false;

    while true do
        local args = {os.pullEvent()};
        local event = args[1];
        if (event == "helper_event") then break
        elseif (event == name) then
            if (not queued) then
                queued = true;
                os.queueEvent("helper_event");
            end
            table.insert(ret, args);
        end
    end
    return ret;
end

--- <b>Pulls multpiple events.</b>
---@param ... string Event
---@return string
---@return table
function Helper.pullMultiple(...)
    local eventList = {...};
    local eventMap = {};
    local current = nil;
    local queued = false;
    local ret = {};

    for _, v in ipairs(eventList) do
        eventMap[v] = true;
    end

    while true do
        local args = {os.pullEvent()};
        local event = args[1];
        if (event == "helper_event") then break
        elseif (event == current or eventMap[event] ~= nil) then
            if (not queued) then
                current = event;
                os.queueEvent("helper_event");
                queued = true;
            end
            table.insert(ret, args);
        end
    end
    return current, ret;
end

function Helper.pullAny(...)
    local eventList = {...};
    local eventMap = {};

    for _, v in ipairs(eventList) do
        eventMap[v] = true;
    end

    while true do
        local args = {os.pullEvent()};
        if (eventMap[args[1]] ~= nil) then
            return table.unpack(args);
        end
    end
end

--- <b>Execute a table of functions in batches</b>
---@param funcList function[]
---@param skipPartial? boolean Only do complete batches and skip the remainder.
---@return function[] skipped Functions that were skipped as they didn't fit.
function Helper.batchExecute(funcList, skipPartial, limit)
    if (skipPartial == nil) then skipPartial = false; end
    if (limit == nil) then limit = executeLimit; end

    local batches = #funcList / limit
    if (skipPartial) then batches = math.floor(batches);
    else batches = math.ceil(batches); end

    for batch = 1, batches do
      local start = ((batch - 1) * limit) + 1
      local batch_end = math.min(start + limit - 1, #funcList)
      parallel.waitForAll(unpack(funcList, start, batch_end))
    end
    return {unpack(funcList, 1 + limit * batches)};
end

--- <b>Wait for all functions to finish.</b>
---@param tab table List of objects to wait for.
---@param fnGetter function A function receiving objects from the table and returning a function.
function Helper.waitForAllTab(tab, fnGetter)
    local fns = {};
    for _, v in ipairs(tab) do
        table.insert(fns, fnGetter(v));
    end
    parallel.waitForAll(table.unpack(fns));
end

--- <b>Wait for all functions to finish.</b>
---@param from any
---@param to any
---@param fnGetter any
function Helper.waitForAllIt(from, to, fnGetter)
    local fns = {};
    for i = from, to do
        table.insert(fns, fnGetter(i));
    end
    parallel.waitForAll(table.unpack(fns));
end

--- <b>Check if a program is run from shell or from `require`.</b>
---@param args table Arguments passed to the program from `{...}`.
---@return boolean required Whether the program was run from `require`.
function Helper.isRequired(args)
    return #args == 2 and type(package.loaded[args[1]]) == "table" and not next(package.loaded[args[1]]);
end

--- <b>Repeats a function a number of times.</b>
---@param times integer
---@param fn function
---@param ... any
function Helper.rep(times, fn, ...)
    for i = 1, times do fn(...); end
end

function Helper.addToString(str, add, findPattern)
    local start = str:find(findPattern);
    return str:sub(1, start - 1) .. add .. str:sub(start);
end

--- <b>Returns the string before an index.</b> <br>
--- Example: `Helper.getBeforeIndex("hello...world", 5)` will return `"hello"`
---@param str string
---@param index integer
---@return string
function Helper.getBeforeIndex(str, index)
    return str:sub(1, index - 1);
end

--- <b>Returns the string after an index.</b> <br>
--- Example: `Helper.getAfterIndex("hello...world", 5)` will return `"...world"`
---@param str string
---@param index integer
---@return string
function Helper.getAfterIndex(str, index)
    return str:sub(index + 1);
end

--- <b>Returns the string before the first pattern.</b>
---@param str string
---@param findPattern string
---@return string|nil
function Helper.getBeforePattern(str, findPattern)
    local startIndex = str:find(findPattern);
    if (startIndex == nil) then return nil; end

    return Helper.getBeforeIndex(str, startIndex);
end

--- <b>Returns the string after the first pattern.</b>
---@param str string
---@param findPattern string
---@return string|nil
function Helper.getAfterPattern(str, findPattern)
    local _, endIndex = str:find(findPattern);
    if (endIndex == nil) then return nil; end

    return Helper.getAfterIndex(str, endIndex);
end

--- <b>Splits a string in two using an index.</b> <br>
--- Example: `Helper.splitIndex("hello...world", 6, 8)` will return `"hello", "world"`
---@param str string
---@param startIndex integer
---@param endIndex integer|nil
---@return string
---@return string
function Helper.splitIndex(str, startIndex, endIndex)
    if (endIndex == nil) then endIndex = startIndex; end
    return Helper.getBeforeIndex(str, startIndex), Helper.getAfterIndex(str, endIndex);
end

--- <b>Splits a string in two using a pattern.</b> <br>
--- Example: `Helper.splitPattern("hello...world", "%.%.%.")` will return `"hello", "world"`
---@param str string
---@param findPattern string
---@return string|nil
---@return string|nil
function Helper.splitPattern(str, findPattern)
    local startIndex, endIndex = str:find(findPattern);
    if (startIndex == nil or endIndex == nil) then return nil; end

    return Helper.splitIndex(str, startIndex, endIndex);
end

--- <b>Iterates from start to finish (works with going from larger to smaller).</b>
---@param from number
---@param to number
---@return function
function Helper.iterate(from, to)
    local index = from;

    local up = from < to;
    local delta = Helper._if(up, 1, -1);
    local endIndex = Helper._if(up, to + 1, to - 1);
    return function()
        if (index == endIndex) then return nil; end

        local current = index;
        index = index + delta;
        return current;
    end
end

--- <b>Returns an iterator that iterates throughout a table.</b>
---@param t table
---@return function
function Helper.ipairs(t)
    return Helper.iterate(1, #t);
end

--- <b>Returns the minimum value.</b>
---@param ... number
---@return number min The minimum value
function Helper.min(...)
    local ret = math.huge;
    for _, v in ipairs({...}) do
        if (v < ret) then ret = v; end
    end
    return ret;
end

--- <b>Returns the maximum value.</b>
---@param ... number
---@return number max The maximum value
function Helper.max(...)
    local ret = -math.huge;
    for _, v in ipairs({...}) do
        if (v > ret) then ret = v; end
    end
    return ret;
end

--- <b>Saves a table to a JSON file.</b>
---@param path string
---@param tab table
function Helper.saveJSON(path, tab)
    local serialized = textutils.serialiseJSON(tab);
    local file = fs.open(path, "w");
    file.write(serialized);
    file.close();
end

--- <b>Loads a table from a JSON file.</b>
---@param path string
---@return table|nil
function Helper.loadJSON(path)
    if (not fs.exists(path)) then return; end
    local file = fs.open(path, "r");
    local unserialised = file.readAll();
    file.close();
    return textutils.unserialiseJSON(unserialised);
end

--- <b>Writes a string to a file.</b>
---@param path string
---@param str string
function Helper.save(path, str)
    local file = fs.open(path, "w");
    file.write(str);
    file.close();
end

--- <b>Writes a string to a file.</b>
---@param path string
function Helper.load(path)
    if (not fs.exists(path)) then return; end
    local file = fs.open(path, "r");
    local str = file.readAll();
    file.close();
    return str;
end

--- <b>Serializes a table to a file.</b>
---@param path string
---@param tab table
function Helper.serialize(path, tab)
    local serialized = textutils.serialize(tab);
    local file = fs.open(path, "w");
    file.write(serialized);
    file.close();
end

--- <b>Loads a table from a file.</b>
---@param path string
---@return table|nil
function Helper.deserialize(path)
    if (not fs.exists(path)) then return; end
    local file = fs.open(path, "r");
    local unserialised = file.readAll();
    file.close();
    return textutils.unserialise(unserialised);
end

--- <b>A way to return a default value, if the given value is nil.</b>
---@param value any
---@param defValue any
---@return any
function Helper._def(value, defValue)
    if (value == nil) then return defValue; end
    return value;
end

--- <b>Simplified if else statement.</b>
---@param exp boolean
---@param a any
---@param b any
---@return any
function Helper._if(exp, a, b)
    if (exp) then return a;
    else return b; end
end

--- <b>Simplifies accessing an assumed table by nil checking</b>
--- ```lua
--- if (tab == nil) then return nil; end 
--- return tab[key];
--- ```
---@param tab table|nil
---@param key any
---@return any|nil
function Helper._gnil(tab, key)
    if (tab == nil) then return nil; end
    return tab[key];
end

--- <b>Creates an array of arrays.</b>
---@param size any
---@return table
function Helper._arr(size)
    local ret = {};
    for i = 1, size do
        ret[i] = {};
    end
    return ret;
end


return Helper;