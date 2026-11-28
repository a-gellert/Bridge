-- Helpers to validate a level: geometry sanity, solution validity, simulated runs per vehicle.
local Blueprint = require("game.bridge.blueprint")
local terrain = require("game.physics.terrain")
local Run = require("game.core.run")
local tuning = require("game.config.tuning")

local M = {}

-- Coordinates the player can actually reach with the build grid (anchors and the reference
-- solution). Returns a list of human-readable errors.
function M.grid_errors(level)
	local g = tuning.GRID
	local out = {}
	local function on_grid(v)
		return math.abs(v / g - math.floor(v / g + 0.5)) < 1e-6
	end
	for i, a in ipairs(level.anchors or {}) do
		if not on_grid(a[1]) or not on_grid(a[2]) then
			out[#out + 1] = string.format("anchor #%d (%g,%g) is off the %gm grid", i, a[1], a[2], g)
		end
	end
	for i, b in ipairs(level.solution or {}) do
		if not on_grid(b[2]) or not on_grid(b[3]) or not on_grid(b[4]) or not on_grid(b[5]) then
			out[#out + 1] = string.format("solution beam #%d (%g,%g-%g,%g) is off the %gm grid",
				i, b[2], b[3], b[4], b[5], g)
		end
	end
	return out
end

function M.simulate(level, geo, bp, veh)
	local run = Run.new(level, geo, bp, veh)
	local steps = 0
	local max_stress = 0
	while run.status == Run.RUNNING and steps < 60 * 55 do
		run:step()
		steps = steps + 1
		for _, c in pairs(run.beam_of) do
			if c.stress > max_stress then max_stress = c.stress end
		end
	end
	return run, max_stress
end

-- Returns a report table and prints one line per vehicle.
function M.check(level, opts)
	opts = opts or {}
	local geo = terrain.build(level)
	local rep = { id = level.id, errors = {}, results = {} }
	local function err(msg) rep.errors[#rep.errors + 1] = msg end
	local function say(fmt, ...) if not opts.quiet then print(string.format(fmt, ...)) end end

	-- anchors must not sit inside rock and must be in the build area
	local bp = Blueprint.new(level, geo)
	for _, a in ipairs(level.anchors) do
		if not bp:in_area(a[1], a[2]) then err(string.format("anchor %g,%g outside area", a[1], a[2])) end
	end
	if level.finish <= level.start then err("finish before start") end
	if not terrain.height_at(geo, level.start) then err("no ground at start") end
	if not terrain.height_at(geo, level.finish) then err("no ground at finish") end

	-- solution must be buildable within the budget by the normal rules
	for i, b in ipairs(level.solution or {}) do
		local ok, e = bp:add_beam(b[1], b[2], b[3], b[4], b[5], { no_undo = true, force = true })
		if not ok then err(string.format("solution beam #%d %s %g,%g-%g,%g rejected: %s", i, b[1], b[2], b[3], b[4], b[5], e)) end
	end
	rep.cost = bp:cost()
	if rep.cost > level.budget then err(string.format("solution costs %d > budget %d (suggest %d)", rep.cost, level.budget, math.ceil(rep.cost * 1.12 / 50) * 50)) end
	rep.budget = level.budget

	for _, veh in ipairs(opts.vehicles or { "moto", "car", "truck" }) do
		local run, ms = M.simulate(level, geo, bp, veh)
		rep.results[veh] = run.status
		if veh == "truck" then rep.portals = run.portals or 0 end
		rep.detail = rep.detail or {}
		rep.detail[veh] = { status = run.status, reason = run.reason, time = run.time, broken = run.broken, stress = ms, portals = run.portals or 0 }
		say("   %-5s %-6s %-7s %-8s t=%5.2f broken=%d stress=%.2f  cost %d/%d", level.id, veh, run.status, tostring(run.reason), run.time, run.broken, ms, rep.cost, level.budget)
	end

	if opts.empty ~= false then
		local empty = Blueprint.new(level, geo)
		local run = M.simulate(level, geo, empty, "moto")
		rep.empty = run.status
		rep.detail = rep.detail or {}
		rep.detail.empty = { status = run.status, reason = run.reason, time = run.time }
		say("   %-5s empty  %-7s %s", level.id, run.status, tostring(run.reason))
	end
	for _, e in ipairs(rep.errors) do say("   !! " .. level.id .. ": " .. e) end
	return rep
end

return M
