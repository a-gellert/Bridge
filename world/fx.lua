-- Cheap voxel particles: debris when beams snap, splashes, crash bits. Ballistic, no collisions.
local spawn = require("world.spawn")
local materials = require("game.config.materials")

local M = {}

local parts = {}
local MAX_PARTS = 140
local GRAVITY = -16

local function emit(x, y, z, color, n, speed, life, size)
	for _ = 1, n do
		if #parts >= MAX_PARTS then return end
		local s = (size or 1) * (0.6 + math.random() * 0.8)
		local p = {
			x = x, y = y, z = z + (math.random() - 0.5) * 2.4,
			vx = (math.random() - 0.5) * speed, vy = math.random() * speed * 0.9 + speed * 0.2, vz = (math.random() - 0.5) * speed * 0.6,
			a = math.random() * 6, va = (math.random() - 0.5) * 14,
			life = life * (0.6 + math.random() * 0.6), s = s,
		}
		p.go = spawn.create("debris", p.x, p.y, p.z, p.a, s, s, s)
		spawn.tint_rgb(p.go, color)
		parts[#parts + 1] = p
	end
end

function M.beam_break(x, y, mat)
	local m = materials.get(mat)
	emit(x, y, 0, m and m.color or { 1, 1, 1 }, 7, 6, 1.4, 1)
end

function M.splash(x, y, color)
	emit(x, y, 0, color or { 0.4, 0.75, 1 }, 16, 9, 1.1, 0.9)
end

function M.crash(x, y, color)
	emit(x, y, 0, color or { 0.9, 0.3, 0.3 }, 12, 8, 1.3, 1.1)
end

function M.update(dt)
	for i = #parts, 1, -1 do
		local p = parts[i]
		p.life = p.life - dt
		if p.life <= 0 then
			spawn.delete(p.go)
			table.remove(parts, i)
		else
			p.vy = p.vy + GRAVITY * dt
			p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
			p.a = p.a + p.va * dt
			local s = p.s * math.min(1, p.life * 3)
			spawn.set("debris", p.go, p.x, p.y, p.z, p.a, s, s, s)
		end
	end
end

function M.clear()
	for i = #parts, 1, -1 do
		spawn.delete(parts[i].go)
		parts[i] = nil
	end
end

return M
