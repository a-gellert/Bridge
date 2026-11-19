-- Drive HUD: FIX (back to building), vehicle badge, and two big hold pedals for touch screens.
-- Pedals are hit-tested on every touch point, so GAS and BRAKE work with any finger, on any device.
-- On phones they grow and press in with a glowing rim; haptics confirm the touch.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local session = require("game.core.session")
local progress = require("game.core.progress")
local vehicles = require("game.config.vehicles")
local layout = require("gui.layout")
local camera = require("world.camera")
local haptics = require("platform.haptics")

local M = {}

local h = {}
local TOUCH = hash("touch")
local TOUCH_MULTI = hash("touch_multi")

local keys = { gas = false, brake = false }
local touch_gas, touch_brake = false, false

local function pedal_inner(active, inner, glow, glow_color, base)
	if not inner then return end
	local k = active and 0.9 or 1
	gui.animate(inner, gui.PROP_SCALE, vmath.vector3(base.x * k, base.y * k, 1),
		active and gui.EASING_OUTQUAD or gui.EASING_OUTBACK, active and 0.06 or 0.18)
	if glow then
		local c = ui.hex(glow_color, active and 0.55 or 0.14)
		gui.set_color(glow, c)
	end
end

local function apply()
	local g = keys.gas or touch_gas
	local b = keys.brake or touch_brake
	session.set_input(g, b)
	if h.gas then gui.set_color(h.gas, g and ui.GREEN or ui.hex("#35C97E", 0.55)) end
	if h.brake then gui.set_color(h.brake, b and ui.RED or ui.hex("#E5484D", 0.55)) end
	if g ~= h.last_gas then
		if g then haptics.click() end
		pedal_inner(g, h.gas_inner, h.gas_glow, "#7CFFB0", h.gas_base)
	end
	if b ~= h.last_brake then
		if b then haptics.click() end
		pedal_inner(b, h.brake_inner, h.brake_glow, "#FF9AA0", h.brake_base)
	end
	h.last_gas, h.last_brake = g, b
end

local function make_pedal(root, x, y, size, color, glow_color, icon_name, label)
	local node = ui.box(root, "circle", x, y, size, size, color)
	ui.box(node, "glow", 0, 0, size * 1.18, size * 1.18, ui.hex(glow_color, 0.14))
	local inner = ui.pane(node, 0, 0)
	gui.set_size(inner, vmath.vector3(size, size, 0))
	ui.icon(inner, icon_name, 0, 12, size * 0.4)
	ui.text(inner, label, 0, -size * 0.3, 26, ui.WHITE)
	return node, inner, ui.box(node, "ring", 0, 0, size * 0.98, size * 0.98, ui.hex(glow_color, 0.28))
end

function M.build(app, root)
	h = { root = root }
	keys.gas, keys.brake = false, false
	touch_gas, touch_brake = false, false
	h.last_gas, h.last_brake = false, false
	local vw, vh = app.vw, app.vh
	local ml, mr, mt, mb = layout.margins(vw, vh, 16)

	ui.btn(root, ml + 120, vh - mt - 44, 220, 80, i18n.t("fix"), function()
		session.stop_drive()
	end, { icon = "wrench", icon_size = 40, color = ui.ORANGE, size = 30 })

	local def = vehicles.get(session.vehicle)
	local badge = ui.panel(root, vw - mr - 130, vh - mt - 44, 240, 80, ui.PANEL, 24)
	ui.icon(badge, def.icon, -70, 2, 60)
	for i = 1, 3 do
		ui.icon(badge, i <= def.stars and "star" or "star_slot", 10 + (i - 1) * 36, 2, 32, i <= def.stars and ui.STAR or ui.STAR_OFF)
	end

	-- pedals (always shown: they also work with a mouse)
	local size = app.touch and (app.portrait and 236 or 204) or (app.portrait and 200 or 180)
	local px = (size - 180) * 0.5
	h.brake, h.brake_inner, h.brake_glow = make_pedal(root, ml + size / 2 + 10 - px, mb + size / 2 + 10 - px,
		size, ui.hex("#E5484D", 0.55), "#FF9AA0", "pedal_brake", i18n.t("brake"))
	h.gas, h.gas_inner, h.gas_glow = make_pedal(root, vw - mr - size / 2 - 10 + px, mb + size / 2 + 10 - px,
		size, ui.hex("#35C97E", 0.55), "#7CFFB0", "pedal_gas", i18n.t("gas"))
	h.gas_base = vmath.vector3(1, 1, 1)
	h.brake_base = vmath.vector3(1, 1, 1)

	if not app.controls_tip_shown and session.index ~= 1 and progress.stats().losses > 0 then
		app.controls_tip_shown = true
		local tw = math.min(720, vw - ml - mr - 40)
		local tip = ui.panel(root, vw / 2, vh - mt - 140, tw, 80, ui.hex("#151926", 0.82), 22)
		ui.label(tip, i18n.t(app.touch and "tip_controls_touch" or "tip_controls_pc"), 0, 0, 24, ui.WHITE, tw - 40, 2)
		gui.animate(tip, "color.w", 0, gui.EASING_INQUAD, 0.6, 5, function() gui.set_enabled(tip, false) end)
	end
	-- teach the stress colours only after the player has already fallen on a brace-hint level
	if session.level and session.level.brace_hint
		and progress.fail_streak(session.level.id) >= 1 and not progress.get("stress_tip_done") then
		progress.set_setting("stress_tip_done", true)
		local tw = math.min(620, vw - ml - mr - 40)
		local tip = ui.panel(root, vw / 2, vh - mt - 236, tw, 64, ui.hex("#151926", 0.82), 22)
		ui.label(tip, i18n.t("tip_stress"), 0, 0, 22, ui.WHITE, tw - 34, 2)
		gui.animate(tip, "color.w", 0, gui.EASING_INQUAD, 0.6, 7, function() gui.set_enabled(tip, false) end)
	end
	camera.set_insets(0, 0)
	apply()
end

-- Raw pointer handling for the pedals. Returns true when a pedal is touched.
function M.on_input(app, action_id, action)
	if not h.gas then return false end
	if action_id == TOUCH_MULTI and action.touch then
		local g, b = false, false
		for _, t in ipairs(action.touch) do
			if not t.released then
				if gui.pick_node(h.gas, t.x, t.y) then g = true end
				if gui.pick_node(h.brake, t.x, t.y) then b = true end
			end
		end
		touch_gas, touch_brake = g, b
		app.multitouch = true
		apply()
		return g or b
	elseif action_id == TOUCH and not app.multitouch then
		local down = not action.released
		touch_gas = down and gui.pick_node(h.gas, action.x, action.y) or false
		touch_brake = down and gui.pick_node(h.brake, action.x, action.y) or false
		apply()
		return touch_gas or touch_brake
	end
	return false
end

function M.on_key(app, action_id, action)
	local name = app.key_names[action_id]
	if name == "gas" or name == "brake" then
		if action.pressed then keys[name] = true elseif action.released then keys[name] = false end
		apply()
		return true
	end
	-- Space / Enter toggles like in the build screen: launch there, back to the bridge here
	if (name == "reset" or name == "back" or name == "go") and action.pressed then
		session.stop_drive()
		return true
	end
	return false
end

function M.clear()
	h = {}
	keys.gas, keys.brake = false, false
	touch_gas, touch_brake = false, false
end

return M
