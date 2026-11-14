-- Vehicles catalog. Each vehicle that reaches point B gives `stars` (stars of a level = best vehicle).
-- Physics: a rigid 4-particle body (w x h) + wheels on springy mounts.
--   body.mass      kg, spread over the 4 corners
--   wheels[i]      x, y relative to body center, r radius, mass
--   max_speed      m/s at full throttle, cruise = auto-drive throttle (0..1)
--   accel          wheel surface acceleration (m/s^2) delivered by the engine
--   susp_stiffness N/m per wheel, susp_damping = fraction of mount velocity removed per second
--   air_torque     rad/s^2 for mid-air tilting (gas = nose down, brake = nose up)
-- Visuals: `body_visual` / `wheel_visual` are ids from game/config/visuals.lua.
local M = {}

M.list = {
	{
		id = "moto", name_key = "veh_moto", icon = "veh_moto", stars = 1,
		body = { w = 1.5, h = 0.5, mass = 150, corner_r = 0.12 },
		wheels = {
			{ x = -0.62, y = -0.34, r = 0.36, mass = 10 },
			{ x = 0.64, y = -0.34, r = 0.36, mass = 10 },
		},
		max_speed = 13, cruise = 0.62, accel = 8, brake = 14, reverse = 3,
		grip = 1.25, susp_stiffness = 14000, susp_damping = 14, air_torque = 7,
		body_visual = "veh_moto", wheel_visual = "wheel_moto",
	},
	{
		id = "car", name_key = "veh_car", icon = "veh_car", stars = 2,
		body = { w = 2.6, h = 0.7, mass = 650, corner_r = 0.14 },
		wheels = {
			{ x = -0.95, y = -0.42, r = 0.42, mass = 25 },
			{ x = 0.98, y = -0.42, r = 0.42, mass = 25 },
		},
		max_speed = 12, cruise = 0.62, accel = 6.5, brake = 12, reverse = 3,
		grip = 1.2, susp_stiffness = 50000, susp_damping = 14, air_torque = 4.5,
		body_visual = "veh_car", wheel_visual = "wheel_car",
	},
	{
		id = "truck", name_key = "veh_truck", icon = "veh_truck", stars = 3,
		body = { w = 4.2, h = 1.1, mass = 1700, corner_r = 0.16 },
		wheels = {
			{ x = -1.55, y = -0.62, r = 0.5, mass = 45 },
			{ x = -0.5, y = -0.62, r = 0.5, mass = 45 },
			{ x = 1.45, y = -0.62, r = 0.5, mass = 45 },
		},
		max_speed = 10, cruise = 0.65, accel = 5, brake = 10, reverse = 2.5,
		grip = 1.2, susp_stiffness = 90000, susp_damping = 14, air_torque = 2.6,
		body_visual = "veh_truck", wheel_visual = "wheel_truck",
	},
}

M.by_id = {}
for i, v in ipairs(M.list) do
	v.order = i
	M.by_id[v.id] = v
end

function M.get(id)
	return M.by_id[id]
end

-- Lowest point of the vehicle below the body center (used to spawn it on the ground).
function M.ground_offset(def)
	local off = def.body.h * 0.5
	for _, w in ipairs(def.wheels) do
		off = math.max(off, -w.y + w.r)
	end
	return off
end

return M
