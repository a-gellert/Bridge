-- Static level visuals: sky, layered mountains, terrain, water, flags, portals, spikes, decor, grid.
local spawn = require("world.spawn")
local themes = require("game.config.themes")
local tuning = require("game.config.tuning")
local terrain = require("game.physics.terrain")

local M = {}

-- Decor that reacts to a light breeze. amp is radians of lean, dx is metres of sway.
local SWAY = {
	tree = { amp = 0.025, dx = 0.05 },
	tree_blossom = { amp = 0.03, dx = 0.07 },
	pine = { amp = 0.018, dx = 0.035 },
	pine_tall = { amp = 0.022, dx = 0.045 },
	bush = { amp = 0.02, dx = 0.03 },
	flower_red = { amp = 0.035, dx = 0.02 },
	flower_yellow = { amp = 0.035, dx = 0.02 },
	flower_blue = { amp = 0.035, dx = 0.02 },
	flower_white = { amp = 0.035, dx = 0.02 },
}

local DH = tuning.DECK_HALF
local Z_FRONT, Z_BACK = 1.45, -6.0          -- terrain depth (front face just in front of the truss members)
local DEPTH = Z_FRONT - Z_BACK
local ZC = (Z_FRONT + Z_BACK) * 0.5
local CAP_TILE = 3.0                        -- terrain tops are split so grass details never stretch

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

local function mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local function extents(level)
	local x0, x1 = level.start - 24, level.finish + 24
	if level.area then
		x0 = math.min(x0, level.area[1] - 10)
		x1 = math.max(x1, level.area[3] + 10)
	end
	return x0, x1
end

-- Split a long terrain cap into short tiles: the model's grass fringe then keeps a natural scale.
local function cap_row(gos, theme, x0, x1, y0, y1, angle)
	if x1 - x0 <= 0 then return end
	local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
	local n = math.max(1, math.ceil(len / CAP_TILE))
	local seg = len / n
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local cx = x0 + (x1 - x0) * t
		local cy = y0 + (y1 - y0) * t
		local cap = add(gos, spawn.create("terrain_top", cx, cy, ZC, angle or 0, seg, 1, DEPTH))
		spawn.tint_rgb(cap, theme.top)
	end
end

local function column(gos, theme, x0, x1, top, vis_bottom)
	if x1 - x0 <= 0 then return end
	-- the body stops under the top slab (coplanar faces would flicker)
	local h = top - 0.3 - vis_bottom
	local body = add(gos, spawn.create("terrain_body", (x0 + x1) * 0.5, vis_bottom + h * 0.5, ZC, 0, x1 - x0, h, DEPTH))
	spawn.tint_rgb(body, theme.ground)
	-- a darker topsoil band, slightly proud of the cliff face
	local soil = add(gos, spawn.create("terrain_body", (x0 + x1) * 0.5, top - 0.66, Z_FRONT + 0.015, 0, x1 - x0, 0.72, 0.06))
	spawn.tint(soil, theme.ground[1] * 0.72, theme.ground[2] * 0.72, theme.ground[3] * 0.72, 1)
	cap_row(gos, theme, x0, x1, top, top, 0)
end

-- First ground spot on this side of the bridge that is outside the build area.
local function ground_spot(level, geo, x, dir)
	local a = level.area
	local kill = level.water or level.kill_y or -12
	for d = 0, 26, 2 do
		local xx = x + dir * d
		if not a or xx < a[1] - 3 or xx > a[3] + 3 then
			local h = terrain.height_at(geo, xx)
			if h and h > kill + 0.5 then return xx, h end
		end
	end
	return nil, nil
end

-- One theme landmark on the bank: a windmill, ruin, crystal or rock arch.
local function spawn_landmark(view, gos, theme, level, geo, rand)
	local id = theme.landmark
	if not id then return end
	local x, h
	local a = level.area or { level.start, -4, level.finish, 6 }
	-- Keep the landmark on the visible bank: the camera frames `level.area`, not the whole level.
	for _, c in ipairs({ { a[1] - 4, -1 }, { a[3] + 4, 1 }, { a[1] - 10, -1 }, { a[3] + 10, 1 }, { level.start - 7, -1 } }) do
		x, h = ground_spot(level, geo, c[1], c[2])
		if x then break end
	end
	if not x then return end
	view.landmark_x, view.landmark_y = x, h
	local z = -5.6
	if id == "windmill" then
		local s = 0.92
		local tower = add(gos, spawn.create("windmill", x, h, z, 0, s, s, s))
		spawn.tint(tower, 1.0, 0.97, 0.9, 1)
		local hub_y = h + 4.15 * s
		local blades = add(gos, spawn.create("windmill_blades", x, hub_y, z + 0.95 * s, 0, s, s, s))
		spawn.tint(blades, 0.96, 0.94, 0.9, 1)
		view.rotors[#view.rotors + 1] = {
			go = blades, x = x, y = hub_y, z = z + 0.95 * s, s = s,
			angle = rand() * math.pi * 2, speed = 0.32 + rand() * 0.18,
		}
	elseif id == "crystal_cluster" then
		local s = 1.1
		local go = add(gos, spawn.create(id, x, h, z, 0, s, s, s))
		spawn.tint_rgb(go, theme.crystal or { 1, 1, 1 })
	elseif id == "lab_generator" then
		local s = 0.95
		local go = add(gos, spawn.create(id, x, h, z, 0, s, s, s))
		spawn.tint_rgb(go, { 1, 1, 1 })
	else
		local s = id == "ruin_arch" and 0.82 or 0.78
		local go = add(gos, spawn.create(id, x, h, z, 0, s, s, s))
		spawn.tint_rgb(go, theme.rock)
	end
end

-- Varied airborne and environmental fauna: flocks in V-formation, fast swallows, soaring raptors,
-- test chamber survey drones (in lab), jumping river fish, and flower butterflies.
local function spawn_fauna(view, gos, theme, level, geo, area, ex0, ex1, rand)
	local is_lab = (level.theme == "lab")
	local has_water = (level.water ~= nil)

	-- 1. Birds (for non-lab outdoor themes)
	if theme.birds and not is_lab then
		local tint = { 0.92, 0.95, 1.0 }
		local dark_tint = (level.theme == "canyon") and { 0.72, 0.54, 0.42 } or { 0.45, 0.48, 0.55 }

		-- A. High V-Formation Flock crossing the distant sky
		local flock_lead = {
			x = ex0 - 35 + rand() * 20,
			y = 20 + rand() * 7,
			z = -55 - rand() * 25,
			speed = 4.6 + rand() * 2.0,
			x0 = ex0 - 55,
			x1 = ex1 + 55,
		}
		local offsets = {
			{ 0, 0, 0 },
			{ -2.4, 0.5, -1.4 },
			{ -2.4, -0.4, 1.4 },
			{ -4.8, 0.9, -2.8 },
			{ -4.8, -0.8, 2.8 },
			{ -7.2, 1.3, -4.2 },
		}
		for fi, off in ipairs(offsets) do
			local s = 0.55 + rand() * 0.15
			local go = add(gos, spawn.create("bird", flock_lead.x + off[1], flock_lead.y + off[2], flock_lead.z + off[3], 0, s, s, s))
			spawn.tint_rgb(go, tint)
			view.fauna[#view.fauna + 1] = {
				kind = "bird_flock", go = go, lead = flock_lead,
				ox = off[1], oy = off[2], oz = off[3],
				s = s, phase = fi * 0.65,
			}
		end

		-- B. Low Swift Swallows darting in the midground
		for _ = 1, 4 do
			local x = ex0 + (ex1 - ex0) * rand()
			local y = 8 + rand() * 7
			local z = -22 - rand() * 12
			local s = 0.45 + rand() * 0.22
			local speed = 6.2 + rand() * 3.2
			local go = add(gos, spawn.create("bird", x, y, z, 0, s, s, s))
			spawn.tint_rgb(go, { tint[1] * 0.94, tint[2] * 0.94, tint[3] })
			view.fauna[#view.fauna + 1] = {
				kind = "bird_fast", go = go, x = x, x0 = ex0 - 25, x1 = ex1 + 25,
				base_y = y, z = z, s = s, speed = speed, phase = rand() * math.pi * 2,
			}
		end

		-- C. High Soaring Raptors (Eagles / Vultures) circling thermals
		local num_eagles = (level.theme == "canyon" or level.theme == "mountains") and 2 or 1
		for _ = 1, num_eagles do
			local cx = (ex0 + ex1) * 0.5 + (rand() - 0.5) * 24
			local cz = -42 - rand() * 28
			local base_y = 22 + rand() * 8
			local rx = 16 + rand() * 10
			local rz = 10 + rand() * 6
			local s = 1.1 + rand() * 0.35
			local go = add(gos, spawn.create("bird", cx, base_y, cz, 0, s, s, s))
			spawn.tint_rgb(go, dark_tint)
			view.fauna[#view.fauna + 1] = {
				kind = "eagle", go = go, cx = cx, cz = cz, rx = rx, rz = rz,
				base_y = base_y, s = s, speed = 0.26 + rand() * 0.16, phase = rand() * math.pi * 2,
			}
		end
	end

	-- 2. Lab Autonomous Inspection Drones
	if is_lab then
		for i = 1, 4 do
			local x = ex0 - 10 + (ex1 - ex0 + 20) * (i / 4)
			local y = 5 + rand() * 6
			local z = -6 - rand() * 6
			local s = 0.55 + rand() * 0.2
			local go = add(gos, spawn.create("debris", x, y, z, 0, s, s * 0.75, s * 1.3))
			spawn.tint(go, 0.92, 0.96, 1.0, 1.0)
			view.fauna[#view.fauna + 1] = {
				kind = "lab_drone", go = go, x = x, x0 = ex0 - 15, x1 = ex1 + 15,
				base_y = y, z = z, s = s, speed = 2.4 + rand() * 1.8, dir = (rand() < 0.5 and 1 or -1),
				phase = rand() * math.pi * 2,
			}
		end
	end

	-- 3. Jumping Fish in water levels
	if has_water and not is_lab then
		for _ = 1, 3 do
			local x = ex0 + (ex1 - ex0) * (0.15 + rand() * 0.7)
			local z = -3.5 - rand() * 6.5
			local s = 0.55 + rand() * 0.25
			local go = add(gos, spawn.create("bird", x, level.water - 25, z, 0, s, s, s))
			spawn.tint_rgb(go, { 0.75, 0.88, 1.0 })
			spawn.enable(go, false)
			view.fauna[#view.fauna + 1] = {
				kind = "fish", go = go, x = x, z = z, s = s,
				water_y = level.water,
				jump_h = 1.8 + rand() * 1.4,
				jump_dist = 1.2 + rand() * 1.4,
				jump_dur = 1.1 + rand() * 0.3,
				interval = 5.0 + rand() * 4.0,
				phase = rand() * 10,
				visible = false,
			}
		end
	end

	-- 4. Butterflies (valley & flower meadows)
	if theme.butterflies then
		local colors = { { 1, 0.72, 0.85 }, { 1, 0.9, 0.55 }, { 0.75, 0.85, 1 }, { 1, 1, 1 } }
		for _ = 1, 8 do
			local x, h
			for _ = 1, 9 do
				local xx = ex0 + (ex1 - ex0) * rand()
				if not area or xx < area[1] - 1 or xx > area[3] + 1 then
					h = terrain.height_at(geo, xx)
					if h and h > (level.water or level.kill_y or -12) then x = xx break end
				end
			end
			if x then
				local z = 0.4 + rand() * 2.2
				local s = 0.55 + rand() * 0.35
				local go = add(gos, spawn.create("butterfly", x, h + 0.5 + rand() * 0.8, z, 0, s, s, s))
				spawn.tint_rgb(go, colors[1 + math.floor(rand() * #colors)])
				view.fauna[#view.fauna + 1] = {
					kind = "butterfly", go = go, x = x, y = h + 0.7, z = z, s = s,
					radius = 0.7 + rand() * 1.2, speed = 0.7 + rand() * 1.1, phase = rand() * math.pi * 2,
				}
			end
		end
	end
end

-- Petals, canyon dust, lab sparks or mountain snow drifting around the camera.
local function spawn_ambient(view, gos, theme, ex0, ex1, rand)
	local kind = theme.ambient
	if not kind then return end
	local n = kind == "snow" and 22 or 16
	local tones = {
		petals = { { 1, 0.62, 0.78 }, { 1, 0.82, 0.9 }, { 0.78, 1, 0.68 }, { 1, 1, 1 } },
		dust = { { 1, 0.84, 0.58 }, { 0.95, 0.74, 0.48 }, { 1, 0.94, 0.8 } },
		sparks = { { 0.6, 1, 1 }, { 0.85, 1, 1 }, { 0.72, 0.88, 1 } },
		snow = { { 1, 1, 1 }, { 0.88, 0.95, 1 } },
	}
	local palette = tones[kind] or { { 1, 1, 1 } }
	for _ = 1, n do
		local x = ex0 + (ex1 - ex0) * rand()
		local z = -1.0 + rand() * 8.0
		local s, y
		if kind == "snow" then
			y = 3 + rand() * 11
			s = 0.15 + rand() * 0.14
		elseif kind == "sparks" then
			y = 0.4 + rand() * 4.8
			s = 0.12 + rand() * 0.14
		else
			y = 0.8 + rand() * 4.4
			s = 0.16 + rand() * 0.16
		end
		local go = add(gos, spawn.create("debris", x, y, z, rand() * math.pi * 2, s, s, s))
		spawn.tint_rgb(go, palette[1 + math.floor(rand() * #palette)])
		view.ambient[#view.ambient + 1] = {
			kind = kind, go = go, x = x, y = y, z = z, s = s,
			speed = 0.35 + rand() * 0.9, phase = rand() * math.pi * 2,
			span = 5 + rand() * 7, offset = rand() * 10,
		}
	end
end

-- Small glints dancing on the water surface.
local function spawn_glints(view, gos, level, ex0, ex1, rand)
	if not level.water then return end
	for _ = 1, 10 do
		local x = ex0 + (ex1 - ex0) * rand()
		local z = -2.2 - rand() * 9
		local s = 0.45 + rand() * 0.9
		local go = add(gos, spawn.create("shadow", x, level.water + 0.08, z, 0, s, 1, s * 0.38))
		spawn.tint(go, 1, 1, 1, 0.18)
		view.glints[#view.glints + 1] = { go = go, x = x, y = level.water + 0.08, z = z, s = s, phase = rand() * math.pi * 2 }
	end
end

function M.build(level)
	M.destroy()
	local theme = themes.get(level.theme)
	local gos = {}
	view = {
		gos = gos, level = level, theme = theme, portals = {}, indicators = {}, waves = {}, clouds = {},
		sway = {}, fauna = {}, ambient = {}, glints = {}, rotors = {},
	}
	local ex0, ex1 = extents(level)
	local kill = level.water or level.kill_y or -12
	local vis_bottom = kill - 45 -- deep enough for tall portrait screens
	local area = level.area or { level.start, -4, level.finish, 6 }
	local rand = rng(level.index * 7919 + 17)

	msg.post("@render:", "clear_color", { color = vmath.vector4(theme.sky[1], theme.sky[2], theme.sky[3], 1) })

	-- ---------------------------------------------------------- sky gradient & celestial body
	local sky_top = theme.sky_top or mix(theme.sky, { 0, 0, 0 }, 0.35)
	local bands = 32
	local y_lo, y_hi = kill - 30, 115
	local bh = (y_hi - y_lo) / bands
	for i = 0, bands - 1 do
		local k = i / (bands - 1)
		local c = mix(theme.sky, sky_top, k ^ 0.55)
		local band = add(gos, spawn.create("sky_band", (ex0 + ex1) * 0.5, y_lo + bh * (i + 0.5), -152, 0, 480, bh + 0.45, 1))
		spawn.tint_rgb(band, c)
	end

	-- Celestial body (sun / moon) in the sky
	if level.theme ~= "lab" then
		local sun_x = (level.theme == "mountains") and (ex0 + 8) or (ex1 - 10)
		local sun_y = (level.theme == "canyon") and (kill + 17) or 36
		local sun_color, sun_scale
		if level.theme == "canyon" then
			sun_color = { 1.0, 0.88, 0.65 }
			sun_scale = 13.0
		elseif level.theme == "mountains" then
			sun_color = { 0.95, 0.95, 1.0 }
			sun_scale = 9.0
		else
			sun_color = { 1.0, 0.98, 0.88 }
			sun_scale = 10.5
		end
		-- glowing sun corona + core
		local corona = add(gos, spawn.create("portal_glow", sun_x, sun_y, -148, 0, sun_scale * 1.5, sun_scale * 1.5, 1))
		spawn.tint(corona, sun_color[1], sun_color[2], sun_color[3], 0.38)
		local core = add(gos, spawn.create("portal_glow", sun_x, sun_y, -147, 0, sun_scale * 0.9, sun_scale * 0.9, 1))
		spawn.tint(core, 1.0, 1.0, 1.0, 0.85)
	end

	-- ---------------------------------------------------------- background mountains (aerial perspective)
	local far = mix(theme.far, theme.sky, 0.68)
	local mid = mix(theme.far, theme.sky, 0.44)
	local near = mix(theme.far, theme.sky, 0.32)
	local spans = ex1 - ex0 + 180
	-- three separate layers of ridges: the lightest and tallest sits farthest back
	for i = 0, 8 do
		local x = ex0 - 80 + spans * (i + rand() * 0.7) / 9
		local s = 13 + rand() * 11
		local m = add(gos, spawn.create("mountain", x, kill - 8 + rand() * 2, -136 - rand() * 10, 0, s * 2.6, s, s * 1.25))
		spawn.tint_rgb(m, far)
	end
	for i = 0, 5 do
		local x = ex0 - 55 + (ex1 - ex0 + 110) * (i + rand() * 0.8) / 6
		local s = 7 + rand() * 5
		local m = add(gos, spawn.create("mountain", x, kill - 7 + rand() * 1.5, -96 - rand() * 14, 0, s * 2.7, s, s * 1.2))
		spawn.tint_rgb(m, mid)
	end
	for i = 0, 4 do
		local x = ex0 - 30 + (ex1 - ex0 + 60) * (i + rand() * 0.8) / 5
		local s = 2.6 + rand() * 2.6
		local m = add(gos, spawn.create("mountain", x, kill - 5 + rand() * 1.2, -68 - rand() * 10, 0, s * 2.9, s, s * 1.15))
		spawn.tint_rgb(m, near)
	end

	-- ---------------------------------------------------------- clouds: fast continuous flight across the sky
	if theme.clouds then
		local pad = 60
		local x_min = ex0 - pad
		local x_max = ex1 + pad
		local span = x_max - x_min
		local num_clouds = 16
		for i = 0, num_clouds - 1 do
			local frac = (i + rand() * 0.8) / num_clouds
			local x = x_min + span * frac
			-- 3 distinct depth layers for rich parallax
			local layer = (i % 3)
			local z, y_base, s, speed
			if layer == 0 then
				-- closer, larger, faster
				z = -38 - rand() * 14
				y_base = 11 + rand() * 10
				s = 1.8 + rand() * 1.1
				speed = 4.4 + rand() * 2.8 -- 4.4 .. 7.2 m/s: swift and dynamic!
			elseif layer == 1 then
				-- mid-distance
				z = -56 - rand() * 20
				y_base = 14 + rand() * 12
				s = 1.4 + rand() * 0.9
				speed = 3.0 + rand() * 1.8 -- 3.0 .. 4.8 m/s
			else
				-- high far background
				z = -80 - rand() * 35
				y_base = 18 + rand() * 14
				s = 2.2 + rand() * 1.6
				speed = 1.8 + rand() * 1.4 -- 1.8 .. 3.2 m/s
			end
			local go = add(gos, spawn.create("cloud", x, y_base, z, 0, s, s, s))
			local tint
			if level.theme == "canyon" then
				-- warm sunset glow on clouds
				tint = mix({ 1.0, 0.88, 0.78 }, theme.sky, 0.15)
			elseif level.theme == "mountains" then
				-- crisp alpine tint
				tint = mix({ 0.98, 0.96, 1.0 }, theme.sky, 0.12)
			else
				-- bright fluffy white
				tint = mix({ 1.0, 1.0, 1.0 }, theme.sky, 0.08)
			end
			spawn.tint_rgb(go, { tint[1] * 1.45, tint[2] * 1.45, tint[3] * 1.45 })
			view.clouds[#view.clouds + 1] = {
				go = go, x = x, y_base = y_base, z = z, s = s,
				speed = speed, phase = rand() * 6.28,
				bob_amp = 0.2 + rand() * 0.25,
				bob_freq = 0.35 + rand() * 0.45,
				x_min = x_min, x_max = x_max, span = span,
			}
		end
	end

	-- ---------------------------------------------------------- terrain
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
		local ang = math.atan2(y1 - y0, x1 - x0)
		cap_row(gos, theme, x0, x1, y0, y1, ang)
	end
	for _, b in ipairs(level.blocks or {}) do
		local blk = add(gos, spawn.create("block", (b[1] + b[3]) * 0.5, (b[2] + b[4]) * 0.5, ZC, 0, b[3] - b[1], b[4] - b[2], DEPTH))
		spawn.tint_rgb(blk, theme.rock)
		-- rocky teeth along the exposed underside: breaks up the giant flat slab
		if b[3] - b[1] > 1.4 then
			for x = b[1] + 0.45, b[3] - 0.35, 1.7 do
				local s = 0.42 + rand() * 0.34
				local id = rand() < 0.28 and "rock_big" or "rock_small"
				local d = add(gos, spawn.create(id, x + rand() * 0.4, b[2] - 0.65 * s, 1.5, rand() * math.pi * 2, s, s * 1.1, s))
				spawn.tint_rgb(d, theme.rock)
			end
		end
	end

	-- ---------------------------------------------------------- water
	if level.water then
		local w = ex1 - ex0 + 140
		local body = add(gos, spawn.create("water", (ex0 + ex1) * 0.5, level.water, -8, 0, w, 62, 12))
		spawn.tint(body, theme.water[1] * 0.8, theme.water[2] * 0.8, theme.water[3] * 0.8, 0.86)
		local lite = mix(theme.water, { 1, 1, 1 }, 0.36)
		local surface = add(gos, spawn.create("water_top", (ex0 + ex1) * 0.5, level.water + 0.02, -8, 0, w, 1, 12))
		spawn.tint(surface, lite[1], lite[2], lite[3], 0.55)
		for i = 0, 3 do
			local z = -2.4 - i * 2.7
			local sx = w * (0.7 + i * 0.08)
			local go = add(gos, spawn.create("water_wave", (ex0 + ex1) * 0.5 - i * 2.5, level.water + 0.07, z, 0, sx, 1, 1))
			spawn.tint(go, 1, 1, 1, 0.3 - i * 0.045)
			view.waves[#view.waves + 1] = { go = go, x = (ex0 + ex1) * 0.5 - i * 2.5, y = level.water + 0.07, z = z, sx = sx, phase = i * 1.7 }
		end
	end

	-- ---------------------------------------------------------- spikes
	for _, s in ipairs(level.spikes or {}) do
		local h = (s[4] - s[2]) / 0.8
		for x = s[1] + 0.5, s[3] - 0.49, 1 do
			add(gos, spawn.create("spikes", x, s[2], 0, 0, 1, h, 1))
		end
	end

	-- ---------------------------------------------------------- portals & indicator conduits
	for pi, p in ipairs(level.portals or {}) do
		for k, side in ipairs({ p[1], p[2] }) do
			local id = k == 1 and "portal_blue" or "portal_orange"
			local ring = add(gos, spawn.create(id, side.x, side.y, 0, side.angle, 1, 1, 1))
			local glow = add(gos, spawn.create("portal_glow", side.x, side.y, 0, side.angle, 0.55, 1.1, 1))
			local color = k == 1 and { 0.3, 0.6, 1 } or { 1, 0.6, 0.2 }
			spawn.tint_rgb(glow, color, 0.45)
			view.portals[#view.portals + 1] = {
				ring = ring, glow = glow, color = color, x = side.x, y = side.y, angle = side.angle,
				flash = 0, is_exit = (k == 2),
			}
		end

		-- Aperture-style dotted indicator line connecting entrance and exit
		local a, b = p[1], p[2]
		local y_ceil = math.max(a.y, b.y) + 3.2
		local pts = {}
		local step = 0.65
		local y = a.y
		while y < y_ceil do
			pts[#pts + 1] = { x = a.x, y = y }
			y = y + step
		end
		local x_dir = b.x >= a.x and 1 or -1
		local x = a.x
		while (x_dir > 0 and x < b.x) or (x_dir < 0 and x > b.x) do
			pts[#pts + 1] = { x = x, y = y_ceil }
			x = x + x_dir * step
		end
		y = y_ceil
		while y > b.y do
			pts[#pts + 1] = { x = b.x, y = y }
			y = y - step
		end

		local total_pts = #pts
		for di, pt in ipairs(pts) do
			local frac = di / math.max(1, total_pts)
			local col = mix({ 0.25, 0.72, 1.0 }, { 1.0, 0.62, 0.18 }, frac)
			local dot = add(gos, spawn.create("debris", pt.x, pt.y, -1.8, 0, 0.13, 0.13, 0.13))
			spawn.tint_rgb(dot, col)
			view.indicators[#view.indicators + 1] = {
				go = dot, x = pt.x, y = pt.y, col = col, frac = frac, pi = pi,
			}
		end
	end

	-- ---------------------------------------------------------- flags
	local geo = terrain.build(level)
	local hs = terrain.height_at(geo, level.start - 3) or 0
	add(gos, spawn.create("flag_start", level.start - 3, hs, 0))
	local hf = terrain.height_at(geo, level.finish) or 0
	add(gos, spawn.create("flag_finish", level.finish, hf, 0))

	spawn_landmark(view, gos, theme, level, geo, rand)

	if level.theme == "lab" then
		local sign_x = level.start - 0.5
		local sign_y = hs + 3.8
		local sign = add(gos, spawn.create("chamber_sign", sign_x, sign_y, -3.2, 0, 0.9, 0.9, 0.9))
		spawn.tint_rgb(sign, { 1, 1, 1 })
	end

	-- ---------------------------------------------------------- decor
	local function outside_area(x, pad)
		return x < area[1] - (pad or 2) or x > area[3] + (pad or 2)
	end
	for x = ex0, ex1, 2.5 do
		if outside_area(x, 2.2) then
			local h = terrain.height_at(geo, x)
			local clear_of_landmark = not view.landmark_x or math.abs(x - view.landmark_x) > 3.4
			if clear_of_landmark and h and h > kill and rand() < 0.62 then
				local id = theme.decor[1 + math.floor(rand() * #theme.decor)]
				local z = -2.5 - rand() * 3.2
				if id ~= "lab_panel" then
					local s = 0.75 + rand() * 0.7
					local dx = x + rand() * 1.5
					local d = add(gos, spawn.create(id, dx, h, z, 0, s, s, s))
					if id == "rock_small" or id == "rock_big" or id == "rock_arch" or id == "ruin_arch" then
						spawn.tint_rgb(d, theme.rock)
					elseif id == "crystal_cluster" then
						spawn.tint_rgb(d, theme.crystal or { 1, 1, 1 })
					end
					local sway = SWAY[id]
					if sway then
						view.sway[#view.sway + 1] = {
							id = id, go = d, x = dx, y = h, z = z, s = s,
							phase = rand() * math.pi * 2, amp = sway.amp, dx = sway.dx,
						}
					end
				end
			end
		end
	end
	-- flowers and small grass at the front rim of the banks
	if theme.flowers and #theme.flowers > 0 then
		for x = ex0, ex1, 2.2 do
			local clear_of_landmark = not view.landmark_x or math.abs(x - view.landmark_x) > 2.6
			if clear_of_landmark and outside_area(x, 1.4) and rand() < 0.5 then
				local h = terrain.height_at(geo, x)
				if h and h > kill then
					local id = theme.flowers[1 + math.floor(rand() * #theme.flowers)]
					local s = 0.75 + rand() * 0.55
					local dx = x + rand() * 1.2
					local z = 0.15 + rand() * 1.0
					local d = add(gos, spawn.create(id, dx, h, z, 0, s, s, s))
					local sway = SWAY[id]
					if sway then
						view.sway[#view.sway + 1] = {
							id = id, go = d, x = dx, y = h, z = z, s = s,
							phase = rand() * math.pi * 2, amp = sway.amp, dx = sway.dx,
						}
					end
				end
			end
		end
	end
	-- rocks breaking the cliff line
	for i = 1, 7 do
		local x = ex0 + (ex1 - ex0) * rand()
		local clear_of_landmark = not view.landmark_x or math.abs(x - view.landmark_x) > 2.8
		if clear_of_landmark and outside_area(x, 1.2) then
			local h = terrain.height_at(geo, x)
			if h and h > kill then
				local big = rand() < 0.3
				local s = big and (0.45 + rand() * 0.25) or (0.5 + rand() * 0.7)
				local id = big and "rock_big" or "rock_small"
				local d = add(gos, spawn.create(id, x, h - 0.15, 0.65, rand() * math.pi * 2, s, s, s))
				spawn.tint_rgb(d, theme.rock)
			end
		end
	end
	-- a little human touch near the start/finish
	for i, x in ipairs({ level.start - 5, level.finish + 3 }) do
		local h = terrain.height_at(geo, x)
		if h and h > kill and rand() < 0.8 then
			local id = i == 1 and "sign" or (rand() < 0.5 and "crate" or "fence")
			local s = 0.9 + rand() * 0.2
			add(gos, spawn.create(id, x, h, 0.6, 0, s, s, s))
		end
	end

	-- ---------------------------------------------------------- life
	spawn_fauna(view, gos, theme, level, geo, area, ex0, ex1, rand)
	spawn_ambient(view, gos, theme, ex0, ex1, rand)
	spawn_glints(view, gos, level, ex0, ex1, rand)

	if theme.panels then
		for x = ex0, ex1, 4.2 do
			for y = -3, 12, 4.2 do
				local p = add(gos, spawn.create("lab_panel", x, y, -9.0, 0, 2.7, 2.7, 1))
				local g = 0.9 + rand() * 0.1
				spawn.tint(p, g, g, g * 1.02, 1)
			end
		end
	end

	-- ---------------------------------------------------------- build helpers
	local a = level.area
	if a then
		view.grid = {}
		for gx = math.floor(a[1]), math.floor(a[3]), 2 do
			for gy = math.floor(a[2]), math.floor(a[4]), 2 do
				local chunk = add(gos, spawn.create("grid_dots", gx, gy, tuning.BUILD_PLANE_Z + 0.05, 0, 1, 1, 1))
				spawn.tint(chunk, 0.82, 0.98, 1, 0.22)
				view.grid[#view.grid + 1] = chunk
			end
		end
		view.zone = add(gos, spawn.create("zone", (a[1] + a[3]) * 0.5, (a[2] + a[4]) * 0.5, -1.7, 0, a[3] - a[1] + 1, a[4] - a[2] + 1, 1))
		spawn.tint(view.zone, 1, 1, 1, 0.05)
		-- crisp border of the build zone (thin quads with a constant world thickness)
		local zx, zy = (a[1] + a[3]) * 0.5, (a[2] + a[4]) * 0.5
		local zw, zh = a[3] - a[1] + 1, a[4] - a[2] + 1
		local edges = {
			{ zx, a[4] + 0.5, zw, 0.05 },
			{ zx, a[2] - 0.5, zw, 0.05 },
			{ a[1] - 0.5, zy, 0.05, zh },
			{ a[3] + 0.5, zy, 0.05, zh },
		}
		for _, e in ipairs(edges) do
			local edge = add(gos, spawn.create("zone", e[1], e[2], tuning.BUILD_PLANE_Z + 0.06, 0, e[3], e[4], 1))
			spawn.tint(edge, 0.62, 0.94, 1, 0.34)
			view.grid[#view.grid + 1] = edge
		end
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
		local s = 1 + p.flash * 0.25 + 0.015 * math.sin(t_acc * 3 + i)
		go.set_scale(vmath.vector3(s, s, 1), p.ring)
		go.set_scale(vmath.vector3(0.55 * s, 1.1 * s, 1), p.glow)
		spawn.overlay(p.glow, 1, 1, 1, p.flash * 0.8)
		spawn.tint_rgb(p.glow, p.color, math.min(1, pulse + p.flash * 0.4))
	end
	for _, ind in ipairs(view.indicators or {}) do
		local wave = (t_acc * 2.2 + ind.frac * 4.5) % (math.pi * 2)
		local bright = 0.4 + 0.6 * math.max(0, math.sin(wave))
		spawn.tint(ind.go, ind.col[1] * bright, ind.col[2] * bright, ind.col[3] * bright, 0.9)
	end
	for _, w in ipairs(view.waves) do
		local y = w.y + math.sin(t_acc * 1.15 + w.phase) * 0.05
		local x = w.x + math.sin(t_acc * 0.35 + w.phase) * 1.2
		spawn.set("water_wave", w.go, x, y, w.z, 0, w.sx, 1, 1)
	end
	for _, c in ipairs(view.clouds) do
		c.x = c.x + c.speed * dt
		if c.speed > 0 and c.x > c.x_max then
			c.x = c.x - c.span
		elseif c.speed < 0 and c.x < c.x_min then
			c.x = c.x + c.span
		end
		local y = c.y_base + math.sin(t_acc * c.bob_freq + c.phase) * c.bob_amp
		spawn.set("cloud", c.go, c.x, y, c.z, 0, c.s, c.s, c.s)
	end
	-- a light breeze in the trees and flowers
	for _, d in ipairs(view.sway) do
		local s = math.sin(t_acc * 1.15 + d.phase)
		spawn.set(d.id, d.go, d.x + s * d.dx, d.y, d.z, s * d.amp, d.s, d.s, d.s)
	end
	-- the windmill turns lazily
	for _, r in ipairs(view.rotors) do
		r.angle = r.angle - r.speed * dt
		spawn.set("windmill_blades", r.go, r.x, r.y, r.z, r.angle, r.s, r.s, r.s)
	end
	-- fauna: flocks, swift swallows, soaring raptors, lab drones, jumping fish, and butterflies
	for _, f in ipairs(view.fauna) do
		if f.kind == "bird_flock" then
			local lead = f.lead
			if f.ox == 0 and f.oy == 0 then
				lead.x = lead.x + lead.speed * dt
				if lead.x > lead.x1 then lead.x = lead.x0 end
			end
			local x = lead.x + f.ox
			local y = lead.y + f.oy + math.sin(t_acc * 1.2 + f.phase) * 0.35
			local z = lead.z + f.oz
			local flap = 0.8 + 0.22 * math.abs(math.sin(t_acc * 8.5 + f.phase))
			spawn.set("bird", f.go, x, y, z, 0, f.s, f.s * flap, f.s)
		elseif f.kind == "bird_fast" then
			f.x = f.x + f.speed * dt
			if f.x > f.x1 then f.x = f.x0 end
			local flap = 0.72 + 0.32 * math.abs(math.sin(t_acc * 13.0 + f.phase))
			local y = f.base_y + math.sin(t_acc * 2.0 + f.phase) * 1.4
			local pitch = math.cos(t_acc * 2.0 + f.phase) * 0.18
			spawn.set("bird", f.go, f.x, y, f.z, pitch, f.s, f.s * flap, f.s)
		elseif f.kind == "eagle" then
			local ang = t_acc * f.speed + f.phase
			local x = f.cx + math.cos(ang) * f.rx
			local z = f.cz + math.sin(ang) * f.rz
			local y = f.base_y + math.sin(ang * 2) * 0.5
			local yaw = -ang + math.pi * 0.5
			local flap = 0.94 + 0.08 * math.sin(t_acc * 2.2 + f.phase)
			spawn.set("bird", f.go, x, y, z, yaw, f.s, f.s * flap, f.s)
		elseif f.kind == "lab_drone" then
			f.x = f.x + f.speed * dt * f.dir
			if f.x > f.x1 then f.dir = -1 f.x = f.x1
			elseif f.x < f.x0 then f.dir = 1 f.x = f.x0 end
			local hover = math.sin(t_acc * 6.0 + f.phase) * 0.1
			local roll = math.sin(t_acc * 2.5 + f.phase) * 0.08
			spawn.set("debris", f.go, f.x, f.base_y + hover, f.z, roll, f.s, f.s * 0.75, f.s * 1.3)
		elseif f.kind == "fish" then
			local timer = (t_acc + f.phase) % f.interval
			if timer < f.jump_dur then
				if not f.visible then
					spawn.enable(f.go, true)
					f.visible = true
				end
				local t = timer / f.jump_dur
				local dy = 4.0 * f.jump_h * t * (1.0 - t)
				local x = f.x + (t - 0.5) * f.jump_dist
				local pitch = (0.5 - t) * 1.6
				spawn.set("bird", f.go, x, f.water_y + dy, f.z, pitch, f.s * 0.65, f.s * 0.35, f.s * 0.65)
			else
				if f.visible then
					spawn.enable(f.go, false)
					f.visible = false
				end
			end
		elseif f.kind == "butterfly" then
			local a = t_acc * f.speed + f.phase
			local x = f.x + math.cos(a) * f.radius
			local z = f.z + math.sin(a) * f.radius * 0.55
			local y = f.y + math.sin(a * 1.7) * 0.35
			spawn.set("butterfly", f.go, x, y, z, math.sin(a * 1.3) * 0.35, f.s, f.s, f.s)
		elseif f.kind == "bird" then
			f.x = f.x + f.speed * dt
			if f.x > f.x1 then f.x = f.x0 end
			local flap = 0.82 + 0.22 * math.abs(math.sin(t_acc * 7.5 + f.phase))
			local y = f.y + math.sin(t_acc * 0.9 + f.phase) * 0.9
			spawn.set("bird", f.go, f.x, y, f.z, 0, f.s, f.s * flap, f.s)
		end
	end
	-- petals / dust / sparks / snow
	for _, b in ipairs(view.ambient) do
		local x, y, z = b.x, b.y, b.z
		if b.kind == "petals" or b.kind == "snow" then
			local k = (t_acc * b.speed + b.offset) % b.span
			y = b.y - k
			if y < 0.25 then y = y + b.span end
			x = b.x + math.sin(t_acc * 1.1 + b.phase + k) * (b.kind == "snow" and 0.45 or 0.8)
			z = b.z + math.cos(t_acc * 0.8 + b.phase) * 0.35
		elseif b.kind == "sparks" then
			x = b.x + math.sin(t_acc * 0.7 + b.phase) * 0.8
			y = b.y + math.sin(t_acc * 1.5 + b.phase) * 0.7
			z = b.z + math.cos(t_acc * 0.55 + b.phase) * 0.45
		else -- dust
			x = b.x + math.sin(t_acc * 0.45 + b.phase) * 1.6
			y = b.y + math.sin(t_acc * 0.9 + b.phase) * 0.4
			z = b.z + math.cos(t_acc * 0.6 + b.phase) * 0.5
		end
		spawn.set("debris", b.go, x, y, z, t_acc * 0.4 + b.phase, b.s, b.s, b.s)
	end
	-- water sparkles
	for _, g in ipairs(view.glints) do
		local k = 0.5 + 0.5 * math.sin(t_acc * 2.1 + g.phase)
		spawn.set("shadow", g.go, g.x + math.sin(t_acc * 0.9 + g.phase) * 0.8, g.y, g.z, 0,
			g.s * (0.55 + 0.65 * k), 1, g.s * 0.32)
		spawn.tint(g.go, 1, 1, 1, 0.08 + 0.42 * k)
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
