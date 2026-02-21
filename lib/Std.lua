local Std = {};

function Std.getDataDirectory(namespace)
    if (namespace == nil) then return "/data"; end
    return "/data/" .. namespace .. "/";
end

function Std.getAndMakeDirectory(namespace)
    local ret = Std.getDataDirectory(namespace);
    if (not fs.exists(ret)) then fs.makeDir(ret); end
    return ret;
end

return Std;