local Math = {};

--- Converts a 3 dimensional coordinate to a 1d index<br>
--- The order is X -> Z -> Y!
---@param x integer
---@param y integer
---@param z integer
---@param xs integer
---@param ys integer
---@param zs integer
function Math.get3D1D(x, y, z, xs, ys, zs)
    return (z - 1) * xs + (y - 1) * zs * xs + x
end

--- Converts an array index to a 3d coordinate<br>
--- Expects the order to be X -> Z -> Y
---@param i integer
---@param xs integer
---@param ys integer
---@param zs integer
function Math.get1D3D(i, xs, ys, zs)
    local xz = xs * zs;

    local i0 = i - 1;

    local y = math.floor(i0 / xz) + 1;
    local z = math.floor(i0 / xs) % zs + 1;
    local x = i0 % xs + 1;

    return x, y, z;
end

return Math;