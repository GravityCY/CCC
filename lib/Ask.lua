local Ask = {};

---@class Options
local Options = {};

---@return Options
function Ask.options()
    ---@class Options
    local self = {
        ---@class OptionData
        data = {
            ---@type any
            blankDefault = nil,
            ---@type boolean
            allowBlank = false
        }
    };

    return setmetatable(self, {__index = Options});
end

function Options:allowBlank(blankDefault)
    self.data.allowBlank = true;
    self.data.blankDefault = blankDefault;
    return self;
end

---@class BoolOptions : Options
local BoolOptions = setmetatable({}, {__index = Options});

---@return BoolOptions
local function newBoolOptions()
    ---@class BoolOptions
    local bool = {
        ---@class BoolOptionData : OptionData
        data = {
            bool = {
                ---@type string
                truePattern = nil,
                ---@type string
                falsePattern = nil,
            }
        }
    };

    local self = Ask.options();
    ---@cast self BoolOptions

    self.data.bool = bool.data.bool;

    return setmetatable(self, {__index = BoolOptions});
end

function BoolOptions:truePattern(pattern)
    self.data.bool.truePattern = pattern;
    return self;
end

function BoolOptions:falsePattern(pattern)
    self.data.bool.falsePattern = pattern;
    return self;
end

---@class NumOptions : Options
local NumOptions = setmetatable({}, {__index = Options});

local function newNumOptions()
    ---@class NumOptions
    local num = {
        ---@class NumOptionData : OptionData
        data = {
            num = {
                ---@type number
                min = nil,
                ---@type number
                max = nil,
            }
        }
    }

    local self = Ask.options();
    ---@cast self NumOptions
    self.data.num = num.data.num;

    return setmetatable(self, {__index = NumOptions});
end

function NumOptions:min(min)
    self.data.num.min = min;
    return self;
end

function NumOptions:max(max)
    self.data.num.max = max;
    return self;
end

function Ask.bool(trueStr, falseStr)
    return newBoolOptions()
        :truePattern(trueStr)
        :falsePattern(falseStr);
end

function Ask.trueFalse()
    return newBoolOptions();
end

function Ask.onOff()
    return newBoolOptions()
        :truePattern("on")
        :falsePattern("off");
end

function Ask.yesNo(full)
    return newBoolOptions()
        :truePattern((full and "yes") or "y")
        :falsePattern((full and "no") or "n");
end

function Ask.num(min, max)
    return newNumOptions()
        :min(min)
        :max(max);
end

--- @param question string
--- @param options? Options
--- @return any
function Ask.ask(question, options)
    options = options or {};

    local allowBlank = options.data.allowBlank or options.data.blankDefault ~= nil;

    while true do
        write(question);
        local res = read();
        local isBlank = res == nil or res == "";
        if (options.data.num ~= nil) then
            ---@cast options NumOptions
            local num = tonumber(res);
            if (num ~= nil) then
                if (options.data.num.min ~= nil and num < options.data.num.min) then
                    print("Outside range: " .. options.data.num.min .. "-" .. options.data.num.max);
                elseif (options.data.num.max ~= nil and num > options.data.num.max) then
                    print("Outside range: " .. options.data.num.min .. "-" .. options.data.num.max);
                else
                    return num;
                end
            elseif (allowBlank and isBlank) then
                return options.data.blankDefault;
            end
                
        elseif (options.data.bool ~= nil) then
            ---@cast options BoolOptions
            if (res == options.data.bool.truePattern) then
                return true;
            elseif (res == options.data.bool.falsePattern) then
                return false;
            elseif (allowBlank and isBlank) then
                return options.data.blankDefault;
            else
                print(("Type either '%s' or '%s'"):format(options.data.bool.truePattern, options.data.bool.falsePattern));
            end

        elseif (allowBlank and isBlank) then
            return options.data.blankDefault;
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
    sy = sy - overflow;

    while true do
        for i, choice in ipairs(choices) do
            term.setCursorPos(1, sy + i - 1);
            local s = "  ";
            if (i == selected) then s = "> " end
            write(s .. i .. ": " .. choice);
        end

        local _, key = os.pullEvent("key");
        local newSelection = nil;
        if (key == keys.up) then
            local zeroBased = selected - 1;
            zeroBased = (zeroBased - 1) % #choices;
            selected = zeroBased + 1;
        elseif (key == keys.down) then
            local zeroBased = selected - 1;
            zeroBased = (zeroBased + 1) % #choices;
            selected = zeroBased + 1;
        elseif (key == keys.enter) then
            return selected, choices[selected];
        end

        if (key == keys.up or key == keys.down) then
            term.clearLine();
            term.setCursorPos(1, sy + selected - 1);
            term.clearLine();
        end
    end
end

return Ask;