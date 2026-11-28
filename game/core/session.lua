-- Level session: the single source of truth shared by the GUI and the world scripts (shared Lua state).
-- States: "menu" -> "build" <-> "drive" -> "result" (-> "build" / next level / "menu").
-- Pure Lua: platform calls (Poki, sound) are made by scripts reacting to the emitted events.
--
-- Events (events.lua):
--   level_loaded {index}      design_changed {}        build_failed {err, x, y}     built {mat}
--   erased {}                 drive_started {vehicle}  drive_stopped {}             beam_broken {x, y, mat}
--   portal {x, y}             bounce {}                boost {}                     run_finished {won, reason}
--   result {...}              state {state}            vehicle_changed {vehicle}    budget_bonus {budget}
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
M.tutorial = false       -- first-level onboarding (dashed plan + HUD instructions)
M.budget_bonus = false
M.last_broken = {}       -- [beam id] = true: beams that snapped in the previous run
M.last_peak_stress = {}  -- [beam id] = peak stress of the previous run (0..1+)

local finish_delay = 0
local make_result

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
	M.last_broken = {}
	M.last_peak_stress = {}
	-- Never teach on entry: the dashed brace hint is a reaction to repeated failure.
	M.guide = M.has_guide()
	-- The first-level tutorial is a one-time onboarding: once the level has stars or the
	-- player finished it, the plan and instructions stay away.
	M.tutorial = (lvl.tutorial and progress.stars(lvl.id) == 0 and not progress.get("tutorial_done")) and true or false
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
	-- Read the blueprint's allowed set: it already contains the cumulative campaign unlocks.
	for _, m in ipairs(materials.list) do
		if M.blueprint.allowed[m.id] then out[#out + 1] = m end
	end
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
	if vehicles.get(id) then
		M.vehicle = id
		events.emit("vehicle_changed", { vehicle = id })
	end
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

-- The post-failure highlight is a snapshot of the design that failed: it lives until the
-- player edits the blueprint (or starts a new run / loads another level).
function M.clear_last_break()
	M.last_broken = {}
	M.last_peak_stress = {}
end

function M.try_build(x1, y1, x2, y2)
	if M.state ~= "build" then return false end
	local bm, err = M.blueprint:add_beam(M.material, x1, y1, x2, y2)
	if not bm then
		events.emit("build_failed", { err = err, x = (x1 + x2) * 0.5, y = (y1 + y2) * 0.5 })
		return false, err
	end
	M.clear_last_break()
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
		M.clear_last_break()
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
		M.clear_last_break()
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
		M.clear_last_break()
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

-- First-level tutorial: is there a continuous drivable path between the two banks?
-- The reference plan is only a suggestion, so any split of the road counts.
function M.tutorial_ready()
	local lvl, bp = M.level, M.blueprint
	if not lvl or not bp or not lvl.anchors or #lvl.anchors < 2 then return false end
	local a, b = lvl.anchors[1], lvl.anchors[2]
	local start, goal = bp:node_at(a[1], a[2]), bp:node_at(b[1], b[2])
	if not start or not goal then return false end
	local adj = {}
	for _, bm in pairs(bp.beams) do
		local mat = materials.get(bm.mat)
		if mat and mat.drivable then
			adj[bm.a] = adj[bm.a] or {}
			adj[bm.a][#adj[bm.a] + 1] = bm.b
			adj[bm.b] = adj[bm.b] or {}
			adj[bm.b][#adj[bm.b] + 1] = bm.a
		end
	end
	local seen = { [start.id] = true }
	local queue = { start.id }
	local head = 1
	while head <= #queue do
		local id = queue[head]
		head = head + 1
		if id == goal.id then return true end
		for _, nb in ipairs(adj[id] or {}) do
			if not seen[nb] then
				seen[nb] = true
				queue[#queue + 1] = nb
			end
		end
	end
	return false
end

-- "build" while the banks are still apart, "go" when the road can carry the truck.
function M.tutorial_step()
	if not M.tutorial then return nil end
	return M.tutorial_ready() and "go" or "build"
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
	M.clear_last_break()
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
	M.clear_last_break()
	M.run = Run.new(M.level, M.geo, M.blueprint, M.vehicle)
	M.run.vehicle.input = M.input
	finish_delay = 0
	progress.bump("runs")
	set_state("drive")
	events.emit("drive_started", { vehicle = M.vehicle })
	return true
end

-- Back to building: the blueprint was never touched by the simulation, so this is instant.
-- A run that has already ended still records its result, so an impatient R / tap cannot
-- skip the attempt counters.
function M.stop_drive()
	if M.state ~= "drive" and M.state ~= "result" then return false end
	if M.state == "drive" and M.run and M.run.status ~= Run.RUNNING and not M.result then
		M.result = make_result()
	end
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

make_result = function()
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
		stunt_score = run.stunts and run.stunts.score or 0,
		max_combo = run.stunts and run.stunts.max_combo or 0,
		air_best = run.air_best or 0,
		stunt_cash = won and (run.stunts and run.stunts.cash or 0) or 0,
	}
	if won then
		if M.index == 1 then
			progress.set_setting("tutorial_done", true)
			M.tutorial = false
		end
		local rec = progress.record_win(M.level, def.stars, cost, {
			clean = run.broken == 0, broken = run.broken,
			stunt_cash = run.stunts and run.stunts.cash or 0,
		})
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
	if run.stunts and run.stunts.score > 0 then progress.bump("stunt_score", run.stunts.score) end
	res.has_next = levels.get(M.index + 1) ~= nil
	res.next_unlocked = res.has_next and progress.level_unlocked(M.index + 1)
	res.wallet = progress.wallet()
	check_achievements({ run = run, result = res })
	return res
end

-- The run is over but the short collapse/highlight beat is still playing.
function M.fail_pending()
	return M.state == "drive" and M.run ~= nil and M.run.status == Run.FAILED and M.result == nil
end

-- A tap / R / Space during that beat: record the attempt and go straight back to building.
function M.instant_retry()
	if not M.fail_pending() then return nil end
	M.result = make_result()
	local reason = M.result.reason
	M.stop_drive()
	return reason
end

-- Publish the result card (used by the normal timer and by a deliberate skip).
function M.show_result()
	if M.state ~= "drive" or not M.run or M.run.status == Run.RUNNING or M.result then return false end
	M.result = make_result()
	set_state("result")
	events.emit("result", M.result)
	return true
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
	-- Peak load per beam: the build-mode overlay can point at the weak member even if the
	-- run failed before the beam actually snapped.
	for id, c in pairs(run.beam_of) do
		if c.stress > (M.last_peak_stress[id] or 0) then M.last_peak_stress[id] = c.stress end
	end
	local ev = run:pop_events()
	if ev then
		for _, e in ipairs(ev) do
			if e.type == "break" then
				M.last_broken[e.id] = true
				events.emit("beam_broken", { id = e.id, x = e.x, y = e.y, mat = e.mat })
			elseif e.type == "portal" or e.type == "bounce" or e.type == "boost" or e.type == "land" or e.type == "stunt" then
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
		-- A collapse is the fun part: give the debris, splash and the weak beam a moment to
		-- read. A tap / R / Space skips this beat instantly (instant_retry).
		local wait = run.status == Run.WON and 0.25 or 0.75
		if finish_delay >= wait then
			M.show_result()
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
