-- Static level visuals: terrain, rocks, water, flags, portals, spikes, background decor, build grid.
local spawn = require("world.spawn")
local themes = require("game.config.themes")
local tuning = require("game.config.tuning")

local M = {}

local DH = tuning.DECK_HALF
local Z_FRONT, Z_BACK = 1.45, -6.0          -- terrain depth (front face just in front of the truss members)
local DEPTH = Z_FRONT - Z_BACK
local ZC = (Z_FRONT + Z_BACK) * 0.5

local view = nil

-- deterministic pseudo random per level
local function rng(seed)
	local s = seed
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
end

local function add(list, id)
	list[#list + 1] = id
	return id
end

local function extents(level)
	local x0, x1 = level.start - 24, level.finish + 24
	if level.area then
		x0 = math.min(x0, level.area[1] - 10)
		x1 = math.max(x1, level.area[3] + 10)
	end
	return x0, x1
end

local function column(gos, theme, x0, x1, top, vis_bottom)
	if x1 - x0 <= 0 then return end
	-- the body stops under the top slab (coplanar faces would flicker)
	local h = top - 0.3 - vis_bottom
	local body = add(gos, spawn.create("terrain_body", (x0 + x1) * 0.5, vis_bottom + h * 0.5, ZC, 0, x1 - x0, h, DEPTH))
	spawn.tint_rgb(body, theme.ground)
	local cap = add(gos, spawn.create("terrain_top", (x0 + x1) * 0.5, top, ZC, 0, x1 - x0, 1, DEPTH))
	spawn.tint_rgb(cap, theme.top)
end

function M.build(level)
	M.destroy()
	local theme = themes.get(level.theme)
	local gos = {}
	view = { gos = gos, level = level, theme = theme, portals = {} }
	local ex0, ex1 = extents(level)
	local kill = level.water or level.kill_y or -12
	local vis_bottom = kill - 45 -- deep enough for tall portrait screens

	msg.post("@render:", "clear_color", { color = vmath.vector4(theme.sky[1], theme.sky[2], theme.sky[3], 1) })

	-- ground columns; the outermost ones are extended so the world never ends on screen
	for _, g in ipairs(level.ground or {}) do
		local x0, x1 = math.max(g[1], ex0 - 30), math.min(g[2], ex1 + 30)
		if g[1] <= ex0 then x0 = ex0 - 30 end
		if g[2] >= ex1 then x1 = ex1 + 30 end
		local bottom = math.max(g[4] or -40, vis_bottom)
		column(gos, theme, x0, x1, g[3] + DH, bottom)
	end
	for _, r in ipairs(level.ramps or {}) do
		local x0, x1, y0, y1 = r[1], r[2], r[3] + DH, r[4] + DH
		local lo = math.min(y0, y1)
		local bottom = math.max(r[5] or -40, vis_bottom)
		local body = add(gos, spawn.create("terrain_body", (x0 + x1) * 0.5, (lo + bottom) * 0.5, ZC, 0, x1 - x0, lo - bottom, DEPTH))
		spawn.tint_rgb(body, theme.ground)
		if math.abs(y1 - y0) > 0.01 then
			local wid = y1 > y0 and "wedge_up" or "wedge_dn"
			local wedge = add(gos, spawn.create(wid, (x0 + x1) * 0.5, lo, ZC, 0, x1 - x0, math.abs(y1 - y0), DEPTH))
			spawn.tint_rgb(wedge, theme.ground)
		end
		local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
		local ang = math.atan2(y1 - y0, x1 - x0)
		local cap = add(gos, spawn.create("terrain_top", (x0 + x1) * 0.5, (y0 + y1) * 0.5, ZC, ang, len, 1, DEPTH))
		spawn.tint_rgb(cap, theme.top)
	end
	for _, b in ipairs(level.blocks or {}) do
		local blk = add(gos, spawn.create("block", (b[1] + b[3]) * 0.5, (b[2] + b[4]) * 0.5, ZC, 0, b[3] - b[1], b[4] - b[2], DEPTH))
		spawn.tint_rgb(blk, theme.rock)
	end

	-- water
	if level.water then
		local wat = add(gos, spawn.create("water", (ex0 + ex1) * 0.5, level.water, -9, 0, ex1 - ex0 + 120, 60, 24))
		spawn.tint(wat, theme.water[1], theme.water[2], theme.water[3], 0.82)
	end

	-- spikes, 1 m pieces
	for _, s in ipairs(level.spikes or {}) do
		local h = (s[4] - s[2]) / 0.8
		for x = s[1] + 0.5, s[3] - 0.49, 1 do
			add(gos, spawn.create("spikes", x, s[2], 0, 0, 1, h, 1))
		end
	end

	-- portals
	for _, p in ipairs(level.portals or {}) do
		for k, side in ipairs({ p[1], p[2] }) do
			local id = k == 1 and "portal_blue" or "portal_orange"
			local ring = add(gos, spawn.create(id, side.x, side.y, 0, side.angle, 1, 1, 1))
			local glow = add(gos, spawn.create("portal_glow", side.x, side.y, 0, side.angle, 0.55, 1.1, 1))
			local color = k == 1 and { 0.3, 0.6, 1 } or { 1, 0.6, 0.2 }
			spawn.tint_rgb(glow, color, 0.45)
			view.portals[#view.portals + 1] = { ring = ring, glow = glow, color = color, x = side.x, y = side.y, flash = 0 }
		end
	end

	-- flags
	local terrain = require("game.physics.terrain")
	local geo = terrain.build(level)
	local hs = terrain.height_at(geo, level.start - 3) or 0
	add(gos, spawn.create("flag_start", level.start - 3, hs, 0))
	local hf = terrain.height_at(geo, level.finish) or 0
	add(gos, spawn.create("flag_finish", level.finish, hf, 0))

	-- decor: behind the road, away from the build zone
	local rand = rng(level.index * 7919 + 17)
	local area = level.area or { 0, 0, 0, 0 }
	local count = 0
	for x = ex0, ex1, 2.5 do
		if x < area[1] - 2 or x > area[3] + 2 then
			local h = terrain.height_at(geo, x)
			if h and h > kill and rand() < 0.55 then
				local id = theme.decor[1 + math.floor(rand() * #theme.decor)]
				local z = -2.6 - rand() * 2.8
				if id ~= "lab_panel" then
					local s = 0.8 + rand() * 0.6
					local d = add(gos, spawn.create(id, x + rand() * 1.5, h, z, 0, s, s, s))
					if id == "rock_small" then spawn.tint_rgb(d, theme.rock) end
					count = count + 1
				end
			end
		end
	end
	-- background mountains and clouds
	-- far mountains, faded toward the sky color (aerial perspective)
	local far = { theme.far[1] * 0.6 + theme.sky[1] * 0.4, theme.far[2] * 0.6 + theme.sky[2] * 0.4, theme.far[3] * 0.6 + theme.sky[3] * 0.4 }
	for i = 0, 9 do
		local x = ex0 - 40 + (ex1 - ex0 + 80) * (i + rand() * 0.5) / 9
		local s = 16 + rand() * 16
		local m = add(gos, spawn.create("mountain", x, kill - 6, -110 - rand() * 30, 0, s * 1.6, s, s))
		spawn.tint_rgb(m, far)
	end
	if theme.clouds then
		for i = 0, 6 do
			local x = ex0 + (ex1 - ex0) * (i + rand()) / 6
			local s = 1.5 + rand() * 1.5
			add(gos, spawn.create("cloud", x, 9 + rand() * 9, -22 - rand() * 14, 0, s, s, s))
		end
	end
	if theme.panels then
		for x = ex0, ex1, 4 do
			for y = -2, 10, 4 do
				add(gos, spawn.create("lab_panel", x, y, -7.2, 0, 2, 2, 1))
			end
		end
	end

	-- build helpers: dot grid and the build zone
	local a = level.area
	if a then
		-- dot grid tiled from 2x2 chunks over the build zone only
		view.grid = {}
		for gx = math.floor(a[1]), math.floor(a[3]), 2 do
			for gy = math.floor(a[2]), math.floor(a[4]), 2 do
				local chunk = add(gos, spawn.create("grid_dots", gx, gy, tuning.BUILD_PLANE_Z + 0.05, 0, 1, 1, 1))
				spawn.tint(chunk, 1, 1, 1, 0.5)
				view.grid[#view.grid + 1] = chunk
			end
		end
		view.zone = add(gos, spawn.create("zone", (a[1] + a[3]) * 0.5, (a[2] + a[4]) * 0.5, -1.7, 0, a[3] - a[1] + 1, a[4] - a[2] + 1, 1))
		spawn.tint(view.zone, 1, 1, 1, 0.1)
	end
	return view
end

function M.set_build_helpers(on)
	if not view then return end
	for _, g in ipairs(view.grid or {}) do spawn.enable(g, on) end
	if view.zone then spawn.enable(view.zone, on) end
end

function M.flash_portal(x, y)
	if not view then return end
	for _, p in ipairs(view.portals) do
		if math.abs(p.x - x) < 0.5 and math.abs(p.y - y) < 0.5 then p.flash = 1 end
	end
end

local t_acc = 0
function M.update(dt)
	if not view then return end
	t_acc = t_acc + dt
	for i, p in ipairs(view.portals) do
		local pulse = 0.4 + 0.15 * math.sin(t_acc * 4 + i)
		if p.flash > 0 then p.flash = math.max(0, p.flash - dt * 2) end
		local s = 1 + p.flash * 0.25
		go.set_scale(vmath.vector3(0.55 * s, 1.1 * s, 1), p.glow)
		spawn.overlay(p.glow, 1, 1, 1, p.flash * 0.8)
		spawn.tint_rgb(p.glow, p.color, math.min(1, pulse + p.flash * 0.4))
	end
end

function M.destroy()
	if view then
		spawn.delete_all(view.gos)
		view = nil
	end
end

function M.get()
	return view
end

return M
