-- Every campaign level must: have valid geometry, a reference solution that fits the budget and the
-- building rules, let the truck (3 stars) reach point B with that solution, fail with no bridge,
-- and (for portal levels) pass every declared portal. At least one level must have three portals.
local levels = require("game.levels.levels")
local Blueprint = require("game.bridge.blueprint")
local check = require("level_check")

local failures = {}
local max_portals = 0
local reps = {}
for _, lvl in ipairs(levels.list) do
	local rep = check.check(lvl, { vehicles = { "truck" } })
	reps[#reps + 1] = { lvl = lvl, rep = rep }
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

-- First ten levels are the FTUE corridor: human-buildable 1 m grid, roomy budget, low stress.
-- They are the levels 90% of new players see before deciding to stay or leave.
for i = 1, 10 do
	local lvl, rep = reps[i].lvl, reps[i].rep
	if lvl.id ~= string.format("1-%d", i) then
		failures[#failures + 1] = "FTUE order: expected 1-" .. i .. ", got " .. lvl.id
	end
	for _, e in ipairs(check.grid_errors(lvl)) do failures[#failures + 1] = lvl.id .. ": " .. e end
	local ratio = rep.cost / lvl.budget
	if ratio > 0.78 then
		failures[#failures + 1] = string.format("%s: solution eats %.0f%% of the budget (target <= 78%%)", lvl.id, ratio * 100)
	end
	local stress = rep.detail and rep.detail.truck and rep.detail.truck.stress or 0
	if stress > 0.78 then
		failures[#failures + 1] = string.format("%s: truck stress %.2f (target <= 0.78)", lvl.id, stress)
	end
end

-- The toolbox only grows: every material available on a level stays available afterwards.
local prev
for _, lvl in ipairs(levels.list) do
	local bp = Blueprint.new(lvl)
	if prev then
		for id in pairs(prev) do
			if not bp.allowed[id] then failures[#failures + 1] = lvl.id .. ": lost material " .. id end
		end
	end
	prev = bp.allowed
end
if #failures > 0 then error("\n" .. table.concat(failures, "\n")) end
