-- Session flow: load -> build -> drive -> result -> progress/unlocks; failure path; hint; persistence.
local progress = require("game.core.progress")
local events = require("game.core.events")
local session = require("game.core.session")
local levels = require("game.levels.levels")

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

-- level 1: fail with nothing built
assert(session.load_level(1))
local res = drive("moto")
assert(res and not res.won and res.reason == "fell", "empty bridge must fail")
assert(session.state == "result")
assert(session.stop_drive() and session.state == "build", "back to build")

-- build the road and send the bike: 1 star
local lvl = levels.get(1)
local b = lvl.solution[1]
assert(session.try_build(b[2], b[3], b[4], b[5]))
res = drive("moto")
assert(res.won and res.stars == 1 and res.new_stars == 1, "bike gives 1 star")
assert(progress.level_unlocked(2), "level 2 unlocked after a star")
session.stop_drive()

-- the truck right away gives 3 stars
res = drive("truck")
assert(res.won and res.stars == 3 and res.new_stars == 2, "truck gives 3 stars")
assert(res.cost == 360 and res.budget == 450, "budget info")
assert(progress.total_stars() == 3)

-- the design is saved and restored
session.exit_to_menu()
assert(session.load_level(1))
assert(session.blueprint:beam_count() == 1, "design restored")

-- hint loads the reference design, undo reverts it
assert(session.load_level(2))
-- no entry tutorial: the old plan is gone; the dashed brace hint is a reaction to failure
assert(not levels.get(1).guide and not levels.get(2).guide and not levels.get(3).guide, "no plan before failure")
assert(not levels.get(1).tip and not levels.get(1).assist and levels.get(1).no_build_zone,
	"level 1 has no text plate, no forced material and no highlighted build zone")
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
assert(session.blueprint.budget == 563, "450 + 25% = 563, got " .. tostring(session.blueprint.budget))
assert(not session.apply_budget_bonus(), "bonus only once per attempt")
