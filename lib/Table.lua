local Helper = require("lib.Helper");

local Table = {};

function Table.toString(tab, separator)
    separator = separator or " ";

    local ret = tostring(tab[1]);
    for i = 2, #tab do
        ret = ret .. separator .. tostring(tab[i]);
    end
    return ret;
end

--- Gets the difference between 2 tables
---@param tab1 any[]
---@param tab2 any[]
---@param diffFn fun(a: any, b: any): boolean
---@return table
function Table.diffIpairs(tab1, tab2, diffFn)
    local ret = {};
    ret.indexDiff = {};
    ret.sizeDiff = #tab2 - #tab1;

    for i = 1, #tab1 do
        if (diffFn(tab1[i], tab2[i])) then
            table.insert(ret, i);
        end
    end

    ret.different = ret.sizeDiff ~= 0 or #ret.indexDiff ~= 0;
    return ret;
end

--- <b>Gets a range of a table.</b>
---@param tab any[]
---@param start number|nil
---@param stop number|nil
---@return table
function Table.range(tab, start, stop)
    start = start or 1;
    stop = stop or #tab;

    local out = {};
    for i = start, stop do
        table.insert(out, tab[i]);
    end
    return out;
end

--- <b>Deep Copies a table.</b>
---@param tab table
---@return table
function Table.deepCopy(tab)
    local ret = {};
    for k, v in pairs(tab) do
        local t = type(v);
        if (t == "table") then
            ret[k] = Table.deepCopy(v);
        else
            ret[k] = v;
        end
    end
    return ret;
end

--- <b>Gets the index of a value in a table.</b>
---@param tab any[]
---@param value any
---@return number
function Table.indexOf(tab, value)
    for i, v in ipairs(tab) do
        if (v == value) then return i; end
    end
    return -1;
end

--- <b>Copies a table to another table while keeping the same table pointer.</b> <br>
--- `Helper.set({1, 2, 3}, {"some", 1, "other", "stuff")` = {1, 2, 3}
---@param fromTab table
---@param toTab table
function Table.copyFrom(fromTab, toTab)
    local toRemove = {};
    for k, v in pairs(toTab) do
        toRemove[k] = true;
    end
    for k, _ in pairs(toRemove) do
        toTab[k] = nil;
    end
    for k, v in pairs(fromTab) do
        toTab[k] = v;
    end
end

--- <b>Checks if a table contains a value.</b>
---@param tab any[]
---@param value any
---@return boolean
function Table.contains(tab, value)
    return Table.indexOf(tab, value) ~= -1;
end

--- <b>Removes the first occurrence of a value in a list.</b>
---@param tab any[]
---@param v any
---@return any
function Table.remove(tab, v)
    local index = Table.indexOf(tab, v);
    if (index == nil) then return end
    return table.remove(tab, index);
end

--- <b>Adds a value to a list.</b>
---@param list any[]
---@param value any
---@param allowDupes boolean? Whether to allow duplicate values
---@return boolean success Whether the value was added
function Table.add(list, value, allowDupes)
    allowDupes = Helper._def(allowDupes, false);

    if (allowDupes) then
        table.insert(list, value);
        return true;
    else
        if (not Table.contains(list, value)) then
            table.insert(list, value);
            return true;
        else
            return false;
        end
    end
end

--- <b>Sets a table to another table while keeping the same table pointer.</b> <br>
--- `Helper.set({1, 2, 3}, {"some", 1, "other", "stuff")` = {1, 2, 3}
---@param fromTab table
---@param toTab table
function Table.set(fromTab, toTab)
    local toRemove = {};
    for k, v in pairs(toTab) do
        toRemove[k] = true;
    end
    for k, _ in pairs(toRemove) do
        toTab[k] = nil;
    end
    for k, v in pairs(fromTab) do
        toTab[k] = v;
    end
end

function Table.concat(tab1, tab2)
    for _, v in ipairs(tab2) do
        table.insert(tab1, v);
    end
end

--- [1, 2, 3, 4] shift by 1
--- [nil, 1, 3, 4]
--- [nil, 1, 2, 4]
--- [nil, 1, 2, 3]
--- [4, 1, 2, 3]
function Table.shift(tab, size, amount)
    amount = amount % size;
    if (amount == 0) then return end

    local moved = 0;
    local start = 1;
    while (moved < size) do
        local next = (start + amount - 1) % size + 1;
        local prev = tab[start];
        while (next ~= start) do
            local temp = tab[next];
            tab[next] = prev;
            prev = temp;
            next = (next + amount - 1) % size + 1;
            moved = moved + 1;
        end
        tab[start] = prev;
        moved = moved + 1;
        start = start + 1;
    end
end

return Table;