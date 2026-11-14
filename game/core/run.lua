-- One test drive: builds the XPBD world from level + blueprint, spawns the vehicle, steps the
-- simulation with a fixed timestep and judges the run (finish, fall, flip, stuck, spikes, portals).
-- Pure Lua: used by the game and by the headless tests.
local tuning = require("game.config.tuning")
local materials = require("game.config.materials")
local vehicles = require("game.config.vehicles")
local Sim = require("game.physics.sim")
local Vehicle = require("game.physics.vehicle")
local terrain = require("game.physics.terrain")

local sqrt, cos, sin, abs = math.sqrt, math.cos, math.sin, math.abs
local atan2 = math.atan2 or math.atan

local M = {}
M.__index = M

M.RUNNING, M.WON, M.FAILED = "running", "won", "failed"

function M.new(level, geo, blueprint, vehicle_id)
	local self = setmetatable({}, M)
	self.level = level
	self.geo = geo
	self.vehicle_def = vehicles.get(vehicle_id)
	local sim = Sim.new()
	self.sim = sim

	for _, s in ipairs(geo.segments) do
		sim:add_static(s.x1, s.y1, s.x2, s.y2, { friction = 1 })
	end
	for _, s in ipairs(geo.node_segments) do
		sim:add_node_static(s.x1, s.y1, s.x2, s.y2)
	end

	-- joints: anchors are fixed, free joints get half of every attached beam's mass
	self.particle_of = {}
	local extra = {}
	for _, bm in pairs(blueprint.beams) do
		local m = materials.get(bm.mat).mass * blueprint:beam_length(bm) * 0.5
		extra[bm.a] = (extra[bm.a] or 0) + m
		extra[bm.b] = (extra[bm.b] or 0) + m
	end
	local node_ids = {}
	for id in pairs(blueprint.nodes) do node_ids[#node_ids + 1] = id end
	table.sort(node_ids)
	for _, id in ipairs(node_ids) do
		local n = blueprint.nodes[id]
		local mass = n.anchor and 0 or (tuning.NODE_MASS + (extra[id] or 0))
		local p = sim:add_particle(n.x, n.y, mass)
		self.particle_of[id] = p
		if not n.anchor then sim:add_node_collider(p, 0) end
	end

	-- beams
	self.beam_of = {}
	local beam_ids = {}
	for id in pairs(blueprint.beams) do beam_ids[#beam_ids + 1] = id end
	table.sort(beam_ids)
	for _, id in ipairs(beam_ids) do
		local bm = blueprint.beams[id]
		local mat = materials.get(bm.mat)
		local len = blueprint:beam_length(bm)
		local c = sim:add_beam(self.particle_of[bm.a], self.particle_of[bm.b], {
			rest = len,
			compliance = len / mat.stiffness,
			max_t = mat.max_t,
			max_c = mat.rope and 0 or mat.max_c,
			rope = mat.rope,
			damping = mat.damping,
			drivable = mat.drivable,
			half = mat.drivable and tuning.DECK_HALF or 0,
			friction = mat.friction or 1,
			surface = mat.surface,
			id = id,
			tag = "bridge",
		})
		c.mat = bm.mat
		self.beam_of[id] = c
	end

	-- vehicle on the start ground
	local def = self.vehicle_def
	local sx = level.start
	local ground = terrain.height_at(geo, sx) or 0
	local cy = ground + vehicles.ground_offset(def) + 0.04
	self.vehicle = Vehicle.new(sim, def, sx, cy)

	self.status = M.RUNNING
	self.reason = nil
	self.time = 0
	self.acc = 0
	self.max_x = sx
	self.stuck_t = 0
	self.flip_t = 0
	self.portal_cd = 0
	self.events = {}
	self.kill_y = level.water or level.kill_y or -12
	self.broken = 0
	return self
end

local function emit(self, ev)
	self.events[#self.events + 1] = ev
end

function M:pop_events()
	local ev = self.events
	if #ev == 0 then return nil end
	self.events = {}
	return ev
end

local function finish(self, status, reason)
	if self.status ~= M.RUNNING then return end
	self.status = status
	self.reason = reason
	self.end_time = self.time
	if status == M.WON then
		self.vehicle.input.gas = false
		self.vehicle.input.brake = false
		self.vehicle.coast = true
	else
		self.vehicle:disable()
	end
	emit(self, { type = status, reason = reason })
end

local function check_portals(self)
	local portals = self.level.portals
	if not portals or self.portal_cd > 0 then return end
	local v = self.vehicle
	local vx, vy = v:velocity()
	local px, py = v.sim.x, v.sim.y
	local r2 = tuning.PORTAL_RADIUS * tuning.PORTAL_RADIUS
	for i, p in ipairs(portals) do
		local a, b = p[1], p[2]
		local inside = false
		for _, pi in ipairs(v.particles) do
			local dx, dy = px[pi] - a.x, py[pi] - a.y
			if dx * dx + dy * dy < r2 then inside = true break end
		end
		if inside then
			local nax, nay = cos(a.angle), sin(a.angle)
			if vx * nax + vy * nay < 0 then
				local speed = math.max(sqrt(vx * vx + vy * vy), p.min_speed or 6)
				local nbx, nby = cos(b.angle), sin(b.angle)
				local body = abs(nbx) > 0.5 and atan2(nby, nbx) or 0
				if nbx < 0 then body = body - math.pi end
				local off = 0.9 + v.def.body.w * 0.5
				local tx, ty = b.x + nbx * off, b.y + nby * off
				if abs(nbx) > 0.5 then
					-- sideways exit: the vehicle rolls out on the portal floor
					ty = b.y - tuning.PORTAL_FLOOR + vehicles.ground_offset(v.def) + 0.05
				end
				v:teleport(tx, ty, body, nbx * speed, nby * speed)
				self.portal_cd = tuning.PORTAL_COOLDOWN
				emit(self, { type = "portal", index = i, x = b.x, y = b.y })
				return
			end
		end
	end
end

local function judge(self, dt)
	local level = self.level
	local v = self.vehicle
	local cx, cy = v:center()

	if self.status == M.RUNNING then
		if cx >= level.finish and cy > self.kill_y + 1 then
			finish(self, M.WON)
			return
		end
		if cy < self.kill_y then
			finish(self, M.FAILED, "fell")
			return
		end
		for _, s in ipairs(level.spikes or {}) do
			if v:touches_box(s[1], s[2], s[3], s[4], 0.2) then
				finish(self, M.FAILED, "spikes")
				return
			end
		end
		if v:up_y() < -0.2 then
			self.flip_t = self.flip_t + dt
			if self.flip_t > tuning.FLIP_TIME then
				finish(self, M.FAILED, "flipped")
				return
			end
		else
			self.flip_t = 0
		end
		if cx > self.max_x + tuning.STUCK_PROGRESS then
			self.max_x = cx
			self.stuck_t = 0
		else
			self.stuck_t = self.stuck_t + dt
			if self.stuck_t > tuning.STUCK_TIME then
				finish(self, M.FAILED, "stuck")
				return
			end
		end
		if self.time > tuning.RUN_TIME_LIMIT then
			finish(self, M.FAILED, "stuck")
			return
		end
		check_portals(self)
	end
end

-- One fixed simulation step.
function M:step()
	local dt = tuning.FIXED_DT
	if self.portal_cd > 0 then self.portal_cd = self.portal_cd - dt end
	self.sim:step(dt)
	self.time = self.time + dt
	local ev = self.sim:pop_events()
	if ev then
		for _, e in ipairs(ev) do
			if e.type == "break" and e.beam.tag == "bridge" then
				self.broken = self.broken + 1
				local c = e.beam
				local x, y = self.sim.x, self.sim.y
				emit(self, { type = "break", id = c.id, mat = c.mat, x = (x[c.a] + x[c.b]) * 0.5, y = (y[c.a] + y[c.b]) * 0.5 })
			end
		end
	end
	local v = self.vehicle
	if v.bounced then
		v.bounced = false
		emit(self, { type = "bounce" })
	end
	if v.boosted then
		v.boosted = false
		if not self.boost_sent then emit(self, { type = "boost" }) end
		self.boost_sent = true
	else
		self.boost_sent = false
	end
	judge(self, dt)
end

-- Advance by a frame time using fixed steps. Returns the number of steps taken.
function M:update(dt)
	self.acc = self.acc + math.min(dt, 0.1)
	local steps = 0
	while self.acc >= tuning.FIXED_DT and steps < tuning.MAX_STEPS_PER_FRAME do
		self.acc = self.acc - tuning.FIXED_DT
		self:step()
		steps = steps + 1
	end
	if steps == tuning.MAX_STEPS_PER_FRAME then self.acc = 0 end
	return steps
end

-- Current world positions of a blueprint beam's ends.
function M:beam_ends(bp_beam_id)
	local c = self.beam_of[bp_beam_id]
	if not c then return nil end
	local x, y = self.sim.x, self.sim.y
	return x[c.a], y[c.a], x[c.b], y[c.b], c
end

function M:node_pos(node_id)
	local p = self.particle_of[node_id]
	return self.sim.x[p], self.sim.y[p]
end

return M
