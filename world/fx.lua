-- Cheap voxel particles: debris when beams snap, dust on landings, splashes, portal bursts,
-- sparks and victory confetti. Ballistic, no collisions, hard cap on the object count.
local spawn = require("world.spawn")
local materials = require("game.config.materials")

local M = {}

local parts = {}
local marks = {}
local MAX_PARTS = 240
local MAX_MARKS = 56
local GRAVITY = -16

-- Adaptive quality: world.script lowers the particle budget on slow devices.
local part_budget = MAX_PARTS
function M.set_budget(n)
	part_budget = math.max(60, math.min(MAX_PARTS, n or MAX_PARTS))
	if #parts > part_budget then
		for i = #parts, part_budget + 1, -1 do
			spawn.delete(parts[i].go)
			parts[i] = nil
		end
	end
end

local function emit(x, y, z, colors, n, speed, life, size, opts)
	opts = opts or {}
	local many = type(colors[1]) == "table"
	local g = opts.gravity or GRAVITY
	local up = opts.up or 0.35
	local spin = opts.spin or 14
	for _ = 1, n do
		if #parts >= part_budget then return end
		local s = (size or 1) * (0.55 + math.random() * 0.8)
		local color = many and colors[1 + math.floor(math.random() * #colors)] or colors
		local p = {
			x = x, y = y, z = z + (math.random() - 0.5) * (opts.depth or 2.4),
			vx = (math.random() - 0.5) * speed,
			vy = (math.random() * (1 - up) + up) * speed,
			vz = (math.random() - 0.5) * speed * 0.6,
			a = math.random() * 6, va = (math.random() - 0.5) * spin,
			life = life * (0.6 + math.random() * 0.6), s = s, g = g, life0 = life,
		}
		p.go = spawn.create("debris", p.x, p.y, p.z, p.a, s, s, s)
		spawn.tint_rgb(p.go, color)
		parts[#parts + 1] = p
	end
end

function M.beam_break(x, y, mat)
	local m = materials.get(mat)
	local c = m and m.color or { 1, 1, 1 }
	emit(x, y, 0, { c, { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7 }, { 0.95, 0.9, 0.8 } }, 9, 6.5, 1.5, 1)
end

function M.dust(x, y, color)
	local c = color or { 0.68, 0.58, 0.46 }
	local light = { math.min(1, c[1] * 1.35 + 0.08), math.min(1, c[2] * 1.35 + 0.08), math.min(1, c[3] * 1.35 + 0.08) }
	emit(x, y, 0, { c, light, { 0.9, 0.88, 0.82 } }, 10, 3.6, 0.75, 0.75, { gravity = -6, up = 0.65, depth = 1.4, spin = 9 })
end

-- Soft voxel exhaust / tire smoke.
function M.smoke(x, y, z, color, n)
	local c = color or { 0.72, 0.72, 0.76 }
	local light = { math.min(1, c[1] + 0.12), math.min(1, c[2] + 0.12), math.min(1, c[3] + 0.12) }
	emit(x, y, z or 0, { c, light, { 0.9, 0.9, 0.94 } }, n or 3, 1.6, 0.85, 0.62,
		{ gravity = -1.8, up = 0.85, depth = 0.9, spin = 5 })
end

-- Dark tire mark on the deck / ground. Flat translucent quads fade out after a few seconds.
function M.skid(x, y, z, angle, length, width, tone)
	if #marks >= MAX_MARKS then
		local old = table.remove(marks, 1)
		spawn.delete(old.go)
	end
	local c = tone or 0.06
	local sx = math.max(0.3, length or 0.7)
	local sz = math.max(0.18, width or 0.26)
	local go = spawn.create("shadow", x, y + 0.02, z or 0, angle or 0, sx, 1, sz)
	spawn.tint(go, c, c, c, 0.32)
	marks[#marks + 1] = { go = go, life = 4.5, life0 = 4.5, c = c }
end

function M.splash(x, y, color)
	local c = color or { 0.4, 0.75, 1 }
	local light = { math.min(1, c[1] + 0.28), math.min(1, c[2] + 0.2), 1 }
	emit(x, y, 0, { c, light, { 0.92, 0.98, 1 } }, 18, 9, 1.15, 0.85, { gravity = -17, up = 0.55, depth = 2.6 })
end

function M.crash(x, y, color)
	local c = color or { 0.9, 0.3, 0.3 }
	emit(x, y, 0, { c, { 0.95, 0.78, 0.35 }, { 0.25, 0.22, 0.2 }, { 0.9, 0.9, 0.9 } }, 15, 8, 1.45, 1.1, { gravity = -15, up = 0.45 })
end

function M.portal_burst(x, y, color)
	local c = color or { 0.35, 0.65, 1 }
	emit(x, y, 0, { c, { 1, 1, 1 }, { math.min(1, c[1] + 0.3), math.min(1, c[2] + 0.3), math.min(1, c[3] + 0.3) } },
		18, 12, 1.25, 0.85, { gravity = -2, up = 0.5, depth = 2.0, spin = 24 })
	-- energetic shockwave sparks
	emit(x, y, 0.05, { { 1, 1, 1 }, c }, 10, 14, 0.55, 0.5, { gravity = 0, up = 0, depth = 0.5, spin = 32 })
end

function M.sparks(x, y, color)
	local c = color or { 1, 0.62, 0.2 }
	emit(x, y, 0, { c, { 1, 0.92, 0.5 }, { 1, 1, 1 } }, 9, 7, 0.55, 0.6, { gravity = -12, up = 0.25, depth = 1.0, spin = 20 })
end

function M.confetti(x, y)
	local cs = {
		{ 1, 0.38, 0.45 }, { 1, 0.82, 0.24 }, { 0.22, 0.78, 0.45 }, { 0.3, 0.58, 1 },
		{ 0.62, 0.42, 1 }, { 1, 1, 1 }, { 1, 0.55, 0.2 },
	}
	emit(x, y + 0.4, 0, cs, 30, 9, 2.4, 0.72, { gravity = -9, up = 0.65, depth = 2.8, spin = 26 })
end

function M.update(dt)
	for i = #parts, 1, -1 do
		local p = parts[i]
		p.life = p.life - dt
		if p.life <= 0 then
			spawn.delete(p.go)
			table.remove(parts, i)
		else
			p.vy = p.vy + p.g * dt
			p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
			p.a = p.a + p.va * dt
			local k = math.min(1, p.life * 3.5)
			local s = p.s * (0.35 + 0.65 * k)
			spawn.set("debris", p.go, p.x, p.y, p.z, p.a, s, s, s)
		end
	end
	for i = #marks, 1, -1 do
		local m = marks[i]
		m.life = m.life - dt
		if m.life <= 0 then
			spawn.delete(m.go)
			table.remove(marks, i)
		elseif m.life < 1.1 then
			spawn.tint(m.go, m.c, m.c, m.c, 0.32 * (m.life / 1.1))
		end
	end
end

function M.clear()
	for i = #parts, 1, -1 do
		spawn.delete(parts[i].go)
		parts[i] = nil
	end
	for i = #marks, 1, -1 do
		spawn.delete(marks[i].go)
		marks[i] = nil
	end
end

function M.count()
	return #parts + #marks
end

return M
