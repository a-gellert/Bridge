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

-- Every reference bridge sits on the 1 m build grid: the budget is fitted to a bridge a player
-- can actually draw (tools/gen/level_kit.js grid mode).
for _, r in ipairs(reps) do
	for _, e in ipairs(check.grid_errors(r.lvl)) do failures[#failures + 1] = r.lvl.id .. ": " .. e end
end

-- Pacing by round. The player path rotates the biomes in blocks of levels.BLOCK, so round r
-- (levels 8(r-1)+1..8r of every chapter) is played together: budget slack and bridge size
-- grow with the round, never with the chapter. Round 1 is every chapter's opening.
local MAX_RATIO = { 0.78, 0.79, 0.81, 0.83, 0.86 }
local MAX_BEAMS = { 22, 24, 34, 34, 60 }
for _, r in ipairs(reps) do
	local round = math.min(#MAX_RATIO, math.ceil(r.lvl.number / levels.BLOCK))
	local ratio = r.rep.cost / r.lvl.budget
	if ratio > MAX_RATIO[round] then
		failures[#failures + 1] = string.format("%s: round %d solution eats %.0f%% of the budget (max %.0f%%)",
			r.lvl.id, round, ratio * 100, MAX_RATIO[round] * 100)
	end
	if #r.lvl.solution > MAX_BEAMS[round] then
		failures[#failures + 1] = string.format("%s: round %d reference has %d beams (max %d)",
			r.lvl.id, round, #r.lvl.solution, MAX_BEAMS[round])
	end
end

-- First ten levels are the FTUE corridor: roomy budget, low stress.
-- They are the levels 90% of new players see before deciding to stay or leave.
for i = 1, 10 do
	local lvl, rep = reps[i].lvl, reps[i].rep
	if lvl.id ~= string.format("1-%d", i) then
		failures[#failures + 1] = "FTUE order: expected 1-" .. i .. ", got " .. lvl.id
	end
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
