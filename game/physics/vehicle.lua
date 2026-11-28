-- Vehicle on top of the XPBD world: rigid 4-particle body + spring-mounted wheels with a tire model.
-- Auto-drive: the vehicle rolls at `cruise` throttle; input.gas = full throttle / nose down in the air,
-- input.brake = brake, then reverse / nose up in the air.
local tuning = require("game.config.tuning")

local sqrt, atan2, abs, min, max = math.sqrt, math.atan2 or math.atan, math.abs, math.min, math.max

local M = {}
M.__index = M

-- Corner order: 1 rear-bottom, 2 front-bottom, 3 front-top, 4 rear-top
function M.new(sim, def, cx, cy)
	local self = setmetatable({}, M)
	self.def = def
	self.sim = sim
	self.input = { gas = false, brake = false }
	self.enabled = true
	local bw, bh = def.body.w * 0.5, def.body.h * 0.5
	local cm = def.body.mass / 4
	local corners = { { -bw, -bh }, { bw, -bh }, { bw, bh }, { -bw, bh } }
	self.c = {}
	for i, c in ipairs(corners) do
		self.c[i] = sim:add_particle(cx + c[1], cy + c[2], cm)
	end
	local rigid = { tag = "vehicle" }
	for i = 1, 4 do
		sim:add_beam(self.c[i], self.c[i % 4 + 1], rigid)
	end
	sim:add_beam(self.c[1], self.c[3], rigid)
	sim:add_beam(self.c[2], self.c[4], rigid)
	for i = 1, 4 do
		sim:add_collider({ p = self.c[i], r = def.body.corner_r or 0.12, friction = 0.7, vehicle = self, top = i >= 3 })
	end

	self.wheels = {}
	local mount = {
		compliance = 2 / def.susp_stiffness,
		damping = def.susp_damping,
		tag = "vehicle",
	}
	for i, wd in ipairs(def.wheels) do
		local p = sim:add_particle(cx + wd.x, cy + wd.y, wd.mass)
		local wheel = {
			p = p, r = wd.r, omega = 0, angle = 0,
			inv_inertia = 1 / (0.6 * wd.mass * wd.r * wd.r),
			contact = false,
		}
		for k = 1, 4 do
			sim:add_beam(p, self.c[k], mount)
		end
		sim:add_collider({ p = p, r = wd.r, friction = def.grip, wheel = wheel, vehicle = self, compliance = tuning.TIRE_COMPLIANCE })
		self.wheels[i] = wheel
	end
	self.total_mass = def.body.mass
	for _, wd in ipairs(def.wheels) do self.total_mass = self.total_mass + wd.mass end
	self.particles = {}
	for i = 1, 4 do self.particles[#self.particles + 1] = self.c[i] end
	for _, wh in ipairs(self.wheels) do self.particles[#self.particles + 1] = wh.p end
	self.grounded = false
	self.bounce_cd = 0
	self.boost_t = 0
	sim.vehicles[#sim.vehicles + 1] = self
	return self
end

-- ------------------------------------------------------------------ queries
function M:center()
	local x, y = self.sim.x, self.sim.y
	local c = self.c
	return (x[c[1]] + x[c[2]] + x[c[3]] + x[c[4]]) * 0.25, (y[c[1]] + y[c[2]] + y[c[3]] + y[c[4]]) * 0.25
end

-- Body angle (radians, CCW) from the rear-bottom -> front-bottom edge.
function M:angle()
	local x, y = self.sim.x, self.sim.y
	local a, b = self.c[1], self.c[2]
	return atan2(y[b] - y[a], x[b] - x[a])
end

-- y of the body "up" vector (1 = upright, -1 = upside down)
function M:up_y()
	return math.cos(self:angle())
end

function M:velocity()
	local vx, vy = self.sim.vx, self.sim.vy
	local c = self.c
	return (vx[c[1]] + vx[c[2]] + vx[c[3]] + vx[c[4]]) * 0.25, (vy[c[1]] + vy[c[2]] + vy[c[3]] + vy[c[4]]) * 0.25
end

function M:speed()
	local vx, vy = self:velocity()
	return sqrt(vx * vx + vy * vy)
end

-- Any wheel resting on a drivable beam (bridge deck)? Used by the wedge rescue in run.lua.
function M:on_deck()
	for _, wh in ipairs(self.wheels) do
		if wh.on_deck then return true end
	end
	return false
end

function M:wheel_pos(i)
	local p = self.wheels[i].p
	return self.sim.x[p], self.sim.y[p]
end

-- Any vehicle particle inside an axis-aligned box?
function M:touches_box(x0, y0, x1, y1, pad)
	pad = pad or 0
	local x, y = self.sim.x, self.sim.y
	for _, p in ipairs(self.particles) do
		if x[p] > x0 - pad and x[p] < x1 + pad and y[p] > y0 - pad and y[p] < y1 + pad then return true end
	end
	return false
end

-- ------------------------------------------------------------------ control (called by the sim every substep)
local function apply_spin(self, alpha, h)
	-- angular acceleration around the body center (CCW positive)
	local x, y, vx, vy = self.sim.x, self.sim.y, self.sim.vx, self.sim.vy
	local cx, cy = self:center()
	local dw = alpha * h
	for i = 1, 4 do
		local p = self.c[i]
		local rx, ry = x[p] - cx, y[p] - cy
		vx[p] = vx[p] - ry * dw
		vy[p] = vy[p] + rx * dw
	end
end

function M:control(h)
	for _, wh in ipairs(self.wheels) do wh.pre_vy = self.sim.vy[wh.p] end
	if not self.enabled then
		for _, wh in ipairs(self.wheels) do
			wh.omega = wh.omega * max(0, 1 - 3 * h)
		end
		return
	end
	local def = self.def
	local inp = self.input
	local grounded = false
	for _, wh in ipairs(self.wheels) do
		if wh.contact then grounded = true end
	end
	self.grounded = grounded

	-- Motor model: each wheel is driven toward a target spin, limited by a torque sized so that the
	-- whole vehicle accelerates at `accel` (or decelerates at `brake`) when the tires grip.
	local share = self.total_mass / #self.wheels
	local function toward(wh, target, accel)
		local d = share * accel * wh.r * wh.inv_inertia * h
		local diff = target - wh.omega
		if diff > d then diff = d elseif diff < -d then diff = -d end
		wh.omega = wh.omega + diff
	end

	if self.coast then
		-- finished: roll to a stop, never reverse
		for _, wh in ipairs(self.wheels) do toward(wh, 0, def.brake * 0.4) end
		return
	end

	if inp.brake then
		local vx = self:velocity()
		for _, wh in ipairs(self.wheels) do
			if vx > 0.6 then
				toward(wh, 0, def.brake)
			else
				toward(wh, -def.reverse / wh.r, def.accel * 0.6)
			end
		end
	else
		local throttle = inp.gas and 1 or def.cruise
		for _, wh in ipairs(self.wheels) do
			local target = def.max_speed * throttle / wh.r
			if wh.omega < target then
				toward(wh, target, def.accel)
			elseif self.boost_t <= 0 then
				toward(wh, target, def.accel * 0.15) -- light engine braking (not right after a boost)
			end
		end
	end

	if not grounded then
		local dir = 0
		if inp.gas then dir = -1 elseif inp.brake then dir = 1 end
		if dir ~= 0 then apply_spin(self, dir * def.air_torque, h) end
	end
end

-- Special surfaces act on the whole vehicle (a wheel alone is too light to carry the body).
function M:post_substep(h)
	local sim = self.sim
	local vx, vy = sim.vx, sim.vy
	local bounce_nx, bounce_ny
	local boosts, btx, bty = 0, 0, 0
	for _, wh in ipairs(self.wheels) do
		wh.angle = wh.angle - wh.omega * h -- visual spin (CW when rolling forward)
		-- first contact after falling: remember the impact for dust / camera shake
		if wh.contact and not wh.was_contact and (wh.pre_vy or 0) < -4 then
			local power = math.min(1, (-wh.pre_vy - 4) / 10)
			if not self.landed or power > self.landed.power then
				self.landed = { x = sim.x[wh.p], y = sim.y[wh.p], power = power }
			end
		end
		wh.was_contact = wh.contact
		if wh.surface == "bounce" then
			bounce_nx, bounce_ny = wh.snx, wh.sny
		elseif wh.surface == "boost" then
			boosts = boosts + 1
			btx, bty = wh.sny, -wh.snx
		end
		wh.surface = nil
	end
	if self.bounce_cd > 0 then self.bounce_cd = self.bounce_cd - h end
	if self.boost_t > 0 then self.boost_t = self.boost_t - h end
	if bounce_nx and self.bounce_cd <= 0 then
		local target = tuning.BOUNCE_SPEED
		for _, p in ipairs(self.particles) do
			local vn = vx[p] * bounce_nx + vy[p] * bounce_ny
			if vn < target then
				vx[p] = vx[p] + bounce_nx * (target - vn)
				vy[p] = vy[p] + bounce_ny * (target - vn)
			end
		end
		self.bounce_cd = 0.35
		self.bounced = true
	end
	if boosts > 0 and self.enabled then
		local a = tuning.BOOST_ACCEL * h * boosts / #self.wheels
		for _, p in ipairs(self.particles) do
			vx[p] = vx[p] + btx * a
			vy[p] = vy[p] + bty * a
		end
		for _, wh in ipairs(self.wheels) do
			wh.omega = wh.omega + a / wh.r
		end
		self.boost_t = 0.6
		self.boosted = true
	end
end

-- ------------------------------------------------------------------ teleport (portals)
-- Moves the whole vehicle so that its center lands on (tx, ty), rotates it to `angle` and sets velocity
-- (vx, vy) on every particle. Wheel spin is matched to the new speed.
function M:teleport(tx, ty, angle, nvx, nvy)
	local sim = self.sim
	local x, y, ox, oy, vx, vy = sim.x, sim.y, sim.ox, sim.oy, sim.vx, sim.vy
	local cx, cy = self:center()
	local da = angle - self:angle()
	local ca, sa = math.cos(da), math.sin(da)
	for _, p in ipairs(self.particles) do
		local rx, ry = x[p] - cx, y[p] - cy
		local nx, ny = tx + rx * ca - ry * sa, ty + rx * sa + ry * ca
		x[p], y[p], ox[p], oy[p] = nx, ny, nx, ny
		vx[p], vy[p] = nvx, nvy
	end
	local spd = sqrt(nvx * nvx + nvy * nvy)
	for _, wh in ipairs(self.wheels) do
		wh.omega = spd / wh.r
	end
end

-- Stop the engine (crash / finish).
function M:disable()
	self.enabled = false
	self.input.gas, self.input.brake = false, false
end

return M
