local EasyAddress = require("lib.EasyAddress");
local Ask = require("lib.Ask");

local function awaitModem(message, type, min, max)
    print(message);
    local addrs = EasyAddress.awaitModem();
    local new = {};
    if (type ~= nil) then
        for _, addr in ipairs(addrs) do
            if (peripheral.getType(addr) == type) then
                table.insert(new, addr);
            end
        end
    end

    min = min or 1;
    max = max or 1;

    assert(#new ~=0, "addresses were 0?");

    if (#new == 1) then
        return new[1];
    else
        local selections = Ask.choose("Please choose " .. tostring(min), {byIndex=new, min=min, max=max});
        if (max == 1) then return selections[1].value; end
        local out = {};
        for _, selection in ipairs(selections) do
            table.insert(out, addrs[selection.index]);
        end
        return out;
    end
end

for i = 1, 100 do
    awaitModem("message", "redstone_relay");
end