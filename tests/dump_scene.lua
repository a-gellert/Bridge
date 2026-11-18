-- Dumps the live 3D scene (objects + camera) to JSON for tools/preview.js.
-- Env: LEVEL (index), DRIVE (seconds of driving with the reference bridge, 0 = build view),
--      W, H (window size), OUT (json path), VEH (vehicle id)
local mock = require("defold_mock")
local ROOT = package.path:match("^(.-)/%?%.lua")
mock.read_factories(ROOT .. "/world/world.go")
local session = require("game.core.session")
local camera = require("world.camera")
local levels = require("game.levels.levels")

local function env(k, d) return (os.getenv and os.getenv(k)) or d end
mock.window_w, mock.window_h = tonumber(env("W", "1280")), tonumber(env("H", "720"))

local world = mock.load_script(ROOT .. "/world/world.script")
local app = mock.load_script(ROOT .. "/gui/app.gui_script")
local W, G = {}, {}
world.init(W)
app.init(G)
local function frame()
	world.update(W, 1 / 60)
	app.update(G, 1 / 60)
	mock.tick_timers(1 / 60)
	mock.posted = {}
end
for _ = 1, 3 do frame() end

local index = tonumber(env("LEVEL", "1"))
-- unlock everything for previews
local progress = require("game.core.progress")
for i = 1, levels.COUNT do progress.level_state(levels.get(i).id).stars = 3 end
session.load_level(index)
for _ = 1, 3 do frame() end
local drive = tonumber(env("DRIVE", "0"))
if drive > 0 then
	session.apply_hint()
	for _ = 1, 2 do frame() end
	session.start_drive(env("VEH", "truck"))
	for _ = 1, math.floor(drive * 60) do frame() end
else
	-- HINT=0 shows the onboarding ghost plan instead of loading the reference bridge
	if env("HINT", "1") == "1" then session.apply_hint() end
	if env("GUIDE", "0") == "1" then session.set_guide(true) end
	session.selected_node = nil
	for _ = 1, 40 do frame() end
end

local screen = env("SCREEN", "")
local function click_text(str)
	for n in pairs(mock.nodes) do
		if n.alive and n.kind == "text" and n.text == str then
			local x0, y0, x1, y1 = mock.bounds(n.parent or n)
			local layout = require("gui.layout")
			local _, vh = layout.virtual_size(mock.window_w, mock.window_h)
			local k = mock.window_h / vh
			local sx, sy = (x0 + x1) / 2 * k, (y0 + y1) / 2 * k
			for _, ph in ipairs({ { true, false }, { false, true } }) do
				app.on_input(G, hash("touch"), { x = sx * 1280 / mock.window_w, y = sy * 720 / mock.window_h, screen_x = sx, screen_y = sy, pressed = ph[1], released = ph[2] })
			end
			return true
		end
	end
end
if screen == "menu" or screen == "levels" then
	session.exit_to_menu()
	for _ = 1, 3 do frame() end
	if screen == "levels" then click_text("УРОВНИ") for _ = 1, 3 do frame() end end
elseif screen == "result" then
	for _ = 1, 60 * 20 do frame() if session.state == "result" then break end end
	for _ = 1, 120 do frame() end
end

local function num(v) return string.format("%.4f", v) end
local out = { '{"objects":[' }
local first = true
for id, o in pairs(mock.objects) do
	local p, r, s = o.pos, o.rot or { x = 0, y = 0, z = 0, w = 1 }, o.scale or { x = 1, y = 1, z = 1 }
	local t = o.props.tint or { x = 1, y = 1, z = 1, w = 1 }
	local ov = o.props.overlay or { x = 1, y = 1, z = 1, w = 0 }
	local name = o.factory:sub(3)
	out[#out + 1] = (first and "" or ",") .. string.format('{"m":"%s","p":[%s,%s,%s],"q":[%s,%s,%s,%s],"s":[%s,%s,%s],"t":[%s,%s,%s,%s],"o":[%s,%s,%s,%s]}',
		name, num(p.x), num(p.y), num(p.z), num(r.x), num(r.y), num(r.z), num(r.w), num(s.x), num(s.y), num(s.z),
		num(t.x), num(t.y), num(t.z), num(t.w), num(ov.x), num(ov.y), num(ov.z), num(ov.w))
	first = false
end
local function m4(m)
	local v = {}
	for i = 1, 4 do for j = 1, 4 do v[#v + 1] = num(m.m[i][j]) end end
	return "[" .. table.concat(v, ",") .. "]"
end
local theme = require("game.config.themes").get(session.level.theme)
-- GUI nodes (virtual units -> screen px)
local layout = require("gui.layout")
local vw, vh = layout.virtual_size(mock.window_w, mock.window_h)
local k = mock.window_h / vh
local function visible(n)
	local p = n
	while p do
		if not p.enabled or not p.alive then return false end
		p = p.parent
	end
	return n.visible
end
local g = {}
local order = {}
for n in pairs(mock.nodes) do order[#order + 1] = n end
table.sort(order, function(a, b) return (a.seq or 0) < (b.seq or 0) end)
for _, n in ipairs(order) do
	if visible(n) then
		local x0, y0, x1, y1 = mock.bounds(n)
		local c = n.color
		local txt = n.text and (n.text:gsub('["\\]', ' '):gsub('\n', ' ')) or ''
		local sc = n.scale.x
		local pp = n.parent
		while pp do sc = sc * pp.scale.x pp = pp.parent end
		g[#g + 1] = string.format('{"k":"%s","a":"%s","b":[%s,%s,%s,%s],"c":[%s,%s,%s,%s],"t":"%s","fs":%s}', n.kind, n.anim or "",
			num(x0 * k), num(y0 * k), num(x1 * k), num(y1 * k), num(c.x), num(c.y), num(c.z), num(c.w), txt, num(sc * 48 * k))
	end
end
out[#out + 1] = '],"gui":[' .. table.concat(g, ",")
out[#out + 1] = string.format('],"view":%s,"proj":%s,"sky":[%s,%s,%s],"w":%d,"h":%d}', m4(camera.view), m4(camera.proj),
	num(theme.sky[1]), num(theme.sky[2]), num(theme.sky[3]), mock.window_w, mock.window_h)
writefile(env("OUT", ROOT .. "/scene.json"), table.concat(out))
print("   dumped " .. session.level.id .. " state=" .. session.state)
