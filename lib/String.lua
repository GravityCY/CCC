local String = {};

function String.format(str, ...)
    return string.format(str, ...); 
end

function String.rep(str, times)
    return string.rep(str, times); 
end

function String.sub(str, startIndex, endIndex)
    return string.sub(str, startIndex, endIndex); 
end

function String.upper(str)
    return string.upper(str);
end

function String.lower(str)
    return string.lower(str);
end

function String.reverse(str)
    return string.reverse(str);
end

function String.replace(str, find, replace)
    return string.gsub(str, find, replace);
end

function String.trim(str)
    return string.gsub(str, "^%s*(.-)%s*$", "%1");
end

---@param str string
---@param match string
function String.startsWith(str, match)
    if (#str < #match) then return false; end

    for i = 1, #match do
        local c = str:sub(i, i);
        if (c ~= match:sub(i, i)) then return false; end
    end
    return true;
end

--- Hello to the world, to -> ["Hello ", " the world"]
function String.split(str, separator, keepSeparator)
    assert(separator ~= "", "separator is empty?");
    if (keepSeparator == nil) then keepSeparator = false; end

    local split = {};
    local current = {};
    local check = {};
    
    for i = 1, #str do
        local c = str:sub(i, i);
        local sc = separator:sub(#check + 1, #check + 1);

        if (c == sc) then
            table.insert(check, c);

            if (#check == #separator) then
                if (#current ~= 0) then
                    table.insert(split, table.concat(current));
                end

                if (keepSeparator) then
                    table.insert(split, table.concat(check));
                end

                current = {};
                check = {};
            end
        else
            if (#check ~= 0) then
                table.insert(current, table.concat(check))
                check = {};
            end

            table.insert(current, c);
        end
    end

    if (#current ~= 0) then
        table.insert(split, table.concat(current))
    end

    if (#check ~= 0) then
        table.insert(split, table.concat(check));
    end

    return split;
end

--- <b>Wraps a string to a certain length.</b>
---@param str string String to wrap.
---@param len integer Length to wrap to.
---@return string[]
function String.wrap(str, len)
    local lines = {};
    local index = 1;

    for word in str:gmatch("%w+") do
        local line = lines[index] or "";

        if (#line + #word + 1 > len) then
            index = index + 1;
            line = "";
        end

        if (line ~= "") then line = line .. " "; end
        lines[index] = line .. word;
    end

    return lines
end

function String.toWordCase(str)
    return str:gsub("(%a)(%w*)", function(first, rest) return first:upper() .. rest:lower() end);
end

--- <b>Returns the index of a character in a string.</b>
---@param char string
---@param str string
---@return integer
function String.indexOf(char, str)
    for i = 1, #str do
        local tempChar = str:sub(i, i);
        if (tempChar == char) then return i end
    end
    return -1
end

--- <b>Returns the last index of a character in a string.</b>
---@param char string
---@param str string
---@return integer
function String.lastIndexOf(char, str)
    for i = #str, 1, -1 do
        local tempChar = str:sub(i, i);
        if (tempChar == char) then return i end
    end
    return -1;
end

return String;