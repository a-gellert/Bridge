-- Front-layer decor must stay out of the start..finish corridor: it has no collision,
-- but a rock, crate or fence in front of the truck reads as an obstacle (and hides the run).
local mock = require("defold_mock")
local ROOT = package.path:match("^(.-)/%?%.lua")
mock.read_factories(ROOT .. "/world/world.go")
local levels = require("game.levels.levels")
local level_view = require("world.level_view")

local BLOCKERS = {
	crate = true, fence = true, sign = true,
	rock_small = true, rock_big = true, rock_arch = true, ruin_arch = true,
	stump = true, bush = true, cactus_saguaro = true, lantern_post = true,
	tree = true, tree_blossom = true, pine = true, pine_tall = true,
}

local bad = {}
for _, lvl in ipairs(levels.list) do
	level_view.build(lvl)
	for _, o in pairs(mock.objects) do
		local prop = o.factory:match("^f_(.+)$")
		local x, z = o.pos.x, o.pos.z
		if BLOCKERS[prop] and z > 0.1 and x >= lvl.start - 2 and x <= lvl.finish + 8 then
			bad[#bad + 1] = string.format("%s: %s at x=%.1f z=%.1f", lvl.id, prop, x, z)
		end
	end
end
if #bad > 0 then
	error("decor on the drive path:\n" .. table.concat(bad, "\n"))
end
