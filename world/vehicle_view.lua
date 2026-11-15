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
	spawn.tint_rgb(v.body, body.tint)
	for _, w in ipairs(v.wheels) do
		spawn.tint_rgb(w, wheel.tint)
	end
	if topper.visual then
		v.topper = spawn.create(topper.visual, 0, 0, 0)
		spawn.tint_rgb(v.topper, topper.tint)
	end
end

function M.create(run)
	M.destroy()
	local def = run.vehicle_def
	view = { def = def, wheels = {}, mark_t = 0, smoke_t = 0 }
	view.body = spawn.create(def.body_visual, 0, 0, 0)
	for i = 1, #def.wheels do
		view.wheels[i] = spawn.create(def.wheel_visual, 0, 0, 0)
	end
	apply_skin(view)
	view.shadow = spawn.create("shadow", 0, 0, 0, 0, def.body.w * 1.1, 1, 2.2)
	spawn.tint(view.shadow, 0, 0, 0, 0.28)
	M.update(run)
end

function M.update(run, geo)
	if not view then return end
	local v = run.vehicle
	local cx, cy = v:center()
	local angle = v:angle()
	local ca, sa = cos_sin(angle)
	local ws = view.wheel_skin and view.wheel_skin.scale or 1
	spawn.set(view.def.body_visual, view.body, cx, cy, 0, angle)
	for i, wh in ipairs(v.wheels) do
		local x, y = v:wheel_pos(i)
		spawn.set(view.def.wheel_visual, view.wheels[i], x, y, 0, wh.angle, ws)
	end
	-- topper sits on the roof, rotating with the chassis
	if view.topper and view.topper_skin then
		local t = view.topper_skin
		local ox = (t.pos[1] or 0) * view.def.body.w
		local oy = (t.pos[2] or 0) * view.def.body.h
		local tx, ty = cx + ox * ca - oy * sa, cy + ox * sa + oy * ca
		local s = t.scale
		if type(s) == "table" then
			spawn.set(t.visual, view.topper, tx, ty, 0, angle, s[1], s[2], s[3])
		else
			spawn.set(t.visual, view.topper, tx, ty, 0, angle, s or 1)
		end
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
			if view.body_skin then
				c = { view.body_skin.tint[1] * 0.7, view.body_skin.tint[2] * 0.7, view.body_skin.tint[3] * 0.7 }
			end
			fx.smoke(rx, ry, 0, c, gas and 2 or 1)
		end
	end
end

function M.destroy()
	if not view then return end
	spawn.delete(view.body)
	for _, w in ipairs(view.wheels) do spawn.delete(w) end
	spawn.delete(view.shadow)
	if view.topper then spawn.delete(view.topper) end
	view = nil
end

function M.exists()
	return view ~= nil
end

return M
