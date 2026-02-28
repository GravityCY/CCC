local Table = {};

function Table.copy(tab)
    local out = {};

    for k, v in pairs(tab) do
        out[k] = v;
    end

    return out;
end

function Table.deepCopy(tab)
    local out = {};

    for k, v in pairs(tab) do
        local t = type(v);
        if (t == "table") then
            out[k] = Table.deepCopy(tab);
        elseif (t ~= "function") then
            out[k] = v;
        end
    end

    return out;
end

return Table;