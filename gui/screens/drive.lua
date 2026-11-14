-- Drive HUD: FIX (back to building), vehicle badge, and two big hold pedals for touch screens.
-- Pedals are hit-tested on every touch point, so GAS and BRAKE work with any finger, on any device.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local session = require("game.core.session")
local vehicles = require("game.config.vehicles")
local camera = require("world.camera")

local M = {}

local h = {}
local TOUCH = hash("touch")
local TOUCH_MULTI = hash("touch_multi")

local keys = { gas = false, brake = false }
local touch_gas, touch_brake = false, false

local function apply()
	session.set_input(keys.gas or touch_gas, keys.brake or touch_brake)
	if h.gas then gui.set_color(h.gas, (keys.gas or touch_gas) and ui.GREEN or ui.hex("#35C97E", 0.55)) end
	if h.brake then gui.set_color(h.brake, (keys.brake or touch_brake) and ui.RED or ui.hex("#E5484D", 0.55)) end
end

function M.build(app, root)
	h = { root = root }
	keys.gas, keys.brake = false, false
	touch_gas, touch_brake = false, false
	local vw, vh = app.vw, app.vh
	local m = 16

	ui.btn(root, m + 120, vh - m - 44, 220, 80, i18n.t("fix"), function()
		session.stop_drive()
	end, { icon = "wrench", icon_size = 40, color = ui.ORANGE, size = 30 })

	local def = vehicles.get(session.vehicle)
	local badge = ui.panel(root, vw - m - 130, vh - m - 44, 240, 80, ui.PANEL, 24)
	ui.icon(badge, def.icon, -70, 2, 60)
	for i = 1, 3 do
		ui.icon(badge, i <= def.stars and "star" or "star_slot", 10 + (i - 1) * 36, 2, 32, i <= def.stars and ui.STAR or ui.STAR_OFF)
	end

	-- pedals (shown on every device: they also work with the mouse)
	local size = app.portrait and 200 or 180
	h.brake = ui.box(root, "circle", m + size / 2 + 10, m + size / 2 + 10, size, size, ui.hex("#E5484D", 0.55))
	ui.icon(h.brake, "pedal_brake", 0, 12, size * 0.4)
	ui.text(h.brake, i18n.t("brake"), 0, -size * 0.3, 26, ui.WHITE)
	h.gas = ui.box(root, "circle", vw - m - size / 2 - 10, m + size / 2 + 10, size, size, ui.hex("#35C97E", 0.55))
	ui.icon(h.gas, "pedal_gas", 0, 12, size * 0.4)
	ui.text(h.gas, i18n.t("gas"), 0, -size * 0.3, 26, ui.WHITE)

	if not app.controls_tip_shown then
		app.controls_tip_shown = true
		local tw = math.min(720, vw - 60)
		local tip = ui.panel(root, vw / 2, vh - m - 140, tw, 80, ui.hex("#151926", 0.82), 22)
		ui.label(tip, i18n.t(app.touch and "tip_controls_touch" or "tip_controls_pc"), 0, 0, 24, ui.WHITE, tw - 40, 2)
		gui.animate(tip, "color.w", 0, gui.EASING_INQUAD, 0.6, 5, function() gui.set_enabled(tip, false) end)
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
	if (name == "reset" or name == "back") and action.pressed then
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
