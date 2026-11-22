-- Every campaign level must: have valid geometry, a reference solution that fits the budget and the
-- building rules, let the truck (3 stars) reach point B with that solution, fail with no bridge,
-- and (for portal levels) pass every declared portal. At least one level must have three portals.
local levels = require("game.levels.levels")
local check = require("level_check")

local failures = {}
local max_portals = 0
for _, lvl in ipairs(levels.list) do
	local rep = check.check(lvl, { vehicles = { "truck" } })
	for _, e in ipairs(rep.errors) do failures[#failures + 1] = lvl.id .. ": " .. e end
	if rep.results.truck ~= "won" then failures[#failures + 1] = lvl.id .. ": truck does not reach point B" end
	if rep.empty == "won" then failures[#failures + 1] = lvl.id .. ": level is passable without building" end
	local declared = lvl.portals and #lvl.portals or 0
	if declared > max_portals then max_portals = declared end
	if declared > 0 and (rep.portals or 0) < declared then
		failures[#failures + 1] = string.format("%s: reference solution used %d/%d portals", lvl.id, rep.portals or 0, declared)
	end
end
assert(levels.COUNT == 160, "expected 160 levels, got " .. levels.COUNT)
assert(max_portals >= 3, "no level can earn Quantum Leap (3 portals in one run)")
if #failures > 0 then error("\n" .. table.concat(failures, "\n")) end
