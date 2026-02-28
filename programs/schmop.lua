local Smopper = require("lib.Schmopper");

Smopper.init("lumberjack");

Smopper.inventory("lumberjack_output")
Smopper.inventory("smelter_input")
Smopper.inventory("smelter_output")
Smopper.inventory("smelter_fuel")
Smopper.inventory("crafter_input")

Smopper.Rule.Export()
    .source("lumberjack_output")
    .targets("smelter_input", "crafter_input")
    .percents(50, 50)
    .tag("minecraft:logs")
    .keep(64)
    .register()

Smopper.Rule.Import()
    .source("smelter_output")
    .target("lumberjack_output")
    .name("minecraft:charcoal")
    .upto(64)
    .register()

Smopper.Rule.Import()
    .target("smelter_fuel")
    .source("smelter_output")
    .name("minecraft:charcoal")
    .upto(64)
    .register()

Smopper.start(1);