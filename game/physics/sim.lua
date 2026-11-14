-- XPBD particle world (pure Lua, no Defold API).
--   particles : point masses (mass 0 = fixed anchor)
--   beams     : distance constraints with compliance, tension/compression limits and breaking
--   statics   : static terrain segments
--   colliders : circles bound to particles (wheels, vehicle corners) that hit statics and drivable beams
-- One step = SUBSTEPS x (integrate -> constraints -> collisions -> velocities -> friction/damping).
-- Forces are physical: beam force = lambda / h^2, so stress does not depend on the substep count.
local tuning = require("game.config.tuning")

local sqrt, abs, min, max = math.sqrt, math.abs, math.min, math.max
local HUGE = math.huge

local M = {}
M.__index = M

function M.new(cfg)
	cfg = cfg or {}
	local self = setmetatable({}, M)
	self.gravity = cfg.gravity or tuning.GRAVITY
	self.substeps = cfg.substeps or tuning.SUBSTEPS
	self.lin_damping = cfg.lin_damping or tuning.LIN_DAMPING
	self.stress_tau = cfg.stress_tau or tuning.STRESS_TAU
	self.n = 0
	self.x, self.y, self.ox, self.oy, self.vx, self.vy, self.w = {}, {}, {}, {}, {}, {}, {}
	self.beams = {}
	self.drivable = {}
	self.statics = {}
	self.colliders = {}
	self.vehicles = {}
	self.events = {}
	self.contacts = {}
	self.ncontacts = 0
	self.cand_static = {}
	self.cand_beams = {}
	self.node_cols = {}
	self.node_statics = {}
	self.time = 0
	return self
end

-- ------------------------------------------------------------------ building
function M:add_particle(x, y, mass)
	local i = self.n + 1
	self.n = i
	self.x[i], self.y[i], self.ox[i], self.oy[i] = x, y, x, y
	self.vx[i], self.vy[i] = 0, 0
	self.w[i] = (mass and mass > 0) and 1 / mass or 0
	return i
end

function M:add_mass(i, mass)
	if self.w[i] == 0 then return end
	self.w[i] = 1 / (1 / self.w[i] + mass)
end

-- p: rest, compliance, max_t, max_c, rope, damping, drivable, half, friction, surface, id, tag
function M:add_beam(a, b, p)
	p = p or {}
	local dx, dy = self.x[b] - self.x[a], self.y[b] - self.y[a]
	local c = {
		a = a, b = b,
		rest = p.rest or sqrt(dx * dx + dy * dy),
		compliance = p.compliance or 0,
		max_t = p.max_t or HUGE,
		max_c = p.max_c or HUGE,
		rope = p.rope or false,
		damping = p.damping or 0,
		drivable = p.drivable or false,
		half = p.half or 0,
		friction = p.friction or 1,
		surface = p.surface,
		id = p.id,
		tag = p.tag,
		force = 0,
		stress = 0,
		broken = false,
	}
	self.beams[#self.beams + 1] = c
	if c.drivable then self.drivable[#self.drivable + 1] = c end
	return c
end

function M:add_static(x1, y1, x2, y2, p)
	p = p or {}
	local s = {
		x1 = x1, y1 = y1, x2 = x2, y2 = y2,
		half = p.half or 0, friction = p.friction or 1, surface = p.surface,
		minx = min(x1, x2), maxx = max(x1, x2), miny = min(y1, y2), maxy = max(y1, y2),
	}
	local el = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
	s.snx, s.sny = -(y2 - y1) / el, (x2 - x1) / el
	self.statics[#self.statics + 1] = s
	return s
end

-- p: p (particle), r, friction, wheel (table|nil), vehicle, top (bool)
function M:add_collider(p)
	self.colliders[#self.colliders + 1] = p
	return p
end

-- Ground surface for bridge joints only (wheels use add_static).
function M:add_node_static(x1, y1, x2, y2)
	local s = {
		x1 = x1, y1 = y1, x2 = x2, y2 = y2, half = 0, friction = 1,
		minx = min(x1, x2), maxx = max(x1, x2), miny = min(y1, y2), maxy = max(y1, y2),
	}
	local el = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
	s.snx, s.sny = -(y2 - y1) / el, (x2 - x1) / el
	self.node_statics[#self.node_statics + 1] = s
	return s
end

-- A bridge joint that can rest on the ground.
function M:add_node_collider(p, r)
	local col = { p = p, r = r or 0.05, friction = 1, cand = {} }
	self.node_cols[#self.node_cols + 1] = col
	return col
end

function M:break_beam(c)
	if c.broken then return end
	c.broken = true
	c.stress = 0
	self.events[#self.events + 1] = { type = "break", beam = c }
end

-- ------------------------------------------------------------------ broad phase (once per step)
local function gather_node_candidates(self)
	local x, y = self.x, self.y
	local ns = self.node_statics
	local ncols = self.node_cols
	for i = 1, #ncols do
		local col = ncols[i]
		local cand = col.cand
		for k = #cand, 1, -1 do cand[k] = nil end
		local px, py = x[col.p], y[col.p]
		local m = col.r + 1
		for k = 1, #ns do
			local s = ns[k]
			if s.maxx >= px - m and s.minx <= px + m and s.maxy >= py - m and s.miny <= py + m then
				cand[#cand + 1] = s
			end
		end
	end
end

local function gather_candidates(self)
	gather_node_candidates(self)
	local cs, cb = self.cand_static, self.cand_beams
	for i = #cs, 1, -1 do cs[i] = nil end
	for i = #cb, 1, -1 do cb[i] = nil end
	local cols = self.colliders
	if #cols == 0 then return end
	local x, y = self.x, self.y
	local minx, maxx, miny, maxy = HUGE, -HUGE, HUGE, -HUGE
	local rmax = 0
	for i = 1, #cols do
		local c = cols[i]
		local px, py = x[c.p], y[c.p]
		if px < minx then minx = px end
		if px > maxx then maxx = px end
		if py < miny then miny = py end
		if py > maxy then maxy = py end
		if c.r > rmax then rmax = c.r end
	end
	-- margin covers the radius, deck thickness and one step of fast motion
	local m = rmax + 1.2
	minx, maxx, miny, maxy = minx - m, maxx + m, miny - m, maxy + m
	local st = self.statics
	for i = 1, #st do
		local s = st[i]
		if s.maxx >= minx and s.minx <= maxx and s.maxy >= miny and s.miny <= maxy then
			cs[#cs + 1] = s
		end
	end
	local dr = self.drivable
	for i = 1, #dr do
		local b = dr[i]
		if not b.broken then
			local ax, ay, bx, by = x[b.a], y[b.a], x[b.b], y[b.b]
			if max(ax, bx) >= minx and min(ax, bx) <= maxx and max(ay, by) >= miny and min(ay, by) <= maxy then
				cb[#cb + 1] = b
			end
		end
	end
end

-- ------------------------------------------------------------------ substep phases
local function integrate(self, h)
	local x, y, ox, oy, vx, vy, w = self.x, self.y, self.ox, self.oy, self.vx, self.vy, self.w
	local gh = self.gravity * h
	local damp = max(0, 1 - self.lin_damping * h)
	for i = 1, self.n do
		ox[i], oy[i] = x[i], y[i]
		if w[i] > 0 then
			local nvx = vx[i] * damp
			local nvy = (vy[i] + gh) * damp
			vx[i], vy[i] = nvx, nvy
			x[i] = x[i] + nvx * h
			y[i] = y[i] + nvy * h
		end
	end
end

local function solve_beams(self, h)
	local x, y, w = self.x, self.y, self.w
	local inv_h2 = 1 / (h * h)
	local smooth = h / (self.stress_tau + h)
	local beams = self.beams
	for k = 1, #beams do
		local c = beams[k]
		if not c.broken then
			local a, b = c.a, c.b
			local wa, wb = w[a], w[b]
			local ws = wa + wb
			if ws > 0 then
				local dx, dy = x[b] - x[a], y[b] - y[a]
				local len = sqrt(dx * dx + dy * dy)
				if len > 1e-9 then
					local C = len - c.rest
					local force = 0
					if not (c.rope and C < 0) then
						local dl = -C / (ws + c.compliance * inv_h2)
						local nx, ny = dx / len, dy / len
						x[a] = x[a] - wa * dl * nx
						y[a] = y[a] - wa * dl * ny
						x[b] = x[b] + wb * dl * nx
						y[b] = y[b] + wb * dl * ny
						force = -dl * inv_h2 -- > 0 tension, < 0 compression
					end
					c.force = force
					if c.max_t < HUGE or c.max_c < HUGE then
						local ratio
						if force >= 0 then
							ratio = force / c.max_t
						elseif c.max_c > 0 then
							ratio = -force / c.max_c
						else
							ratio = 0
						end
						c.stress = c.stress + (ratio - c.stress) * smooth
						if c.stress >= 1 then self:break_beam(c) end
					end
				end
			end
		end
	end
end

-- Contact record layout (reused tables): col, nx, ny, pn, seg (beam|nil), t, friction, surface
local function push_contact(self, col, nx, ny, pn, seg, t, friction, surface)
	local n = self.ncontacts + 1
	self.ncontacts = n
	local ct = self.contacts[n]
	if not ct then
		ct = {}
		self.contacts[n] = ct
	end
	ct.col, ct.nx, ct.ny, ct.pn, ct.seg, ct.t, ct.friction, ct.surface = col, nx, ny, pn, seg, t, friction, surface
end

local function closest_on_segment(px, py, ax, ay, bx, by)
	local ex, ey = bx - ax, by - ay
	local l2 = ex * ex + ey * ey
	local t = 0
	if l2 > 1e-12 then
		t = ((px - ax) * ex + (py - ay) * ey) / l2
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
	end
	return ax + ex * t, ay + ey * t, t, ex, ey
end

-- Circle (collider) vs static segment: push the collider out, record a contact.
-- Static segments are one-sided: (snx, sny) is the outward normal (left of x1,y1 -> x2,y2).
-- Points slightly behind the face are pushed back out; points deep behind it are left to other faces.
local function collide_static(self, col, s, h)
	local x, y = self.x, self.y
	local p = col.p
	local px, py = x[p], y[p]
	local snx, sny = s.snx, s.sny
	local sd = (px - s.x1) * snx + (py - s.y1) * sny
	local lim = col.r + s.half
	if sd >= lim or sd < -0.6 then return end
	local qx, qy, t = closest_on_segment(px, py, s.x1, s.y1, s.x2, s.y2)
	local nx, ny, pen
	if t > 0 and t < 1 then
		nx, ny, pen = snx, sny, lim - sd
	else
		-- beyond an end: round corner when in front of the face
		local dx, dy = px - qx, py - qy
		local d2 = dx * dx + dy * dy
		if d2 >= lim * lim then return end
		local d = sqrt(d2)
		if sd > 0 and d > 1e-6 then
			nx, ny, pen = dx / d, dy / d, lim - d
		else
			return -- past the end and behind the face: belongs to a neighbour face (e.g. hidden inner walls)
		end
	end
	if pen <= 0 then return end
	-- tires are compliant: the contact behaves like a stiff spring, which spreads impacts over a few ms
	local wc = self.w[p]
	local dl = pen / (wc + (col.compliance or 0) / (h * h))
	x[p] = px + nx * wc * dl
	y[p] = py + ny * wc * dl
	push_contact(self, col, nx, ny, dl / h, nil, t, s.friction, s.surface)
end

local function solve_collisions(self, h)
	local x, y, w = self.x, self.y, self.w
	local cols = self.colliders
	local cs, cb = self.cand_static, self.cand_beams
	self.ncontacts = 0
	for i = 1, #cols do
		local col = cols[i]
		col.touching = false
		if col.wheel then col.wheel.contact = false end
	end
	for i = 1, #cols do
		local col = cols[i]
		local p = col.p
		local wc = w[p]
		if wc > 0 then
			local r = col.r
			-- drivable beams first (two-way coupling: the bridge feels the wheel). A deck lying flush on the
			-- ground must win the contact, or its surface effect (boost / bounce) would never trigger.
			for k = 1, #cb do
				local b = cb[k]
				if not b.broken then
					local a, bb = b.a, b.b
					local px, py = x[p], y[p]
					local qx, qy, t, ex, ey = closest_on_segment(px, py, x[a], y[a], x[bb], y[bb])
					local dx, dy = px - qx, py - qy
					local d2 = dx * dx + dy * dy
					local lim = r + b.half
					if d2 < lim * lim then
						local d = sqrt(d2)
						local nx, ny
						if d > 1e-6 then
							nx, ny = dx / d, dy / d
						else
							local el = sqrt(ex * ex + ey * ey)
							nx, ny = -ey / el, ex / el
						end
						local pen = lim - d
						local wa, wb = w[a], w[bb]
						local u = 1 - t
						local wq = wa * u * u + wb * t * t
						local dl = pen / (wc + wq + (col.compliance or 0) / (h * h))
						x[p] = px + wc * dl * nx
						y[p] = py + wc * dl * ny
						x[a] = x[a] - wa * u * dl * nx
						y[a] = y[a] - wa * u * dl * ny
						x[bb] = x[bb] - wb * t * dl * nx
						y[bb] = y[bb] - wb * t * dl * ny
						push_contact(self, col, nx, ny, dl / h, b, t, b.friction, b.surface)
					end
				end
			end
			-- static terrain
			for k = 1, #cs do
				collide_static(self, col, cs[k], h)
			end
		end
	end
	-- bridge joints rest on the ground (raw level surface, without the deck offset)
	local ncols = self.node_cols
	for i = 1, #ncols do
		local col = ncols[i]
		local cand = col.cand
		for k = 1, #cand do
			collide_static(self, col, cand[k], h)
		end
	end
end

local function update_velocities(self, h)
	local x, y, ox, oy, vx, vy, w = self.x, self.y, self.ox, self.oy, self.vx, self.vy, self.w
	local inv_h = 1 / h
	for i = 1, self.n do
		if w[i] > 0 then
			vx[i] = (x[i] - ox[i]) * inv_h
			vy[i] = (y[i] - oy[i]) * inv_h
		end
	end
end

-- Friction / tire model / special surfaces at velocity level.
local function solve_contact_velocities(self, h)
	local vx, vy, w = self.vx, self.vy, self.w
	for k = 1, self.ncontacts do
		local ct = self.contacts[k]
		local col = ct.col
		local p = col.p
		local wc = w[p]
		local nx, ny = ct.nx, ct.ny
		local tx, ty = ny, -nx -- "forward" along the surface (to the right on a floor)
		local seg, t = ct.seg, ct.t
		local wq, svx, svy = 0, 0, 0
		local a, b, wa, wb, u
		if seg then
			a, b = seg.a, seg.b
			wa, wb = w[a], w[b]
			u = 1 - t
			wq = wa * u * u + wb * t * t
			svx = vx[a] * u + vx[b] * t
			svy = vy[a] * u + vy[b] * t
		end
		col.touching = true
		local wheel = col.wheel
		if wheel then wheel.contact = true end

		local rvx, rvy = vx[p] - svx, vy[p] - svy
		-- special surfaces: remembered on the wheel, the vehicle applies them to its whole body
		-- (use the deck's face normal, not the contact normal: on the rounded deck ends the contact normal
		-- tilts backwards and a bounce would steal forward speed)
		if wheel and ct.surface and seg then
			local ex, ey = self.x[b] - self.x[a], self.y[b] - self.y[a]
			local el = sqrt(ex * ex + ey * ey)
			if el > 1e-6 then
				local fnx, fny = -ey / el, ex / el
				if fnx * nx + fny * ny < 0 then fnx, fny = -fnx, -fny end
				if fny > 0.3 then wheel.surface, wheel.snx, wheel.sny = ct.surface, fnx, fny end
			end
		end

		-- friction impulse along the tangent, limited by Coulomb
		local vt = rvx * tx + rvy * ty
		local ang = 0
		if wheel then
			vt = vt - wheel.omega * wheel.r
			ang = wheel.r * wheel.r * wheel.inv_inertia
		end
		local denom = wc + wq + ang
		if denom > 0 then
			local P = -vt / denom
			local lim = ct.friction * (col.friction or 1) * ct.pn
			if P > lim then P = lim elseif P < -lim then P = -lim end
			vx[p] = vx[p] + wc * P * tx
			vy[p] = vy[p] + wc * P * ty
			if seg then
				vx[a] = vx[a] - wa * u * P * tx
				vy[a] = vy[a] - wa * u * P * ty
				vx[b] = vx[b] - wb * t * P * tx
				vy[b] = vy[b] - wb * t * P * ty
			end
			if wheel then
				wheel.omega = wheel.omega - wheel.r * wheel.inv_inertia * P
			end
		end
	end
end

local function damp_beams(self, h)
	local x, y, vx, vy, w = self.x, self.y, self.vx, self.vy, self.w
	local beams = self.beams
	for k = 1, #beams do
		local c = beams[k]
		if c.damping > 0 and not c.broken then
			local a, b = c.a, c.b
			local wa, wb = w[a], w[b]
			local ws = wa + wb
			if ws > 0 then
				local dx, dy = x[b] - x[a], y[b] - y[a]
				local len = sqrt(dx * dx + dy * dy)
				if len > 1e-9 then
					local nx, ny = dx / len, dy / len
					local vrel = (vx[b] - vx[a]) * nx + (vy[b] - vy[a]) * ny
					local f = c.damping * h -- damping = share of relative axial velocity removed per second
					if f > 1 then f = 1 end
					local dv = vrel * f / ws
					vx[a] = vx[a] + wa * dv * nx
					vy[a] = vy[a] + wa * dv * ny
					vx[b] = vx[b] - wb * dv * nx
					vy[b] = vy[b] - wb * dv * ny
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ step
function M:step(dt)
	local n = self.substeps
	local h = dt / n
	gather_candidates(self)
	local vehicles = self.vehicles
	for _ = 1, n do
		for i = 1, #vehicles do vehicles[i]:control(h) end
		integrate(self, h)
		solve_beams(self, h)
		solve_collisions(self, h)
		update_velocities(self, h)
		solve_contact_velocities(self, h)
		damp_beams(self, h)
		for i = 1, #vehicles do vehicles[i]:post_substep(h) end
	end
	self.time = self.time + dt
end

-- Drain events produced since the last call.
function M:pop_events()
	local ev = self.events
	if #ev == 0 then return nil end
	self.events = {}
	return ev
end

return M
