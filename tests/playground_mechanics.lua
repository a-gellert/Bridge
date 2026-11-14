-- Mechanics playground (not a test, run: node run.js playground_mechanics.lua): ramps, boost, bounce, portals.
local Blueprint = require("game.bridge.blueprint")
local terrain = require("game.physics.terrain")
local Run = require("game.core.run")

local ALL = { "road", "wood", "steel", "rope", "cable", "steel_road", "boost", "bounce" }

local function try(name, level, beams, veh, verbose)
	level.budget = level.budget or 99999
	level.materials = level.materials or ALL
	level.anchors = level.anchors or {}
	local geo = terrain.build(level)
	local bp = Blueprint.new(level, geo)
	for _, b in ipairs(beams) do
		local ok, err = bp:add_beam(b[1], b[2], b[3], b[4], b[5], { no_undo = true, force = true })
		if not ok then print("  beam rejected", b[1], b[2], b[3], b[4], b[5], err) end
	end
	local run = Run.new(level, geo, bp, veh)
	local steps, maxy = 0, -99
	while run.status == Run.RUNNING and steps < 60 * 40 do
		run:step()
		steps = steps + 1
		local cx, cy = run.vehicle:center()
		if cy > maxy then maxy = cy end
		local ev = run:pop_events()
		if ev and verbose then for _, e in ipairs(ev) do print("    event", e.type, e.reason or "", e.x or "") end end
		if verbose and steps % 20 == 0 then
			print(string.format("   t=%.2f x=%.2f y=%.2f v=%.2f up=%.2f g=%s", run.time, cx, cy, run.vehicle:speed(), run.vehicle:up_y(), tostring(run.vehicle.grounded)))
		end
	end
	local cx = run.vehicle:center()
	print(string.format("  %-22s %-6s %-7s %-8s t=%5.2f x=%6.2f maxy=%.2f broken=%d", name, veh, run.status, tostring(run.reason), run.time, cx, maxy, run.broken))
end

-- uphill ramp then plateau
local ramp = { ground = { { -30, 0, 0 }, { 8, 40, 3 } }, ramps = { { 0, 8, 0, 3 } }, start = -8, finish = 20, water = -5 }
for _, v in ipairs({ "moto", "car", "truck" }) do try("ramp 3/8", ramp, {}, v) end
local steep = { ground = { { -30, 0, 0 }, { 5, 40, 3 } }, ramps = { { 0, 5, 0, 3 } }, start = -8, finish = 20, water = -5 }
for _, v in ipairs({ "moto", "car", "truck" }) do try("ramp 3/5", steep, {}, v) end

-- jump: ramp kicker then gap of 8 m, with and without boost road
local jump = { ground = { { -30, 0, 0 }, { 12, 40, 0 } }, ramps = { { 0, 3, 0, 1, -40 } }, anchors = { { -9, 0 }, { 0, 0 } }, start = -14, finish = 20, water = -5 }
for _, v in ipairs({ "moto", "car", "truck" }) do try("jump 9 no boost", jump, {}, v) end
local boost = { { "boost", -9, 0, -6, 0 }, { "boost", -6, 0, -3, 0 }, { "boost", -3, 0, 0, 0 } }
for _, v in ipairs({ "moto", "car", "truck" }) do try("jump 9 boost", jump, boost, v) end

-- bounce over a wall
local wall = { ground = { { -30, 0, 0 }, { 0, 40, 0 } }, blocks = { { 6, 0, 7, 3.2 } }, anchors = { { 0, 0 }, { 3, 0 } },
	start = -8, finish = 16, water = -5 }
for _, v in ipairs({ "moto", "car", "truck" }) do try("wall no bounce", wall, {}, v) end
for _, v in ipairs({ "moto", "car", "truck" }) do try("wall bounce", wall, { { "bounce", 0, 0, 3, 0 } }, v) end

-- portal: entry facing left at x=4 on the start ground, exit on a high platform facing right
local portal = { ground = { { -30, 6, 0 }, { 20, 50, 6 } }, blocks = { { 6, 0, 7, 4 } },
	portals = { { { x = 5, y = 1.2, angle = math.pi }, { x = 21, y = 7.4, angle = 0 } } },
	start = -6, finish = 30, water = -5 }
for _, v in ipairs({ "moto", "car", "truck" }) do try("portal", portal, {}, v, v == "car") end
