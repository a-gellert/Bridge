-- Build materials catalog. Add a material = add one entry here (+ a visual in visuals.lua).
--   cost       $ per meter
--   max_len    longest beam in grid steps (meters)
--   mass       kg per meter
--   stiffness  axial stiffness (N); spring constant = stiffness / length
--   max_t      tension that breaks the beam (N)
--   max_c      compression that breaks the beam (N)
--   rope       true = works only in tension (slacks when compressed)
--   drivable   true = wheels collide with it
--   surface    special effect for wheels: "boost" | "bounce" | nil
--   unlock     first level index (1-based, campaign order) where the material appears
local M = {}

M.list = {
	{
		id = "road", name_key = "mat_road", icon = "mat_road", visual = "beam_road",
		color = { 0.30, 0.32, 0.38 },
		cost = 120, max_len = 3, mass = 55, stiffness = 6.0e6, max_t = 36000, max_c = 36000,
		drivable = true, friction = 1.1, damping = 30, unlock = 1,
	},
	{
		id = "wood", name_key = "mat_wood", icon = "mat_wood", visual = "beam_wood",
		color = { 0.78, 0.52, 0.27 },
		cost = 45, max_len = 4, mass = 14, stiffness = 3.5e6, max_t = 24000, max_c = 42000,
		damping = 30, unlock = 2,
	},
	{
		id = "rope", name_key = "mat_rope", icon = "mat_rope", visual = "beam_rope",
		color = { 0.86, 0.74, 0.50 },
		cost = 25, max_len = 8, mass = 3, stiffness = 1.2e6, max_t = 26000, max_c = 0,
		rope = true, damping = 12, unlock = 4,
	},
	{
		id = "steel", name_key = "mat_steel", icon = "mat_steel", visual = "beam_steel",
		color = { 0.86, 0.24, 0.20 },
		cost = 110, max_len = 5, mass = 26, stiffness = 1.2e7, max_t = 80000, max_c = 80000,
		damping = 30, unlock = 16,
	},
	{
		id = "cable", name_key = "mat_cable", icon = "mat_cable", visual = "beam_cable",
		color = { 0.62, 0.66, 0.72 },
		cost = 70, max_len = 12, mass = 6, stiffness = 6.0e6, max_t = 90000, max_c = 0,
		rope = true, damping = 12, unlock = 43,
	},
	{
		id = "steel_road", name_key = "mat_steel_road", icon = "mat_steel_road", visual = "beam_steel_road",
		color = { 0.95, 0.62, 0.15 },
		cost = 220, max_len = 4, mass = 80, stiffness = 1.4e7, max_t = 95000, max_c = 95000,
		drivable = true, friction = 1.1, damping = 30, unlock = 40,
	},
	{
		id = "boost", name_key = "mat_boost", icon = "mat_boost", visual = "beam_boost",
		color = { 1.00, 0.52, 0.11 },
		cost = 260, max_len = 3, mass = 60, stiffness = 6.0e6, max_t = 40000, max_c = 40000,
		drivable = true, friction = 1.1, damping = 30, surface = "boost", unlock = 82,
	},
	{
		id = "bounce", name_key = "mat_bounce", icon = "mat_bounce", visual = "beam_bounce",
		color = { 0.20, 0.55, 0.95 },
		cost = 200, max_len = 3, mass = 60, stiffness = 6.0e6, max_t = 40000, max_c = 40000,
		drivable = true, friction = 1.0, damping = 30, surface = "bounce", unlock = 99,
	},
}

M.by_id = {}
for i, m in ipairs(M.list) do
	m.order = i
	M.by_id[m.id] = m
end

function M.get(id)
	return M.by_id[id]
end

-- Price of one beam of a given length (rounded to whole dollars).
function M.beam_cost(id, len)
	local m = M.by_id[id]
	return math.floor(m.cost * len + 0.5)
end

return M
