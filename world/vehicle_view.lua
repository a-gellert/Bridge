-- Vehicle visuals: body + wheels + roof topper + a soft shadow, driven by the simulation.
-- Cosmetic skins come from game/config/skins.lua (progress stores the player's choices).
local spawn = require("world.spawn")
local vehicles = require("game.config.vehicles")
local skins = require("game.config.skins")
local terrain = require("game.physics.terrain")
local progress = require("game.core.progress")
local fx = require("world.fx")

local M = {}

local view = nil

local function cos_sin(a)
	return math.cos(a), math.sin(a)
end

local function apply_skin(v)
	local def = v.def
	local body = skins.get("body", progress.skin_for("body", def.id))
	local wheel = skins.get("wheel", progress.skin_for("wheel", def.id))
	local topper = skins.get("topper", progress.skin_for("topper", def.id))
	v.body_skin, v.wheel_skin, v.topper_skin = body, wheel, topper
	if v.paint then spawn.tint_rgb(v.paint, skins.paint_tint(def, body)) end
	for _, w in ipairs(v.wheels) do
		spawn.tint_rgb(w, wheel.tint)
	end
	if topper.visual then
		v.topper = spawn.create(topper.visual, 0, 0, 0)
		if topper.tint then spawn.tint_rgb(v.topper, topper.tint) end
	end
end

local function make_view(def)
	local v = { def = def, wheels = {}, mark_t = 0, smoke_t = 0 }
	v.body = spawn.create(def.body_visual, 0, 0, 0)
	if def.paint_visual then v.paint = spawn.create(def.paint_visual, 0, 0, 0) end
	for i = 1, #def.wheels do
		v.wheels[i] = spawn.create(def.wheel_visual, 0, 0, 0)
	end
	apply_skin(v)
	v.shadow = spawn.create("shadow", 0, 0, 0, 0, def.body.w * 1.1, 1, 2.2)
	spawn.tint(v.shadow, 0, 0, 0, 0.28)
	return v
end

local function place_static(v, cx, cy, angle, geo)
	local def = v.def
	local ca, sa = cos_sin(angle or 0)
	spawn.set(def.body_visual, v.body, cx, cy, 0, angle)
	if v.paint then spawn.set(def.paint_visual, v.paint, cx, cy, 0, angle) end
	local ws = v.wheel_skin and v.wheel_skin.scale or 1
	for i, wh in ipairs(def.wheels) do
		local x, y = cx + wh.x * ca - wh.y * sa, cy + wh.x * sa + wh.y * ca
		spawn.set(def.wheel_visual, v.wheels[i], x, y, 0, angle, ws)
	end
	if v.topper and v.topper_skin then
		local t = v.topper_skin
		local mount = def.mounts and def.mounts[t.mount or "roof"]
		local ox = mount and mount.x or 0
		local oy = mount and mount.y or def.body.h * 0.5
		local tx, ty = cx + ox * ca - oy * sa, cy + ox * sa + oy * ca
		spawn.set(t.visual, v.topper, tx, ty, 0, angle, (def.topper_scale or 1) * (t.scale or 1))
	end
	-- a crisp contact shadow on the home bank
	local h = geo and terrain.height_at(geo, cx, cy)
	if h and cy - h < 3 then
		local k = math.max(0.25, 1 - (cy - h) / 3)
		spawn.set("shadow", v.shadow, cx, h + 0.17, 0, 0, def.body.w * (0.6 + 0.5 * k), 1, 2.2)
		spawn.tint(v.shadow, 0, 0, 0, 0.3 * k)
	else
		spawn.tint(v.shadow, 0, 0, 0, 0)
	end
end

function M.create(run)
	M.destroy()
	local def = run.vehicle_def
	view = make_view(def)
	M.update(run)
end

-- Static vehicle on the start pad while the player builds: the goal "carry THIS truck
-- across" reads from the first second, before any tutorial text.
function M.create_preview(level, vehicle_id, geo)
	M.destroy()
	local def = vehicles.get(vehicle_id)
	if not def or not level then return end
	view = make_view(def)
	local sx = level.start
	local ground = geo and terrain.height_at(geo, sx) or 0
	local cy = ground + vehicles.ground_offset(def) + 0.04
	place_static(view, sx, cy, 0, geo)
end

function M.update(run, geo)
	if not view then return end
	local v = run.vehicle
	local cx, cy = v:center()
	local angle = v:angle()
	local ca, sa = cos_sin(angle)
	local ws = view.wheel_skin and view.wheel_skin.scale or 1
	spawn.set(view.def.body_visual, view.body, cx, cy, 0, angle)
	if view.paint then spawn.set(view.def.paint_visual, view.paint, cx, cy, 0, angle) end
	for i, wh in ipairs(v.wheels) do
		local x, y = v:wheel_pos(i)
		spawn.set(view.def.wheel_visual, view.wheels[i], x, y, 0, wh.angle, ws)
	end
	-- a warm pulse while a stunt combo is alive: readable at a glance without extra HUD
	local combo = run.stunts and run.stunts.combo or 0
	local glow = combo >= 3 and (0.07 + 0.04 * math.sin((run.time or 0) * 12)) or 0
	spawn.overlay(view.body, 1, 0.82, 0.3, glow)
	if view.paint then spawn.overlay(view.paint, 1, 0.82, 0.3, glow) end
	-- topper sits on its mount point (roof / rear), rotating with the chassis
	if view.topper and view.topper_skin then
		local t = view.topper_skin
		local mount = view.def.mounts and view.def.mounts[t.mount or "roof"]
		local ox = mount and mount.x or 0
		local oy = mount and mount.y or view.def.body.h * 0.5
		local tx, ty = cx + ox * ca - oy * sa, cy + ox * sa + oy * ca
		spawn.set(t.visual, view.topper, tx, ty, 0, angle, (view.def.topper_scale or 1) * (t.scale or 1))
	end
	-- shadow on the terrain right below (hidden over gaps and when far above)
	local h = geo and terrain.height_at(geo, cx, cy)
	if h and cy - h < 6 then
		local k = math.max(0.2, 1 - (cy - h) / 6)
		spawn.set("shadow", view.shadow, cx, h + 0.17, 0, 0, view.def.body.w * (0.6 + 0.5 * k), 1, 2.2)
		spawn.tint(view.shadow, 0, 0, 0, 0.3 * k)
	else
		spawn.tint(view.shadow, 0, 0, 0, 0)
	end
	-- skid marks and exhaust smoke while the engine works
	local speed = v:speed()
	local gas = v.input.gas and v.enabled
	view.mark_t = view.mark_t - (1 / 60)
	view.smoke_t = view.smoke_t - (1 / 60)
	if geo and speed > 3.2 and (gas or v.input.brake) then
		if view.mark_t <= 0 then
			view.mark_t = 0.085
			local rx = cx - ca * view.def.body.w * 0.35
			local ry = cy - sa * view.def.body.w * 0.35
			local hh = terrain.height_at(geo, rx, ry)
			if hh and math.abs(hh - ry) < 1.2 then
				fx.skid(rx, hh + 0.16, 0, angle, 0.7, 0.3)
			end
		end
		if view.smoke_t <= 0 then
			view.smoke_t = 0.13
			local rx = cx - ca * (view.def.body.w * 0.55)
			local ry = cy - sa * (view.def.body.w * 0.55) - 0.15
			local c = { 0.62, 0.62, 0.66 }
			if view.body_skin and view.body_skin.color then
				local p = view.body_skin.color
				c = { 0.45 + p[1] * 0.3, 0.45 + p[2] * 0.3, 0.45 + p[3] * 0.3 } -- a hint of the paint in grey smoke
			end
			fx.smoke(rx, ry, 0, c, gas and 2 or 1)
		end
	end
end

function M.destroy()
	if not view then return end
	spawn.delete(view.body)
	if view.paint then spawn.delete(view.paint) end
	for _, w in ipairs(view.wheels) do spawn.delete(w) end
	spawn.delete(view.shadow)
	if view.topper then spawn.delete(view.topper) end
	view = nil
end

function M.exists()
	return view ~= nil
end

return M
