-- Level session: the single source of truth shared by the GUI and the world scripts (shared Lua state).
-- States: "menu" -> "build" <-> "drive" -> "result" (-> "build" / next level / "menu").
-- Pure Lua: platform calls (Poki, sound) are made by scripts reacting to the emitted events.
--
-- Events (events.lua):
--   level_loaded {index}      design_changed {}        build_failed {err, x, y}     built {mat}
--   erased {}                 drive_started {vehicle}  drive_stopped {}             beam_broken {x, y, mat}
--   portal {x, y}             bounce {}                boost {}                     run_finished {won, reason}
--   result {...}              state {state}            hint {}
local levels = require("game.levels.levels")
local materials = require("game.config.materials")
local vehicles = require("game.config.vehicles")
local terrain = require("game.physics.terrain")
local Blueprint = require("game.bridge.blueprint")
local Run = require("game.core.run")
local progress = require("game.core.progress")
local events = require("game.core.events")

local M = {}

M.state = "menu"
M.index = nil
M.level = nil
M.geo = nil
M.blueprint = nil
M.run = nil
M.material = "road"
M.tool = "build"           -- "build" | "erase"
M.vehicle = "truck"
M.selected_node = nil      -- joint id chosen as the start of the next beam (tap-tap building)
M.preview = nil            -- ghost beam { x1, y1, x2, y2, mat, ok, err, cost }
M.result = nil
M.input = { gas = false, brake = false }

local finish_delay = 0

local function set_state(s)
	M.state = s
	events.emit("state", { state = s })
end

-- ------------------------------------------------------------------ level
function M.load_level(index)
	local lvl = levels.get(index)
	if not lvl then return false end
	M.index = index
	M.level = lvl
	M.geo = terrain.build(lvl)
	M.blueprint = Blueprint.new(lvl, M.geo)
	local saved = progress.design(lvl.id)
	if saved then M.blueprint:load(saved) end
	M.run = nil
	M.result = nil
	M.selected_node = nil
	M.preview = nil
	M.tool = "build"
	-- keep the chosen material if this level has it, else the first one
	if not M.blueprint.allowed[M.material] then M.material = lvl.materials[1] end
	progress.record_attempt(lvl)
	set_state("build")
	events.emit("level_loaded", { index = index })
	return true
end

function M.available_materials()
	local out = {}
	for _, id in ipairs(M.level.materials) do out[#out + 1] = materials.get(id) end
	table.sort(out, function(a, b) return a.order < b.order end)
	return out
end

-- Materials that appear for the first time on this level (for the "NEW" badge).
function M.new_materials()
	local out = {}
	for _, id in ipairs(M.level.materials) do
		local m = materials.get(id)
		if m.unlock == M.index then out[#out + 1] = m end
	end
	return out
end

function M.save_design()
	if M.level and M.blueprint then progress.save_design(M.level.id, M.blueprint:serialize()) end
end

-- ------------------------------------------------------------------ build mode
function M.select_material(id)
	if M.blueprint and M.blueprint.allowed[id] then
		M.material = id
		M.tool = "build"
		events.emit("design_changed", {})
	end
end

function M.set_tool(tool)
	M.tool = tool
	M.selected_node = nil
	M.preview = nil
	events.emit("design_changed", {})
end

function M.select_vehicle(id)
	if vehicles.get(id) then M.vehicle = id end
end

-- Validate a beam for the ghost preview.
function M.check(x1, y1, x2, y2)
	local ok, err, cost = M.blueprint:check_beam(M.material, x1, y1, x2, y2)
	return ok, err, cost
end

function M.set_preview(x1, y1, x2, y2)
	if not x1 then
		M.preview = nil
		return
	end
	local ok, err, cost = M.check(x1, y1, x2, y2)
	M.preview = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, mat = M.material, ok = ok, err = err, cost = cost }
end

function M.try_build(x1, y1, x2, y2)
	if M.state ~= "build" then return false end
	local bm, err = M.blueprint:add_beam(M.material, x1, y1, x2, y2)
	if not bm then
		events.emit("build_failed", { err = err, x = (x1 + x2) * 0.5, y = (y1 + y2) * 0.5 })
		return false, err
	end
	events.emit("built", { mat = M.material })
	events.emit("design_changed", {})
	return true, bm
end

function M.erase_beam(id)
	if M.state ~= "build" then return false end
	if M.blueprint:remove_beam(id) then
		M.selected_node = nil
		events.emit("erased", {})
		events.emit("design_changed", {})
		return true
	end
	return false
end

function M.undo()
	if M.state ~= "build" then return false end
	if M.blueprint:undo() then
		M.selected_node = nil
		events.emit("erased", {})
		events.emit("design_changed", {})
		return true
	end
	return false
end

function M.clear()
	if M.state ~= "build" then return false end
	if M.blueprint:remove_all() then
		M.selected_node = nil
		events.emit("erased", {})
		events.emit("design_changed", {})
		return true
	end
	return false
end

-- Replace the design with the level's reference solution (rewarded hint).
function M.apply_hint()
	if not M.level.solution then return false end
	M.blueprint:push_undo()
	local st = M.blueprint.undo_stack
	M.blueprint:load(M.level.solution, true)
	M.blueprint.undo_stack = st
	M.selected_node = nil
	events.emit("hint", {})
	events.emit("design_changed", {})
	return true
end

-- ------------------------------------------------------------------ drive mode
function M.start_drive(vehicle_id)
	if M.state ~= "build" then return false end
	M.vehicle = vehicle_id or M.vehicle
	M.save_design()
	M.selected_node = nil
	M.preview = nil
	M.input.gas, M.input.brake = false, false
	M.run = Run.new(M.level, M.geo, M.blueprint, M.vehicle)
	M.run.vehicle.input = M.input
	finish_delay = 0
	set_state("drive")
	events.emit("drive_started", { vehicle = M.vehicle })
	return true
end

-- Back to building: the blueprint was never touched by the simulation, so this is instant.
function M.stop_drive()
	if M.state ~= "drive" and M.state ~= "result" then return false end
	M.run = nil
	M.result = nil
	M.input.gas, M.input.brake = false, false
	set_state("build")
	events.emit("drive_stopped", {})
	return true
end

function M.set_input(gas, brake)
	M.input.gas = gas and true or false
	M.input.brake = brake and true or false
end

local function make_result()
	local run = M.run
	local won = run.status == Run.WON
	local def = vehicles.get(M.vehicle)
	local cost = M.blueprint:cost()
	local res = {
		won = won,
		reason = run.reason,
		vehicle = M.vehicle,
		vehicle_stars = def.stars,
		cost = cost,
		budget = M.level.budget,
		ratio = cost / math.max(1, M.level.budget),
		level_index = M.index,
		time = run.end_time or run.time,
		broken = run.broken,
	}
	if won then
		local rec = progress.record_win(M.level, def.stars, cost)
		for k, v in pairs(rec) do res[k] = v end
	else
		res.stars = progress.stars(M.level.id)
	end
	res.has_next = levels.get(M.index + 1) ~= nil
	res.next_unlocked = res.has_next and progress.level_unlocked(M.index + 1)
	return res
end

function M.update(dt)
	if M.state ~= "drive" or not M.run then return end
	local run = M.run
	run:update(dt)
	local ev = run:pop_events()
	if ev then
		for _, e in ipairs(ev) do
			if e.type == "break" then
				events.emit("beam_broken", { id = e.id, x = e.x, y = e.y, mat = e.mat })
			elseif e.type == "portal" or e.type == "bounce" or e.type == "boost" then
				events.emit(e.type, e)
			elseif e.type == Run.WON or e.type == Run.FAILED then
				events.emit("run_finished", { won = e.type == Run.WON, reason = e.reason })
			end
		end
	end
	if run.status ~= Run.RUNNING then
		finish_delay = finish_delay + dt
		local wait = run.status == Run.WON and 1.1 or 1.3
		if finish_delay >= wait then
			M.result = make_result()
			set_state("result")
			events.emit("result", M.result)
		end
	end
end

function M.exit_to_menu()
	if M.state == "build" then M.save_design() end
	M.run = nil
	M.result = nil
	M.preview = nil
	M.selected_node = nil
	set_state("menu")
end

return M
