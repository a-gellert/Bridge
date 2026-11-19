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
local tuning = require("game.config.tuning")
local terrain = require("game.physics.terrain")
local Blueprint = require("game.bridge.blueprint")
local Run = require("game.core.run")
local progress = require("game.core.progress")
local achievements = require("game.core.achievements")
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
M.hover_node = nil         -- desktop hover: joint a click would grab (build tool)
M.hover_beam = nil         -- desktop hover: beam a click would delete (erase tool)
M.result = nil
M.input = { gas = false, brake = false }
M.paused = false
M.hint_used = false
M.guide = false          -- dashed brace hint, unlocked by repeated failure on levels 3-5
M.budget_bonus = false

local finish_delay = 0

local function set_state(s)
	M.state = s
	events.emit("state", { state = s })
end

local function announce(list)
	for _, a in ipairs(list or {}) do
		events.emit("achievement", { id = a.id, icon = a.icon })
	end
end

local function check_achievements(ctx)
	ctx = ctx or {}
	ctx.level = ctx.level or M.level
	ctx.blueprint = ctx.blueprint or M.blueprint
	if not ctx.beams and M.blueprint then ctx.beams = M.blueprint:beam_count() end
	announce(achievements.check(ctx))
end

-- Highest beam stress in the current simulation (0..1+), used by the creak audio.
function M.get_max_stress()
	local run = M.run
	if not run then return 0 end
	local max = 0
	for _, c in pairs(run.beam_of) do
		if c.stress > max then max = c.stress end
	end
	return max
end

function M.set_paused(on)
	M.paused = on and true or false
	if on then M.input.gas, M.input.brake = false, false end
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
	M.hover_node, M.hover_beam = nil, nil
	M.tool = "build"
	M.paused = false
	M.hint_used = false
	M.budget_bonus = false
	-- Never teach on entry: the dashed brace hint is a reaction to repeated failure.
	M.guide = M.has_guide()
	-- keep the chosen material if this level has it, else the first one
	if not M.blueprint.allowed[M.material] then M.material = lvl.materials[1] end
	progress.record_attempt(lvl)
	check_achievements({ meta = true })
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
	M.hover_node, M.hover_beam = nil, nil
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
	progress.bump("built")
	events.emit("built", { mat = M.material })
	events.emit("design_changed", {})
	check_achievements()
	return true, bm
end

function M.erase_beam(id)
	if M.state ~= "build" then return false end
	if M.blueprint:remove_beam(id) then
		M.selected_node = nil
		if M.hover_beam == id then M.hover_beam = nil end
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

-- ------------------------------------------------------------------ post-failure brace hint
-- Only levels 3-5 carry `brace_hint`, and only after two consecutive collapses on that
-- level. The hint draws the non-deck solution beams as dashed lines (see world/guide_view).
function M.has_guide()
	return M.level and M.level.brace_hint and M.level.solution ~= nil
		and progress.fail_streak(M.level.id) >= 2 and true or false
end

function M.set_guide(on)
	if not M.has_guide() then return false end
	M.guide = on and true or false
	events.emit("design_changed", {})
	return true
end

-- True when the player's design already has a beam with the same endpoints (any material).
function M.guide_has_beam(s)
	local bp = M.blueprint
	if not bp or not s then return false end
	local a, b = bp:node_at(s[2], s[3]), bp:node_at(s[4], s[5])
	return (a and b and bp:beam_between(a.id, b.id)) and true or false
end

-- True when every beam of the reference solution is already in the design.
function M.guide_done()
	local sol = M.level and M.level.solution
	if not sol or #sol == 0 then return false end
	for _, s in ipairs(sol) do
		if not M.guide_has_beam(s) then return false end
	end
	return true
end

-- Replace the design with the level's reference solution (rewarded hint).
function M.apply_hint()
	if not M.level.solution then return false end
	M.blueprint:push_undo()
	local st = M.blueprint.undo_stack
	M.blueprint:load(M.level.solution, true)
	M.blueprint.undo_stack = st
	M.selected_node = nil
	M.hint_used = true
	events.emit("hint", {})
	events.emit("design_changed", {})
	return true
end

-- Emergency help after repeated defeats: +25% budget for the current attempt.
-- The caller grants it only after a rewarded break succeeded.
function M.apply_budget_bonus()
	if not M.blueprint or M.budget_bonus then return false end
	M.budget_bonus = true
	M.blueprint.budget = math.floor(M.blueprint.budget * 1.25 + 0.5)
	events.emit("budget_bonus", { budget = M.blueprint.budget })
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
	M.hover_node, M.hover_beam = nil, nil
	M.paused = false
	M.input.gas, M.input.brake = false, false
	M.run = Run.new(M.level, M.geo, M.blueprint, M.vehicle)
	M.run.vehicle.input = M.input
	finish_delay = 0
	progress.bump("runs")
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
	M.paused = false
	-- The result has already recorded the failure, so the 2nd collapse re-arms the hint.
	M.guide = M.has_guide()
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
		budget = M.blueprint.budget,
		level_budget = M.level.budget,
		ratio = cost / math.max(1, M.blueprint.budget),
		level_index = M.index,
		level_id = M.level.id,
		level_number = M.level.number,
		chapter_index = M.level.chapter_index,
		is_biome_milestone = won and (M.level.number == 8),
		time = run.end_time or run.time,
		broken = run.broken,
		beams = M.blueprint:beam_count(),
		hint_used = M.hint_used,
		budget_bonus = M.budget_bonus,
		portals = run.portals or 0,
		trick = run.trick_landed or false,
	}
	if won then
		local rec = progress.record_win(M.level, def.stars, cost, { clean = run.broken == 0, broken = run.broken })
		for k, v in pairs(rec) do res[k] = v end
	else
		res.stars = progress.stars(M.level.id)
		progress.record_fail(M.level)
		if run.reason ~= "stuck" then progress.bump("crashes") end
		res.fails = progress.fail_streak(M.level.id)
		res.can_assist = res.fails >= 3 and not M.budget_bonus
	end
	-- per-run counters for the profile / achievements
	progress.bump("portals", run.portals or 0)
	progress.bump("bounces", run.bounces or 0)
	progress.bump("boosts", run.boosts or 0)
	if run.trick_landed then progress.bump("tricks") end
	res.has_next = levels.get(M.index + 1) ~= nil
	res.next_unlocked = res.has_next and progress.level_unlocked(M.index + 1)
	res.wallet = progress.wallet()
	check_achievements({ run = run, result = res })
	return res
end

function M.update(dt)
	if M.state ~= "drive" or not M.run or M.paused then return end
	local run = M.run
	local scale = run.status == Run.RUNNING and 1 or 0.45
	-- micro slow motion: a beam snaps close to the finish
	if run.slowmo_t and run.slowmo_t > 0 then
		run.slowmo_t = math.max(0, run.slowmo_t - dt)
		scale = tuning.SLOWMO_SCALE
	end
	run:update(dt * scale)
	local ev = run:pop_events()
	if ev then
		for _, e in ipairs(ev) do
			if e.type == "break" then
				events.emit("beam_broken", { id = e.id, x = e.x, y = e.y, mat = e.mat })
			elseif e.type == "portal" or e.type == "bounce" or e.type == "boost" or e.type == "land" then
				events.emit(e.type, e)
			elseif e.type == "slowmo" then
				events.emit("slowmo", e)
			elseif e.type == Run.WON or e.type == Run.FAILED then
				events.emit("run_finished", { won = e.type == Run.WON, reason = e.reason })
			end
		end
		check_achievements({ run = run })
	end
	if run.status ~= Run.RUNNING then
		finish_delay = finish_delay + dt
		local wait = run.status == Run.WON and 0.25 or 0.1
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
	M.hover_node, M.hover_beam = nil, nil
	set_state("menu")
end

return M
