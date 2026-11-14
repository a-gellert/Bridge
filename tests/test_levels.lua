-- Every campaign level must: have valid geometry, a reference solution that fits the budget and the
-- building rules, let the truck (3 stars) reach point B with that solution, and fail with no bridge.
local levels = require("game.levels.levels")
local check = require("level_check")

local failures = {}
for _, lvl in ipairs(levels.list) do
	local rep = check.check(lvl, { vehicles = { "truck" } })
	for _, e in ipairs(rep.errors) do failures[#failures + 1] = lvl.id .. ": " .. e end
	if rep.results.truck ~= "won" then failures[#failures + 1] = lvl.id .. ": truck does not reach point B" end
	if rep.empty == "won" then failures[#failures + 1] = lvl.id .. ": level is passable without building" end
end
assert(levels.COUNT == 24, "expected 24 levels, got " .. levels.COUNT)
if #failures > 0 then error("\n" .. table.concat(failures, "\n")) end
