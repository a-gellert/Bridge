-- Vehicle visuals: body + wheels + a soft shadow, driven by the simulation.
local spawn = require("world.spawn")
local vehicles = require("game.config.vehicles")
local terrain = require("game.physics.terrain")

local M = {}

local view = nil

function M.create(run)
	M.destroy()
	local def = run.vehicle_def
	view = { def = def, wheels = {} }
	view.body = spawn.create(def.body_visual, 0, 0, 0)
	for i = 1, #def.wheels do
		view.wheels[i] = spawn.create(def.wheel_visual, 0, 0, 0)
	end
	view.shadow = spawn.create("shadow", 0, 0, 0, 0, def.body.w * 1.1, 1, 2.2)
	spawn.tint(view.shadow, 0, 0, 0, 0.28)
	M.update(run)
end

function M.update(run, geo)
	if not view then return end
	local v = run.vehicle
	local cx, cy = v:center()
	spawn.set(view.def.body_visual, view.body, cx, cy, 0, v:angle())
	for i, wh in ipairs(v.wheels) do
		local x, y = v:wheel_pos(i)
		spawn.set(view.def.wheel_visual, view.wheels[i], x, y, 0, wh.angle)
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
end

function M.destroy()
	if not view then return end
	spawn.delete(view.body)
	for _, w in ipairs(view.wheels) do spawn.delete(w) end
	spawn.delete(view.shadow)
	view = nil
end

function M.exists()
	return view ~= nil
end

return M
