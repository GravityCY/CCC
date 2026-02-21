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

function String.split(str, separator)
    local tab = {};

    if (separator == nil or separator == " ") then separator = "%s"; end
    for s in string.gmatch(str, "[^" .. separator .. "]+") do
        table.insert(tab, s);
    end
    return tab;
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