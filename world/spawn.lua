-- Spawning and transforming visuals through the registry (game/config/visuals.lua).
-- Must be called from world.script (factory.create / go.* only work in game object scripts).
local visuals = require("game.config.visuals")

local M = {}

local V3, V4 = vmath.vector3, vmath.vector4
local rad = math.rad
local tmp_pos = vmath.vector3()
local tmp_scale = vmath.vector3()
local Z_AXIS = vmath.vector3(0, 0, 1)

local function base_scale(def)
	local s = def.scale or 1
	if type(s) == "number" then return s, s, s end
	return s[1], s[2], s[3]
end

-- angle: rotation around z (radians); sx, sy, sz: logical scale (beam length etc.)
function M.create(id, x, y, z, angle, sx, sy, sz)
	local def = visuals.get(id)
	local bx, by, bz = base_scale(def)
	local a = (angle or 0) + rad(def.rot or 0)
	local rot = vmath.quat_rotation_z(a)
	local pos = V3(x or 0, y or 0, z or 0)
	if def.offset then pos = pos + vmath.rotate(rot, V3(def.offset[1], def.offset[2], def.offset[3])) end
	local scale = V3(
		math.max(0.0001, (sx or 1) * bx),
		math.max(0.0001, (sy or sx or 1) * by),
		math.max(0.0001, (sz or sx or 1) * bz)
	)
	return factory.create(visuals.factory(id), pos, rot, nil, scale)
end

function M.set(id, go_id, x, y, z, angle, sx, sy, sz)
	local def = visuals.get(id)
	local a = (angle or 0) + rad(def.rot or 0)
	local rot = vmath.quat_rotation_z(a)
	tmp_pos.x, tmp_pos.y, tmp_pos.z = x, y, z or 0
	if def.offset then
		local o = vmath.rotate(rot, V3(def.offset[1], def.offset[2], def.offset[3]))
		tmp_pos.x, tmp_pos.y, tmp_pos.z = tmp_pos.x + o.x, tmp_pos.y + o.y, tmp_pos.z + o.z
	end
	go.set_position(tmp_pos, go_id)
	go.set_rotation(rot, go_id)
	if sx then
		local bx, by, bz = base_scale(def)
		tmp_scale.x = math.max(0.0001, sx * bx)
		tmp_scale.y = math.max(0.0001, (sy or sx) * by)
		tmp_scale.z = math.max(0.0001, (sz or sx) * bz)
		go.set_scale(tmp_scale, go_id)
	end
end

local function model_url(go_id)
	return msg.url(nil, go_id, "model")
end

function M.tint(go_id, r, g, b, a)
	go.set(model_url(go_id), "tint", V4(r, g, b, a or 1))
end

function M.tint_rgb(go_id, c, a)
	go.set(model_url(go_id), "tint", V4(c[1], c[2], c[3], a or 1))
end

function M.overlay(go_id, r, g, b, a)
	go.set(model_url(go_id), "overlay", V4(r, g, b, a))
end

function M.delete(go_id)
	if go_id then go.delete(go_id) end
end

function M.delete_all(list)
	for k, id in pairs(list) do
		go.delete(id)
		list[k] = nil
	end
end

function M.enable(go_id, on)
	msg.post(go_id, on and "enable" or "disable")
end

return M
