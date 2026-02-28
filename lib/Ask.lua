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
--- @param options Options|nil
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

return Ask;