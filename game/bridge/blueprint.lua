-- Editable bridge design: joints (nodes) and beams, budget, validation, undo, save format (pure Lua).
local tuning = require("game.config.tuning")
local materials = require("game.config.materials")
local terrain = require("game.physics.terrain")

local sqrt, abs, floor = math.sqrt, math.abs, math.floor

local M = {}
M.__index = M

local function key(x, y)
	return floor(x * 100 + 0.5) .. ":" .. floor(y * 100 + 0.5)
end

local function dist(ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	return sqrt(dx * dx + dy * dy)
end

-- level: level table (see game/levels), geo: terrain.build(level) result
function M.new(level, geo)
	local self = setmetatable({}, M)
	self.level = level
	self.geo = geo or terrain.build(level)
	self.budget = level.budget
	self.allowed = {}
	for _, id in ipairs(level.materials) do self.allowed[id] = true end
	self.version = 0
	self.undo_stack = {}
	self:clear()
	return self
end

function M:clear()
	self.nodes = {}
	self.node_by_key = {}
	self.beams = {}
	self.next_node = 1
	self.next_beam = 1
	self.total = 0
	for _, a in ipairs(self.level.anchors) do
		self:_add_node(a[1], a[2], true)
	end
	self.version = self.version + 1
end

function M:_add_node(x, y, anchor)
	local id = self.next_node
	self.next_node = id + 1
	local n = { id = id, x = x, y = y, anchor = anchor or false, beams = 0 }
	self.nodes[id] = n
	self.node_by_key[key(x, y)] = n
	return n
end

function M:_remove_node(n)
	self.nodes[n.id] = nil
	self.node_by_key[key(n.x, n.y)] = nil
end

-- ------------------------------------------------------------------ queries
function M:node_at(x, y)
	return self.node_by_key[key(x, y)]
end

function M:nearest_node(x, y, tol)
	local best, bd
	for _, n in pairs(self.nodes) do
		local d = dist(x, y, n.x, n.y)
		if d <= tol and (not bd or d < bd) then best, bd = n, d end
	end
	return best
end

function M:beam_between(a, b)
	for _, bm in pairs(self.beams) do
		if (bm.a == a and bm.b == b) or (bm.a == b and bm.b == a) then return bm end
	end
	return nil
end

function M:beam_length(bm)
	local a, b = self.nodes[bm.a], self.nodes[bm.b]
	return dist(a.x, a.y, b.x, b.y)
end

-- Beam whose segment is closest to (x, y) within tol.
function M:nearest_beam(x, y, tol)
	local best, bd
	for _, bm in pairs(self.beams) do
		local a, b = self.nodes[bm.a], self.nodes[bm.b]
		local ex, ey = b.x - a.x, b.y - a.y
		local l2 = ex * ex + ey * ey
		local t = l2 > 0 and ((x - a.x) * ex + (y - a.y) * ey) / l2 or 0
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		local d = dist(x, y, a.x + ex * t, a.y + ey * t)
		if d <= tol and (not bd or d < bd) then best, bd = bm, d end
	end
	return best
end

function M:cost()
	return self.total
end

function M:remaining()
	return self.budget - self.total
end

function M:beam_count()
	local n = 0
	for _ in pairs(self.beams) do n = n + 1 end
	return n
end

function M:in_area(x, y)
	local a = self.level.area
	if not a then return true end
	return x >= a[1] - 1e-6 and x <= a[3] + 1e-6 and y >= a[2] - 1e-6 and y <= a[4] + 1e-6
end

-- Real length limit of a material (with the grid slack).
function M.max_len(mat_id)
	return materials.get(mat_id).max_len * tuning.LENGTH_SLACK
end

-- ------------------------------------------------------------------ validation
-- Returns ok, err, cost. err: "material" | "short" | "long" | "area" | "rock" | "exists" | "budget"
function M:check_beam(mat_id, x1, y1, x2, y2)
	local mat = materials.get(mat_id)
	if not mat or not self.allowed[mat_id] then return false, "material", 0 end
	local len = dist(x1, y1, x2, y2)
	local cost = materials.beam_cost(mat_id, len)
	if len < tuning.MIN_BEAM then return false, "short", cost end
	if len > M.max_len(mat_id) + 1e-6 then return false, "long", cost end
	if not self:in_area(x1, y1) or not self:in_area(x2, y2) then return false, "area", cost end
	local n1, n2 = self:node_at(x1, y1), self:node_at(x2, y2)
	if (not n1 and terrain.point_inside(self.geo, x1, y1)) or (not n2 and terrain.point_inside(self.geo, x2, y2)) then
		return false, "rock", cost
	end
	if n1 and n2 and self:beam_between(n1.id, n2.id) then return false, "exists", cost end
	if self.total + cost > self.budget then return false, "budget", cost end
	return true, nil, cost
end

-- ------------------------------------------------------------------ editing
local function changed(self)
	self.version = self.version + 1
end

function M:push_undo()
	local st = self.undo_stack
	st[#st + 1] = self:serialize()
	if #st > tuning.UNDO_LIMIT then table.remove(st, 1) end
end

function M:can_undo()
	return #self.undo_stack > 0
end

function M:undo()
	local st = self.undo_stack
	if #st == 0 then return false end
	local snap = table.remove(st)
	self:load(snap, true)
	return true
end

-- Adds a beam (creating joints as needed). opts.no_undo skips the undo snapshot, opts.force skips budget.
function M:add_beam(mat_id, x1, y1, x2, y2, opts)
	opts = opts or {}
	local ok, err, cost = self:check_beam(mat_id, x1, y1, x2, y2)
	if not ok and not (opts.force and err == "budget") then return nil, err end
	if not opts.no_undo then self:push_undo() end
	local a = self:node_at(x1, y1) or self:_add_node(x1, y1, false)
	local b = self:node_at(x2, y2) or self:_add_node(x2, y2, false)
	local id = self.next_beam
	self.next_beam = id + 1
	local bm = { id = id, a = a.id, b = b.id, mat = mat_id, cost = cost }
	self.beams[id] = bm
	a.beams = a.beams + 1
	b.beams = b.beams + 1
	self.total = self.total + cost
	changed(self)
	return bm
end

function M:remove_beam(id, opts)
	opts = opts or {}
	local bm = self.beams[id]
	if not bm then return false end
	if not opts.no_undo then self:push_undo() end
	self.beams[id] = nil
	self.total = self.total - bm.cost
	for _, nid in ipairs({ bm.a, bm.b }) do
		local n = self.nodes[nid]
		n.beams = n.beams - 1
		if n.beams <= 0 and not n.anchor then self:_remove_node(n) end
	end
	changed(self)
	return true
end

function M:remove_all()
	if self:beam_count() == 0 then return false end
	self:push_undo()
	self:clear()
	return true
end

-- ------------------------------------------------------------------ save format
-- { {mat, x1, y1, x2, y2}, ... }
function M:serialize()
	local out = {}
	local ids = {}
	for id in pairs(self.beams) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local bm = self.beams[id]
		local a, b = self.nodes[bm.a], self.nodes[bm.b]
		out[#out + 1] = { bm.mat, a.x, a.y, b.x, b.y }
	end
	return out
end

-- Replace the design with `list`. Invalid beams (e.g. from an old save) are skipped.
function M:load(list, keep_undo)
	local st = self.undo_stack
	self:clear()
	if keep_undo then self.undo_stack = st else self.undo_stack = {} end
	for _, b in ipairs(list or {}) do
		self:add_beam(b[1], b[2], b[3], b[4], b[5], { no_undo = true })
	end
	changed(self)
end

return M
