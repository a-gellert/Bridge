-- Visual registry: logical visual id -> factory + transform tweaks.
-- The game logic never references meshes directly, so replacing any model is a data change:
--   1. Put your model (.glb/.gltf/.dae) anywhere under assets/ and point entities/<id>.go to it
--      (or create a new .go and add a factory for it in world/world.go).
--   2. If its size/origin/orientation differ from the stock model, set scale / offset / rot here.
-- Conventions of stock models: see tools/gen/models.js (beams are 1 m long along x, centered).
--
-- Fields:
--   factory  factory component id in world/world.go
--   scale    uniform scale multiplier (number) or {x, y, z}
--   offset   {x, y, z} added in the object's local space (e.g. to lift a model)
--   rot      extra rotation around z in degrees (e.g. a model that faces left)
--   alpha    true = drawn in the translucent pass (material voxel_alpha)
local M = {}

M.defs = {
	-- beams (scaled along x by the beam length)
	beam_road = { factory = "f_beam_road" },
	beam_steel_road = { factory = "f_beam_steel_road" },
	beam_boost = { factory = "f_beam_boost" },
	beam_bounce = { factory = "f_beam_bounce" },
	beam_wood = { factory = "f_beam_wood" },
	beam_steel = { factory = "f_beam_steel" },
	beam_rope = { factory = "f_beam_rope" },
	beam_cable = { factory = "f_beam_cable" },
	-- joints
	node_joint = { factory = "f_node_joint" },
	node_anchor = { factory = "f_node_anchor" },
	-- vehicles (origin = physics body center) and wheels
	veh_moto = { factory = "f_veh_moto" },
	veh_car = { factory = "f_veh_car" },
	veh_truck = { factory = "f_veh_truck" },
	wheel_moto = { factory = "f_wheel_moto" },
	wheel_car = { factory = "f_wheel_car" },
	wheel_truck = { factory = "f_wheel_truck" },
	-- terrain (tinted by theme)
	terrain_body = { factory = "f_terrain_body" },
	terrain_top = { factory = "f_terrain_top" },
	wedge_up = { factory = "f_wedge_up" },
	wedge_dn = { factory = "f_wedge_dn" },
	block = { factory = "f_block" },
	water = { factory = "f_water", alpha = true },
	water_top = { factory = "f_water_top", alpha = true },
	water_wave = { factory = "f_water_wave", alpha = true },
	sky_band = { factory = "f_sky_band" },
	-- level props
	flag_finish = { factory = "f_flag_finish" },
	flag_start = { factory = "f_flag_start" },
	portal_blue = { factory = "f_portal_blue" },
	portal_orange = { factory = "f_portal_orange" },
	portal_glow = { factory = "f_portal_glow", alpha = true },
	spikes = { factory = "f_spikes" },
	-- build mode helpers
	grid_dots = { factory = "f_grid_dots", alpha = true },
	zone = { factory = "f_zone", alpha = true },
	select_ring = { factory = "f_select_ring" },
	shadow = { factory = "f_shadow", alpha = true },
	debris = { factory = "f_debris" },
	-- decor
	tree = { factory = "f_tree" },
	pine = { factory = "f_pine" },
	bush = { factory = "f_bush" },
	rock_small = { factory = "f_rock_small" },
	rock_big = { factory = "f_rock_big" },
	cloud = { factory = "f_cloud" },
	mountain = { factory = "f_mountain" },
	lab_panel = { factory = "f_lab_panel" },
	stump = { factory = "f_stump" },
	crate = { factory = "f_crate" },
	fence = { factory = "f_fence" },
	sign = { factory = "f_sign" },
	flower_red = { factory = "f_flower_red" },
	flower_yellow = { factory = "f_flower_yellow" },
	flower_blue = { factory = "f_flower_blue" },
	flower_white = { factory = "f_flower_white" },
	-- Blender-authored hero decor (self-contained .glb, same palette + material)
	tree_blossom = { factory = "f_tree_blossom", scale = 0.9 },
	pine_tall = { factory = "f_pine_tall", scale = 0.9 },
	rock_arch = { factory = "f_rock_arch" },
	ruin_arch = { factory = "f_ruin_arch" },
	crystal_cluster = { factory = "f_crystal_cluster" },
	windmill = { factory = "f_windmill" },
	windmill_blades = { factory = "f_windmill_blades" },
	spoiler = { factory = "f_spoiler" },
	bird = { factory = "f_bird" },
	butterfly = { factory = "f_butterfly" },
	lab_generator = { factory = "f_lab_generator", scale = 1.0 },
	lab_terminal = { factory = "f_lab_terminal", scale = 0.95 },
	energy_pylon = { factory = "f_energy_pylon", scale = 1.0 },
	cactus_saguaro = { factory = "f_cactus_saguaro", scale = 0.85 },
	lantern_post = { factory = "f_lantern_post", scale = 0.9 },
	chamber_sign = { factory = "f_chamber_sign", scale = 1.0 },
}

local DEFAULT = { scale = 1, offset = nil, rot = 0 }

function M.get(id)
	local d = M.defs[id]
	if not d then error("unknown visual '" .. tostring(id) .. "'") end
	return d
end

-- Factory URL relative to the world game object (world/world.script lives next to the factories).
function M.factory(id)
	return "#" .. M.get(id).factory
end

function M.scale(id)
	return M.get(id).scale or DEFAULT.scale
end

return M
