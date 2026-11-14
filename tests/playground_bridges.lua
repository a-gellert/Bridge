-- Physics playground (not a test, run: node run.js playground_bridges.lua): prints how vehicles behave on simple setups.
local Blueprint = require("game.bridge.blueprint")
local terrain = require("game.physics.terrain")
local Run = require("game.core.run")

local function try(level, beams, veh, verbose)
	local geo = terrain.build(level)
	local bp = Blueprint.new(level, geo)
	for _, b in ipairs(beams) do
		local ok, err = bp:add_beam(b[1], b[2], b[3], b[4], b[5], { no_undo = true, force = true })
		if not ok then print("  beam rejected", b[1], b[2], b[3], b[4], b[5], err) end
	end
	local run = Run.new(level, geo, bp, veh)
	local steps = 0
	local maxstress, maxname = 0, ""
	while run.status == Run.RUNNING and steps < 60 * 40 do
		run:step()
		steps = steps + 1
		for id, c in pairs(run.beam_of) do
			if c.stress > maxstress then maxstress, maxname = c.stress, c.mat .. "#" .. id end
		end
		if verbose and steps % 30 == 0 then
			local cx, cy = run.vehicle:center()
			print(string.format("   t=%.1f x=%.2f y=%.2f v=%.2f up=%.2f g=%s", run.time, cx, cy, run.vehicle:speed(), run.vehicle:up_y(), tostring(run.vehicle.grounded)))
		end
	end
	local cx, cy = run.vehicle:center()
	print(string.format("  %-6s %-7s %-8s t=%5.2f x=%6.2f broken=%d cost=%d maxstress=%.2f (%s)", veh, run.status, tostring(run.reason), run.time, cx, run.broken, bp:cost(), maxstress, maxname))
	return run
end

local flat = { budget = 99999, materials = { "road", "wood", "steel", "rope", "cable", "steel_road", "boost", "bounce" },
	ground = { { -30, 0, 0 }, { 0, 60, 0 } }, anchors = {}, start = -10, finish = 30, water = -5 }
print("flat ground")
for _, v in ipairs({ "moto", "car", "truck" }) do try(flat, {}, v, v == "truck") end

local function gap(w)
	return { budget = 99999, materials = flat.materials,
		ground = { { -30, 0, 0 }, { w, w + 30, 0 } }, anchors = { { 0, 0 }, { w, 0 } }, start = -8, finish = w + 8, water = -5 }
end

print("gap 6: flat road, 2 segments")
for _, v in ipairs({ "moto", "car", "truck" }) do try(gap(6), { { "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 } }, v) end

print("gap 6: road + wood king post truss")
local truss6 = { { "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 }, { "wood", 0, 0, 3, 2 }, { "wood", 3, 2, 6, 0 }, { "wood", 3, 0, 3, 2 } }
for _, v in ipairs({ "moto", "car", "truck" }) do try(gap(6), truss6, v) end

print("gap 12: flat road 4 segments")
local flat12 = { { "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 }, { "road", 6, 0, 9, 0 }, { "road", 9, 0, 12, 0 } }
for _, v in ipairs({ "moto", "car", "truck" }) do try(gap(12), flat12, v) end

print("gap 12: warren truss over road (wood)")
local w12 = { { "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 }, { "road", 6, 0, 9, 0 }, { "road", 9, 0, 12, 0 },
	{ "wood", 0, 0, 2, 2 }, { "wood", 2, 2, 3, 0 }, { "wood", 3, 0, 5, 2 }, { "wood", 5, 2, 6, 0 }, { "wood", 6, 0, 7, 2 }, { "wood", 7, 2, 9, 0 }, { "wood", 9, 0, 10, 2 }, { "wood", 10, 2, 12, 0 },
	{ "wood", 2, 2, 5, 2 }, { "wood", 5, 2, 7, 2 }, { "wood", 7, 2, 10, 2 } }
for _, v in ipairs({ "moto", "car", "truck" }) do try(gap(12), w12, v) end
