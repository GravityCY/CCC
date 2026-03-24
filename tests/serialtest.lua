local HashMap = require("lib.structs.HashMap");
local Serial = require("lib.Serial");

local data = Serial.new("mobsorter_vjunction"):auto();

---@type HashMap<string, string>
local chambers = nil;

data:serializer(Serial.Codec.new()
    :setPredicate(function(v) return HashMap.instanceof(v) end)
    :setConverter(function(v) return {__name="hashmap", entries=data:toSerializable(v.data.map)} end)
);

data:deserializer(Serial.Codec.new()
    :setPredicate(function(v) return type(v) == "table" and v.__name == "hashmap" end)
    :setConverter(function(v)
        local map = HashMap.new();
        for key, value in pairs(v.entries) do
            map:put(key, value);
        end
        return map
     end)
);

data:load();

local function setup()
    ---@type KeyValue[]
    local chambersData = data:get("chambers");
    if (data:exists("chambers")) then
        chambers = data:get("chambers");
        print("loaded chambers");
        for _, entry in ipairs(chambers:toArray()) do
            print(entry.key .. ": " .. entry.value);
        end
    else
        ---@type HashMap<string, string>
        chambers = HashMap.new();

        chambers:put("key", "value")
        chambers:put("key1", "value1")
        chambers:put("key2", "value2")
        
        data:set("chambers", chambers);
        print("saved chambers");
    end
end

setup();