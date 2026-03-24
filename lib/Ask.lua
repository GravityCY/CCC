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
    options = options or Ask.options();

    local allowBlank = options.data.allowBlank or options.data.blankDefault ~= nil;

    while true do
        write(question);
        local res = read();
        local isBlank = res == nil or res == "";
        
        ---@diagnostic disable-next-line: undefined-field
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
                
        ---@diagnostic disable-next-line: undefined-field
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
---@field min integer?
---@field max integer?

---@param message string
---@param options ChooseOptions
---@return table
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

    options.min = options.min or 0;
    options.max = options.max or #choices;

    ---@cast choices string[]

    table.insert(choices, "Done");

    local cursor = 1;
    
    local selectionsSet = {};
    local selected = 0;

    local sx, sy = term.getCursorPos();
    local w, h = term.getSize();

    print(message);

    local total = #choices;
    local overflow = sy + total - h;
    if (overflow > 0) then term.scroll(overflow); end
    sy = sy - overflow;

    local errorMessage = nil;

    while true do
        for i, choice in ipairs(choices) do
            term.setCursorPos(1, sy + i - 1);
            term.clearLine();
            local prefix = " ";
            local postfix = "";
            if (i ~= total) then
                if (selectionsSet[i]) then postfix = "*" end
            end
            if (cursor == i) then prefix = "> " end
            local s = prefix..choice..postfix;

            term.write(s);
        end

        term.setCursorPos(1, sy + total);
        term.clearLine();
        if (errorMessage ~= nil) then
            term.write(errorMessage)
            errorMessage = nil;
        end

        local _, key = os.pullEvent("key");
        local newSelection = nil;
        if (key == keys.up) then
            local zeroBased = cursor - 1;
            zeroBased = (zeroBased - 1) % total;
            cursor = zeroBased + 1;
        elseif (key == keys.down) then
            local zeroBased = cursor - 1;
            zeroBased = (zeroBased + 1) % total;
            cursor = zeroBased + 1;
        elseif (key == keys.enter) then
            if (cursor == total) then
                if (selected >= options.min and selected <= options.max) then
                    local out = {};
                    for index in pairs(selectionsSet) do
                        table.insert(out, {index=index, value=choices[index]});
                    end
                    return out;
                else
                    errorMessage = "You must select between " .. options.min .. " and " .. options.max .. " options.";
                end
            else
                local exists = selectionsSet[cursor] ~= nil;
                if (exists) then
                    selected = selected - 1;
                    selectionsSet[cursor] = nil;
                else
                    if (selected < options.max) then
                        selected = selected + 1;
                        selectionsSet[cursor] = true;
                    else
                        errorMessage = "You must select between " .. options.min .. " and " .. options.max .. " options.";
                    end
                end
            end
        end

        if (key == keys.up or key == keys.down) then
            term.setCursorPos(1, sy + cursor - 1);
        end
    end
end

return Ask;