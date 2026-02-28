---@class Recipe
local Recipe = {};
Recipe.__index = Recipe;

function Recipe.new(id)
    ---@class Recipe
    local self = {
        data = {
            ---@type string
            name = id,
            ---@type string[]
            shape = {},
            ---@type string
            processorId = nil,
            ---@type table<string, number>
            materials = {},
            outputAmount = 1,
            shaped = false,
            craftMax = 64,
            ---@type table<string, number>
            leftovers = {}
        }
    };

    return setmetatable(self, Recipe);
end

function Recipe:setOutputAmount(var)
    self.data.outputAmount = var;
    return self;
end

---@param shape string[]
---@return Recipe
function Recipe:setShape(shape)
    self.data.shape = shape;
    self.data.shaped = true;

    for slot, item in pairs(self.data.shape) do
        self.data.materials[item] = (self.data.materials[item] or 0) + 1;
    end

    return self;
end

---@param materials table<string, number>
---@return Recipe
function Recipe:setMaterials(materials)
    self.data.materials = materials;
    return self;
end

---@param value number
---@return Recipe
function Recipe:setCraftMax(value)
    self.data.craftMax = value;
    return self;
end

---@param var table<string, number>
---@return Recipe
function Recipe:setLeftovers(var)
    self.data.leftovers = var;
    return self;
end

---@param processor string
---@return Recipe
function Recipe:setProcessor(processor)
    self.data.processorId = processor;
    return self;
end

return Recipe;