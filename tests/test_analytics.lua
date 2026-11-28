-- Poki lifecycle + analytics funnel: gameplayStart/Stop must follow the player, not the
-- build/drive toggle; level events are one start -> one complete/fail; run events stay separate;
-- FTUE milestones are one-shot.
local mock = require("defold_mock")
local ROOT = package.path:match("^(.-)/%?%.lua")
mock.read_factories(ROOT .. "/world/world.go")

local calls = {}
local gameplay_starts, gameplay_stops = 0, 0
poki_sdk = {
	get_url_param = function() return nil end,
	measure = function(category, what, action)
		calls[#calls + 1] = { category = category, what = what, action = action }
	end,
	gameplay_start = function() gameplay_starts = gameplay_starts + 1 end,
	gameplay_stop = function() gameplay_stops = gameplay_stops + 1 end,
}

local session = require("game.core.session")
local progress = require("game.core.progress")
local levels = require("game.levels.levels")

local world = mock.load_script(ROOT .. "/world/world.script")
local app = mock.load_script(ROOT .. "/gui/app.gui_script")
local rnd = mock.load_script(ROOT .. "/render/bridge.render_script")
local W, G, R = {}, {}, {}

local function frame(dt)
	dt = dt or 1 / 60
	world.update(W, dt)
	app.update(G, dt)
	rnd.update(R)
	mock.tick_timers(dt)
	local posted = mock.posted
	mock.posted = {}
	for _, m in ipairs(posted) do
		if m.url == "@render:" then rnd.on_message(R, hash(m.id), m.data) end
	end
end

local function frames(n, dt) for _ = 1, n do frame(dt) end end

local function count(category, what, action)
	local n = 0
	for _, c in ipairs(calls) do
		if c.category == category and (what == nil or c.what == what) and (action == nil or c.action == action) then
			n = n + 1
		end
	end
	return n
end

world.init(W)
app.init(G)
rnd.init(R)
frames(3)

assert(session.state == "build" and session.index == 1, "first start opens level 1")
assert(count("level", "1-1", "start") == 1, "one level start when 1-1 loads")
assert(count("ftue", "level1_loaded", "1") == 1, "FTUE level1_loaded once")
assert(count("run", nil, "start") == 0, "no run event before GO")

-- touching the level is the first deliberate gameplay input
local function touch(x, y, pressed, released)
	local a = { x = x, y = y, screen_x = x, screen_y = y, pressed = pressed, released = released }
	return app.on_input(G, hash("touch"), a)
end
touch(640, 360, true, false)
frame()
touch(640, 360, false, true)
frame()
assert(gameplay_starts == 1, "first build touch starts gameplay")
touch(640, 360, true, false)
frame()
touch(640, 360, false, true)
frame()
assert(gameplay_starts == 1, "further touches do not duplicate gameplayStart")

-- build the reference bridge and win with the truck
for _, b in ipairs(levels.get(1).solution) do
	session.select_material(b[1])
	assert(session.try_build(b[2], b[3], b[4], b[5]))
end
frames(2)
assert(count("ftue", "first_beam_built", "1") == 1, "FTUE first_beam_built once")
assert(session.start_drive("truck"))
for _ = 1, 60 * 15 do
	frame()
	if session.state == "result" then break end
end
assert(session.state == "result" and session.result and session.result.won, "truck wins level 1")
assert(count("run", "1-1", "start") == 1, "one run start")
assert(count("run", "1-1", "win") == 1, "one run win")
assert(count("level", "1-1", "complete") == 1, "one level complete")
assert(count("ftue", "first_drive_started", "1") == 1, "FTUE first_drive_started once")
assert(count("ftue", "level1_won", "1") == 1, "FTUE level1_won once")
assert(gameplay_stops == 1, "win result pauses the gameplay session")

-- the win card is a pause; closing it back to building must not add another stop
session.stop_drive()
frames(2)
assert(session.state == "build", "back to building")
assert(gameplay_stops == 1, "build after a win is not an extra gameplayStop")
assert(count("level", "1-1", "fail") == 0, "a won level is never reported as fail")

-- level 2: a collapse and a fast retry are still an active play session
assert(session.load_level(2))
frames(2)
assert(count("level", "1-2", "start") == 1, "one level start when 1-2 loads")
assert(session.start_drive("moto"))
for _ = 1, 60 * 15 do
	frame()
	if session.state == "build" then break end
end
assert(session.state == "build", "empty bridge returns to building")
assert(gameplay_stops == 1, "returning from a failed run does not stop gameplay")
assert(count("level", "1-2", "fail") == 0, "a retryable level is not closed as fail")
assert(count("run", "1-2", nil) >= 2, "run start + fail reason are recorded separately")
assert(count("level", "1-2", "start") == 1, "retrying the run does not duplicate level start")

-- leaving the unresolved level to the menu closes it exactly once
session.exit_to_menu()
frames(2)
assert(count("level", "1-2", "fail") == 1, "leaving an unsolved level reports one fail")
assert(gameplay_stops == 2, "menu stops gameplay")
session.exit_to_menu()
frames(2)
assert(count("level", "1-2", "fail") == 1, "menu exit is idempotent")

assert(count("ftue", "level1_loaded", "1") == 1, "FTUE milestones never repeat")

-- The garage uses the same one-shot flag; the screen itself is covered by test_runtime.
assert(progress.ftue("garage_opened"), "garage FTUE step can be recorded")
assert(not progress.ftue("garage_opened"), "FTUE steps never repeat")
print("   gameplayStart=" .. gameplay_starts .. " gameplayStop=" .. gameplay_stops .. " measures=" .. #calls)

