local AE69 = require("lib.AE69");
local Recipe = AE69.Recipe;

AE69.registerProcessor("furnace", "minecraft:barrel_15", "minecraft:barrel_11");
AE69.registerProcessor("blast_furnace", "minecraft:barrel_17", "minecraft:barrel_16");
AE69.registerProcessor("smoker", "minecraft:barrel_19", "minecraft:barrel_18");

AE69.registerRecipes(
    Recipe.new("computercraft:turtle_normal")
        :setShape({
            [1]="minecraft:iron_ingot", [2]="minecraft:iron_ingot",                 [3]="minecraft:iron_ingot",
            [4]="minecraft:iron_ingot", [5]="computercraft:computer_normal",        [6]="minecraft:iron_ingot",
            [7]="minecraft:iron_ingot", [8]="minecraft:chest",                      [9]="minecraft:iron_ingot"
        }),

    Recipe.new("computercraft:computer_normal")
        :setShape({
            [1]="minecraft:stone",      [2]="minecraft:stone",                      [3]="minecraft:stone",
            [4]="minecraft:stone",      [5]="minecraft:redstone",                   [6]="minecraft:stone",
            [7]="minecraft:stone",      [8]="minecraft:glass_pane",                 [9]="minecraft:stone",
        }),

    Recipe.new("minecraft:chest")
        :setShape({
            [1]="minecraft:oak_planks", [2]="minecraft:oak_planks",                 [3]="minecraft:oak_planks",
            [4]="minecraft:oak_planks",                                             [6]="minecraft:oak_planks",
            [7]="minecraft:oak_planks", [8]="minecraft:oak_planks",                 [9]="minecraft:oak_planks",
        }),

    Recipe.new("minecraft:glass_pane")
        :setShape({
            [1]="minecraft:glass",      [2]="minecraft:glass",                      [3]="minecraft:glass",
            [4]="minecraft:glass",      [5]="minecraft:glass",                      [6]="minecraft:glass",
        })
        :setOutputAmount(16),

    Recipe.new("minecraft:oak_planks")
        :setShape({"minecraft:oak_log"})
        :setOutputAmount(4),

    Recipe.new("minecraft:iron_ingot")
        :setMaterials({
            ["minecraft:raw_iron"]=1
        })
        :setProcessor("blast_furnace"),

    Recipe.new("minecraft:glass")
        :setMaterials({
            ["minecraft:sand"]=1
        })
        :setProcessor("furnace"),

    Recipe.new("minecraft:stone")
        :setMaterials({
            ["minecraft:cobblestone"]=1
        })
        :setProcessor("furnace"),

    Recipe.new("minecraft:cooked_mutton")
        :setMaterials({
            ["minecraft:mutton"]=1
        })
        :setProcessor("smoker"),

    Recipe.new("minecraft:cooked_beef")
        :setMaterials({
            ["minecraft:beef"]=1
        })
        :setProcessor("smoker"),
    
    Recipe.new("minecraft:cooked_porkchop")
        :setMaterials({
            ["minecraft:porkchop"]=1
        })
        :setProcessor("smoker")
        
)

print("Initializing AE69...\n");
AE69.init("minecraft:chest_0");

AE69.stock("minecraft:cooked_mutton", 8);
AE69.stock("minecraft:cooked_beef", 8);
AE69.stock("minecraft:cooked_porkchop", 8);

AE69.stock("minecraft:chest", 64);
AE69.stock("minecraft:glass_pane", 64);
AE69.stock("minecraft:glass", 64);
AE69.stock("minecraft:stone", 64);
AE69.stock("minecraft:iron_ingot", 64);

AE69.stock("computercraft:computer_normal", 4);
AE69.stock("computercraft:turtle_normal", 4);

print("Stockpile List: ")
for name, count in pairs(AE69.getStockpiles()) do
    print(name .. ": " .. count);
end

local function onCraftRoot(name, count)
    print("Queueing " .. count .. " " .. name .. " to be crafted...");
end

AE69.OnCraftRoot:listen(onCraftRoot);

print("Entering stockpile mode...");
while true do
    AE69.poll()
    sleep(1);
end