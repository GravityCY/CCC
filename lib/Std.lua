local Std = {};

function Std.getDataDirectory(...)
    local args = {...};
    local path = table.concat(args, "/");

    if (path == nil) then return "/data"; end
    return "/data/" .. path;
end

function Std.getAndMakeDirectory(...)
    local ret = Std.getDataDirectory(...);
    if (not fs.exists(ret)) then fs.makeDir(ret); end
    return ret;
end

return Std;