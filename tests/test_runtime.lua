-- Headless runtime test: runs world.script, app.gui_script and the render script on the Defold mock and
-- plays the game through the UI (screen-space touches, buttons found by their labels, keyboard).
local mock = require("defold_mock")
local ROOT = package.path:match("^(.-)/%?%.lua")
mock.read_factories(ROOT .. "/world/world.go")

local layout = require("gui.layout")
local camera = require("world.camera")
local session = require("game.core.session")
local progress = require("game.core.progress")
local levels = require("game.levels.levels")
local i18n = require("game.core.i18n")

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

local function frames(n, dt)
	for _ = 1, n do frame(dt) end
end

-- ------------------------------------------------------------------ input helpers
local function send(action_id, sx, sy, pressed, released)
	local a = {
		x = sx * 1280 / mock.window_w, y = sy * 720 / mock.window_h,
		screen_x = sx, screen_y = sy, pressed = pressed, released = released,
	}
	return app.on_input(G, action_id and hash(action_id) or nil, a)
end

local function tap_screen(sx, sy)
	send("touch", sx, sy, true, false)
	send("touch", sx, sy, false, true)
	frame()
end

local function drag_screen(x0, y0, x1, y1)
	send("touch", x0, y0, true, false)
	for i = 1, 6 do
		local t = i / 6
		send("touch", x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, false, false)
	end
	send("touch", x1, y1, false, true)
	frame()
end

local function world_screen(x, y)
	return camera.world_to_screen(x, y, 1.3)
end

local function key(name, pressed, released)
	return app.on_input(G, hash(name), { pressed = pressed, released = released })
end

local function press_key(name)
	key(name, true, false)
	key(name, false, true)
	frame()
end

-- find a live text node by exact text
local function find_text(str)
	for n in pairs(mock.nodes) do
		if n.alive and n.kind == "text" and n.text == str and gui.is_enabled(n, true) then return n end
	end
	return nil
end

local function click_node(n)
	local x0, y0, x1, y1 = mock.bounds(n)
	local vw, vh = layout.virtual_size(mock.window_w, mock.window_h)
	local k = mock.window_h / vh
	tap_screen((x0 + x1) / 2 * k, (y0 + y1) / 2 * k)
end

local function click_text(str)
	local t = find_text(str)
	assert(t, "button with label '" .. str .. "' not found")
	click_node(t.parent or t)
end

local function count_objects()
	local n = 0
	for _ in pairs(mock.objects) do n = n + 1 end
	return n
end

-- ------------------------------------------------------------------ scenario
world.init(W)
app.init(G)
rnd.init(R)
frames(3)

-- first start: straight into level 1 build mode (no stars yet)
assert(session.state == "build" and session.index == 1, "first start should open level 1, state=" .. session.state)
assert(find_text("ПУСК!"), "build HUD with GO button")
assert(count_objects() > 20, "level visuals spawned")
-- level 1 is completely clean: no plan overlay, no text plate, no forced tutorial step
assert(not find_text("ПЛАН"), "no tutorial plan on the first level")
assert(not session.guide, "level 1 never shows a hint before a failure")
assert(not levels.get(1).guide and not levels.get(1).brace_hint, "level 1 has no tutorial data")

-- build the road by dragging from the left anchor to the right one
local ax, ay = world_screen(0, 0)
local bx, by = world_screen(3, 0)
drag_screen(ax, ay, bx, by)
assert(session.blueprint:beam_count() == 1, "drag builds one beam, got " .. session.blueprint:beam_count())
assert(session.guide_has_beam(session.level.solution[1]), "built beam matches the plan")

-- launch the truck (default vehicle) with the GO button
click_text("ПУСК!")
assert(session.state == "drive", "GO starts the drive, state=" .. session.state)
for _ = 1, 60 * 12 do
	frame()
	if session.state == "result" then break end
end
assert(session.state == "result", "run finished")
local res = session.result
assert(res.won and res.stars == 3, "truck across level 1 gives 3 stars")
frames(60)
assert(find_text("ДОСТАВЛЕНО!"), "win popup shown")
assert(find_text("$360 из $450"), "budget line shown")

-- next level through the popup button (no Poki SDK -> no ad)
click_text("ДАЛЬШЕ")
frames(2)
assert(session.state == "build" and session.index == 2, "NEXT opens level 2")

-- portrait phone: HUD rebuilds after the resize
mock.window_w, mock.window_h = 720, 1560
frames(20)
assert(find_text("ПУСК!"), "portrait build HUD")

-- tap-tap building: tap the anchor, then tap where the beam ends
ax, ay = world_screen(0, 0)
tap_screen(ax, ay)
assert(session.selected_node, "tap on an anchor selects it")
bx, by = world_screen(3, 0)
tap_screen(bx, by)
assert(session.blueprint:beam_count() == 1, "tap-tap built a beam")
assert(session.selected_node, "end joint stays selected for chaining")
local cx, cy = world_screen(6, 0)
tap_screen(cx, cy)
assert(session.blueprint:beam_count() == 2, "chained second beam")

-- Esc peels one layer at a time: the selection first, the level only after that
assert(session.selected_node, "chain end is selected")
press_key("back")
assert(session.state == "build" and not session.selected_node, "Esc drops the selection, stays in the level")

-- erase tool removes the beam under the finger, undo brings it back
click_text("ЛАСТИК")
assert(session.tool == "erase")
local mx, my = world_screen(1.5, 0)
tap_screen(mx, my)
assert(session.blueprint:beam_count() == 1, "erased one beam")
press_key("undo")
assert(session.blueprint:beam_count() == 2, "undo restores it")
-- one swipe across both beams deletes both, undo twice restores them
local sx0, sy0 = world_screen(1.5, 0)
local sx1, sy1 = world_screen(4.5, 0)
drag_screen(sx0, sy0, sx1, sy1)
assert(session.blueprint:beam_count() == 0, "eraser swipe deletes every beam it crosses")
press_key("undo")
press_key("undo")
assert(session.blueprint:beam_count() == 2, "undo restores the swiped beams")
-- Esc leaves the eraser before it leaves the level
press_key("back")
assert(session.state == "build" and session.tool == "build", "Esc switches the eraser off")
click_text("ЛАСТИК")

-- a tap on the HUD must not build or pan the world
local before = session.blueprint:beam_count()
click_text("ЛАСТИК")
assert(session.blueprint:beam_count() == before)

-- keyboard drive: GO, hold gas, then R back to the bridge
press_key("go")
assert(session.state == "drive", "space/enter launches")
key("gas", true, false)
frames(30)
assert(session.input.gas, "gas key held")
key("gas", false, true)
press_key("reset")
assert(session.state == "build", "R returns to building")
press_key("go")
assert(session.state == "drive", "space launches again")
press_key("go")
assert(session.state == "build", "space toggles back to building")

-- pedals on a touch screen (portrait): press GAS
press_key("go")
local gas = find_text("ГАЗ")
assert(gas, "gas pedal shown")
local x0, y0, x1, y1 = mock.bounds(gas.parent)
local vw, vh = layout.virtual_size(mock.window_w, mock.window_h)
local k = mock.window_h / vh
send("touch", (x0 + x1) / 2 * k, (y0 + y1) / 2 * k, true, false)
frame()
assert(session.input.gas, "touching the GAS pedal accelerates")
send("touch", (x0 + x1) / 2 * k, (y0 + y1) / 2 * k, false, true)
frame()
assert(not session.input.gas, "releasing the pedal")
click_text("ЧИНИТЬ")
assert(session.state == "build", "FIX button returns to building")

-- back to the menu, then the level list, then a level card
press_key("back")
frames(2)
assert(session.state == "menu", "back -> menu")
assert(find_text("УРОВНИ"), "menu shown")
click_text("УРОВНИ")
frames(2)
assert(find_text("1-1"), "level list shown")
click_text("1-1")
frames(2)
assert(session.state == "build" and session.index == 1, "level card opens the level")
assert(session.blueprint:beam_count() == 1, "saved design restored")

-- landscape again, hint (rewarded without SDK), language switch in the menu
mock.window_w, mock.window_h = 1600, 900
frames(20)
session.clear()
local hint_btn
for n in pairs(mock.nodes) do
	if n.alive and n.anim == "hint" and n.parent and n.parent.kind == "box" then hint_btn = n.parent end
end
assert(hint_btn, "hint button")
click_node(hint_btn)
assert(session.blueprint:beam_count() == #session.level.solution, "hint loads the reference bridge")
press_key("back")
frames(2)
click_text("RU")
frames(2)
assert(find_text("ЯЗЫК"), "language picker opens")
for _, name in ipairs({ "English", "Русский", "Deutsch", "Français", "Español", "Italiano", "Português", "Polski", "Türkçe", "Nederlands" }) do
	assert(find_text(name), "language picker lists " .. name)
end
click_text("Deutsch")
frames(2)
assert(find_text("SPIELEN  1-2") or find_text("SPIELEN  1-1"), "German menu")
click_text("DE")
frames(2)
click_text("English")
frames(2)
assert(find_text("PLAY  1-2") or find_text("PLAY  1-1"), "language switched back to English")

-- garage: select the owned classic paint, then back to the menu
click_text("GARAGE")
frames(3)
assert(find_text("PAINT"), "garage paint tab")
assert(find_text("Classic"), "garage shows the owned paint")
click_text("Classic")
frames(3)
assert(find_text("EQUIPPED"), "owned skin can be equipped")
press_key("back")
frames(2)
assert(find_text("AWARDS"), "back from the garage to the menu")

-- achievements screen shows the unlocked first-bridge award
click_text("AWARDS")
frames(3)
assert(find_text("First Engineer"), "unlocked achievement listed")
press_key("back")
frames(2)
assert(find_text("PLAY  1-2") or find_text("PLAY  1-1"), "back from awards")

-- dynamic assist UI: three defeats -> rewarded +25% budget button
for _ = 1, 3 do
	session.load_level(1)
	session.clear()
	session.start_drive("moto")
	for _ = 1, 600 do
		session.update(1 / 60)
		if session.state == "result" then break end
	end
	assert(session.state == "result", "empty bridge run finished")
end
assert(session.result and session.result.can_assist, "assist is offered after three defeats")
frames(5)
assert(find_text("+25% BUDGET"), "budget assist button")
click_text("+25% BUDGET")
frames(4)
assert(session.state == "build", "assist returns to the bridge")
assert(session.blueprint.budget == 563, "budget bonus applied: " .. tostring(session.blueprint.budget))

-- 1. Single collapse: fast 0.1s return to build mode, blueprint preserved intact
session.load_level(2)
session.clear()
session.try_build(0, 0, 2, 0) -- half-bridge into the void on level 2
assert(session.blueprint:beam_count() == 1, "has one beam")
session.start_drive("moto")
for _ = 1, 600 do
	frame()
	if session.state == "build" then break end
end
assert(session.state == "build", "instantly back to build after collapse")
assert(session.blueprint:beam_count() == 1, "blueprint preserved intact, not reset")
assert(session.index == 2, "still on level 2")

-- post-failure hint: two collapses on level 3 arm the dashed braces, the first touch clears them
local function count_zones()
	local n = 0
	for _, o in pairs(mock.objects) do if o.factory == "f_zone" then n = n + 1 end end
	return n
end
session.load_level(3)
frames(2)
session.clear()
local zones0 = count_zones()
for i = 1, 2 do
	assert(not session.guide, "no brace hint before collapse " .. i)
	session.start_drive("moto")
	for _ = 1, 600 do
		frame()
		if session.state == "build" then break end
	end
	assert(session.state == "build", "fast return after collapse " .. i .. " on level 3")
end
assert(session.guide, "dashed brace hint appears after the second collapse")
frames(2)
assert(count_zones() > zones0, "dashed brace nodes reach the world")
app.on_input(G, hash("touch"), { x = 10, y = 10, screen_x = 10, screen_y = 10, pressed = true })
app.on_input(G, hash("touch"), { x = 10, y = 10, screen_x = 10, screen_y = 10, released = true })
frames(2)
assert(not session.guide and count_zones() == zones0, "first screen touch dismisses and removes the hint")

-- 2. Auto-transition to next level on 3 stars without manual click
session.load_level(1)
session.clear()
local b1 = levels.get(1).solution[1]
session.try_build(b1[2], b1[3], b1[4], b1[5])
session.start_drive("truck")
for _ = 1, 60 * 10 do
	frame()
	if session.index == 2 then break end
end
assert(session.index == 2, "seamlessly advanced to level 2 on 3 stars")

-- 3. Biome milestone: completing level 8 offers to transition to a new setting
session.load_level(8)
session.clear()
for _, b in ipairs(levels.get(8).solution) do
	session.select_material(b[1])
	session.try_build(b[2], b[3], b[4], b[5])
end
session.start_drive("truck")
for _ = 1, 60 * 15 do
	frame()
	if session.state == "result" then break end
end
assert(session.state == "result", "level 8 completed")
frames(10)
assert(find_text("НОВЫЙ СЕТТИНГ!") or find_text("NEW SETTING!"), "biome switch prompt shown on level 8")
local canyon_text = i18n.f("biome_offer_go", i18n.pick(levels.chapters[2].name))
local canyon_btn = find_text(canyon_text)
assert(canyon_btn, "next setting option button: " .. tostring(canyon_text))
click_text(canyon_text)
frames(5)
assert(session.level.chapter_index == 2, "transitioned to Red Canyon biome")
assert(session.level.id == "2-1", "first level of new setting loaded")

-- HUD survives desktop, tablet and tall phone canvases
for _, s in ipairs({ { 1920, 1080 }, { 1024, 768 }, { 1170, 2532 } }) do
	mock.window_w, mock.window_h = s[1], s[2]
	frames(20)
	assert(find_text("GO!") or find_text("ПУСК!"), "build HUD at " .. s[1] .. "x" .. s[2])
end

-- persistence went through sys.save
local saved = mock.saved["bridge_mad/progress"]
assert(saved and saved.levels["1-1"].stars == 3, "progress saved")

-- no runaway object count
assert(count_objects() < 900, "objects: " .. count_objects())
print("   objects alive: " .. count_objects())
