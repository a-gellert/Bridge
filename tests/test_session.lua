-- Session flow: load -> build -> drive -> result -> progress/unlocks; failure path; hint; persistence.
local progress = require("game.core.progress")
local events = require("game.core.events")
local session = require("game.core.session")
local levels = require("game.levels.levels")
local Run = require("game.core.run")

local store = nil
progress.set_storage({
	load = function() return store end,
	save = function(d) store = d end,
})
progress.load()
events.subscribe("test")

assert(progress.level_unlocked(1), "level 1 open")
assert(not progress.level_unlocked(2), "level 2 locked")
assert(progress.chapter_unlocked(2), "any chapter can be visited")
assert(progress.level_unlocked(levels.chapters[2].first), "chapter 2 level 1 open")
assert(not progress.level_unlocked(levels.chapters[2].first + 1), "chapter 2 level 2 locked")

local function drive(vehicle)
	assert(session.start_drive(vehicle))
	local t = 0
	while session.state == "drive" and t < 70 do
		session.update(1 / 60)
		t = t + 1 / 60
	end
	return session.result
end

-- level 1: the truck must fall into the water with nothing built, not hang nose-first
-- on the chamfered cliff edge (the run also has a generic over-water slip rescue)
assert(session.load_level(1))
assert(session.tutorial, "first level starts the tutorial")
local res = drive("truck")
assert(res and not res.won and res.reason == "fell", "empty bridge must drop the truck into the water")
assert(session.state == "result")
assert(session.stop_drive() and session.state == "build", "back to build")

-- build the road and send the bike: 1 star
local lvl = levels.get(1)
for _, b in ipairs(lvl.solution) do
	assert(session.try_build(b[2], b[3], b[4], b[5]))
end
assert(session.tutorial_ready(), "tutorial plan is complete")
res = drive("moto")
assert(res.won and res.stars == 1 and res.new_stars == 1, "bike gives 1 star")
assert(progress.level_unlocked(2), "level 2 unlocked after a star")
assert(not session.tutorial, "winning ends the first-level tutorial")
session.stop_drive()

-- the truck right away gives 3 stars
res = drive("truck")
assert(res.won and res.stars == 3 and res.new_stars == 2, "truck gives 3 stars")
assert(res.cost == 360 and res.budget == 500, "budget info")
assert(progress.total_stars() == 3)

-- the design is saved and restored
session.exit_to_menu()
assert(session.load_level(1))
assert(session.blueprint:beam_count() == 1, "design restored")
assert(not session.tutorial, "tutorial is one-time after the first win")

-- hint loads the reference design, undo reverts it
assert(session.load_level(2))
-- level 1 has its own one-time onboarding; the dashed brace hint stays a reaction to failure
assert(levels.get(1).tutorial and levels.get(1).no_build_zone,
	"level 1 has the tutorial and no highlighted build zone")
assert(not levels.get(1).tip and not levels.get(1).assist, "level 1 has no reward tip / assist plate")
assert(not session.tutorial, "tutorial is over after the first win")
assert(not levels.get(1).guide and not levels.get(2).guide and not levels.get(3).guide, "no plan before failure")
assert(not levels.get(1).brace_hint and not levels.get(2).brace_hint, "no brace hint on levels 1-2")
assert(levels.get(3).brace_hint and levels.get(4).brace_hint and levels.get(5).brace_hint, "brace hint on levels 3-5")
assert(not levels.get(6).brace_hint, "brace hint ends at level 5")
assert(not session.guide, "no hint on entry")
assert(not session.set_guide(true), "hint cannot be forced before failures")
session.clear()
assert(not session.guide_done(), "empty design is not plan-complete")
assert(session.apply_hint())
assert(session.blueprint:beam_count() == #levels.get(2).solution)
assert(session.guide_done(), "reference bridge counts as plan-complete")
assert(session.undo())
assert(session.blueprint:beam_count() == 0)

-- the dashed brace hint unlocks only after the 2nd consecutive collapse on levels 3-5
assert(session.load_level(3))
assert(not session.guide, "level 3 starts without a hint")
res = drive("moto")
assert(res and not res.won, "empty level 3 must fail")
assert(session.stop_drive())
assert(not session.guide, "one collapse is not enough")
res = drive("moto")
assert(res and not res.won, "empty level 3 must fail again")
assert(session.stop_drive())
assert(session.guide, "second consecutive collapse shows the brace hint")
assert(session.set_guide(false) and not session.guide, "any touch can dismiss the hint")
assert(session.set_guide(true) and session.guide, "hint can be recalled on the same attempt")

-- events were emitted
local evs = events.drain("test")
local seen = {}
for _, e in ipairs(evs) do seen[e.id] = true end
for _, id in ipairs({ "level_loaded", "drive_started", "result", "built", "design_changed", "hint", "state" }) do
	assert(seen[id], "event " .. id)
end

-- persistence survived through the storage backend
assert(store and store.levels["1-1"].stars == 3)

-- dynamic assist: after three consecutive defeats the fail screen can offer +25% budget
local last
for _ = 1, 3 do
	assert(session.load_level(1))
	session.clear()
	last = drive("moto")
	assert(last and not last.won, "empty bridge must fail")
end
assert(last.can_assist, "assist offered after three defeats")
assert(session.apply_budget_bonus(), "budget bonus applied")
assert(session.blueprint.budget == 625, "500 + 25% = 625, got " .. tostring(session.blueprint.budget))
assert(not session.apply_budget_bonus(), "bonus only once per attempt")

-- Collapse beat: a failed run stays visible for ~0.75 s, and a deliberate skip records the
-- attempt before returning to build (an impatient player must not dodge the fail counter).
assert(session.load_level(2))
session.clear()
session.start_drive("truck")
local guard = 0
while session.run.status == Run.RUNNING and guard < 3600 do
	session.update(1 / 60)
	guard = guard + 1
end
assert(session.run.status == Run.FAILED, "empty truck run failed")
assert(session.state == "drive", "collapse beat keeps the run on screen")
for _ = 1, 20 do session.update(1 / 60) end
assert(session.state == "drive", "0.33 s is still inside the 0.75 s beat")
local fails_before = progress.fail_streak(session.level.id)
local skip_reason = session.instant_retry()
assert(skip_reason and session.state == "build", "tap / R during the beat returns to build")
assert(progress.fail_streak(session.level.id) == fails_before + 1, "skipped collapse still records the defeat")

-- Post-failure weak spots: a deck-only truck run breaks the road, the design remembers it,
-- and the first edit clears the highlight.
session.clear()
for _, b in ipairs(session.level.solution) do
	if b[1] == "road" then
		session.select_material("road")
		assert(session.try_build(b[2], b[3], b[4], b[5]))
	end
end
session.start_drive("truck")
guard = 0
while session.state == "drive" and guard < 3600 do
	session.update(1 / 60)
	guard = guard + 1
end
assert(session.state == "result" and not session.result.won, "deck-only bridge collapses")
session.stop_drive()
assert(next(session.last_broken), "broken beams are remembered for the build overlay")
assert(next(session.last_peak_stress), "peak stress is remembered for the build overlay")
session.select_material("wood")
assert(session.try_build(3, 0, 3, 2), "first edit builds a brace")
assert(next(session.last_broken) == nil and next(session.last_peak_stress) == nil,
	"the first design edit clears the weak-spot highlight")
