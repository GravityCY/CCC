local Peripheral = require("lib.Peripheral");

local SerializersLib = {};

local Serializers = {};
local Deserializers = {};

SerializersLib.Serializers = Serializers;
SerializersLib.Deserializers = Deserializers;

function Serializers.isPeripheral(v)
    return Peripheral.isPeripheral(v);
end

function Deserializers.isPeripheral(v)
    return type(v) == "table" and v.__name == "peripheral";
end

function Serializers.peripheral(v)
    return {__name="peripheral", address=peripheral.getName(v)};
end

function Deserializers.peripheral(v)
    return peripheral.wrap(v.address);
end

return SerializersLib;