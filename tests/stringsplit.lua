local String = require "lib.String"


local function test(tab, expected)
    for i, v in ipairs(tab) do
        assert(expected[i] == v, "failed v at " .. i .. " was not the same!");
    end
end

test(String.split("A--B", "--"), {"A", "B"});
test(String.split("--B", "--"), {"B"});
test(String.split("A--B--C", "--"), {"A", "B", "C"});
test(String.split("A-B--C", "--"), {"A-B", "C"});
test(String.split("--A-B--C", "--"), {"A-B", "C"});

test(String.split("A--B", "--", true), {"A", "--", "B"});
test(String.split("--B", "--", true), {"--","B"});
test(String.split("A--B--C", "--", true), {"A", "--", "B", "--", "C"});
test(String.split("A-B--C", "--", true), {"A-B", "--", "C"});
test(String.split("--A-B--C", "--", true), {"--", "A-B", "--", "C"});

print("all tests passed");