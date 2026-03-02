local Ask = {};

function Ask.onOff()
    return Ask.bool("on", "off");
end

function Ask.yesNo(full)
    return Ask.bool((full and "yes") or "y", (full and "no") or "n");
end

function Ask.trueFalse()
    return Ask.bool("true", "false");
end

function Ask.bool(trueStr, falseStr)
    return {
        bool = {
            truePattern = trueStr,
            falsePattern = falseStr
        }
    };
end

function Ask.num(min, max)
    return {
        num={
            min=min,
            max=max
        }
    };
end

---@class Options
---@field num NumOptions
---@field bool BoolOptions

---@class NumOptions
---@field min number
---@field max number

---@class BoolOptions
---@field truePattern string
---@field falsePattern string

--- @param question string
--- @param options? Options
--- @return string|number|boolean
function Ask.ask(question, options)
    options = options or {};

    while true do
        write(question);
        local res = read();
        if (options.num ~= nil) then
            res = tonumber(res);
            if (res ~= nil) then
                if (options.num.min ~= nil and res < options.num.min) then
                    print("Outside range: " .. options.num.min .. "-" .. options.num.max);
                elseif (options.num.max ~= nil and res > options.num.max) then
                    print("Outside range: " .. options.num.min .. "-" .. options.num.max);
                else
                    return res;
                end
            end
        elseif (options.bool ~= nil) then
            if (res == options.bool.truePattern) then
                return true;
            elseif (res == options.bool.falsePattern) then
                return false;
            else
                print(("Type either '%s' or '%s'"):format(options.bool.truePattern, options.bool.falsePattern));
            end
        else
            return res;
        end
    end
end

---@class ChooseOptions
---@field byIndex string[]?
---@field byKey table<string, any>?
---@field byValue table<any, string>?

---@param message string
---@param options ChooseOptions
---@return number, string
function Ask.choose(message, options)
    local choices = {};

    if (options.byIndex ~= nil) then
        choices = options.byIndex
    elseif (options.byKey ~= nil) then
        for key in pairs(options.byKey) do
            table.insert(choices, tostring(key));
        end
    elseif (options.byValue ~= nil) then
        for _, value in pairs(options.byValue) do
            table.insert(choices, tostring(value));
        end
    else
        error("didnt pass anything")
    end

    ---@cast choices string[]

    local selected = 1;

    local sx, sy = term.getCursorPos();
    local w, h = term.getSize();

    print(message);

    local overflow = sy + #choices - h;
    if (overflow > 0) then term.scroll(overflow); end

    while true do
        for i, choice in ipairs(choices) do
            term.setCursorPos(1, sy + i - 1 - overflow);
            local s = "  ";
            if (i == selected) then s = "> " end
            write(s .. i .. ": " .. choice);
        end

        local _, key = os.pullEvent("key");
        if (key == keys.up) then
            term.clearLine();
            local zeroBased = selected - 1;
            zeroBased = (zeroBased - 1) % #choices;
            selected = zeroBased + 1;
            term.setCursorPos(1, sy + selected - 1);
            term.clearLine();
        elseif (key == keys.down) then
            term.clearLine();
            local zeroBased = selected - 1;
            zeroBased = (zeroBased + 1) % #choices;
            selected = zeroBased + 1;
            term.setCursorPos(1, sy + selected - 1);
            term.clearLine();
        elseif (key == keys.enter) then
            return selected, choices[selected];
        end
    end
end

return Ask;