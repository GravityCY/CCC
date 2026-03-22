local Peripheral = require("lib.Peripheral");

local RailLib = {};

---@class Rail
local Rail = {};
Rail.__name = "Rail";
Rail.__index = Rail;

function RailLib.class()
    return Rail;
end

function RailLib.wrap(obj)
    local periph = Peripheral.asPeripheral(obj);
    assert(periph ~= nil, "periph is nil");
    
    ---@class Rail
    local self = {
        data = {
            rail = obj;
        }
    };

    return setmetatable(self, Rail);
end

function Rail:getMinecarts()
    return self.data.rail.getMinecarts();
end

---@return string, any[]
function Rail:awaitMinecart(lastUuid, timeout)
    timeout = timeout or math.huge;

    local start = os.clock();
    while ((os.clock() - start) < timeout) do
        local minecarts = self.data.rail.getMinecarts();
        
        local minecart = minecarts[1];
        if (minecart and minecart.uuid ~= lastUuid) then return minecart.uuid, minecarts; end
    end
end

Rail.__construct = RailLib.wrap;
return RailLib;