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
assert(not progress.chapter_unlocked(2), "chapter 2 locked")

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
session.clear()
assert(session.apply_hint())
assert(session.blueprint:beam_count() == #levels.get(2).solution)
assert(session.undo())
assert(session.blueprint:beam_count() == 0)

-- events were emitted
local evs = events.drain("test")
local seen = {}
for _, e in ipairs(evs) do seen[e.id] = true end
for _, id in ipairs({ "level_loaded", "drive_started", "result", "built", "design_changed", "hint", "state" }) do
	assert(seen[id], "event " .. id)
end

-- persistence survived through the storage backend
assert(store and store.levels["1-1"].stars == 3)
