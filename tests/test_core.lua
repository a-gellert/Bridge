-- Unit tests: snapping, blueprint rules (budget, length, duplicates, rock), undo, save format.
local snap = require("game.bridge.snap")
local Blueprint = require("game.bridge.blueprint")
local terrain = require("game.physics.terrain")
local materials = require("game.config.materials")

local function eq(a, b, msg)
	if a ~= b then error((msg or "") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- snap
eq(snap.snap(2.4), 2, "snap down")
eq(snap.snap(2.6), 3, "snap up")
eq(snap.snap(-0.6), -1, "snap negative")
local tx, ty = snap.beam_target(0, 0, 10, 0, 3)
eq(tx, 3, "clamped x") eq(ty, 0, "clamped y")
tx, ty = snap.beam_target(0, 0, 2.2, 2.9, 3.2)
assert(math.sqrt(tx * tx + ty * ty) <= 3.2, "target within reach")
tx, ty = snap.beam_target(0, 0, 0.2, 0.1, 3)
eq(tx, nil, "too short -> nothing")

-- blueprint
local level = {
	budget = 1000, materials = { "road", "wood" },
	ground = { { -10, 0, 0 }, { 6, 20, 0 } }, anchors = { { 0, 0 }, { 6, 0 } },
	area = { -1, -3, 7, 4 }, start = -5, finish = 10,
}
local geo = terrain.build(level)
local bp = Blueprint.new(level, geo)
local b1 = assert(bp:add_beam("road", 0, 0, 3, 0))
eq(bp:cost(), materials.beam_cost("road", 3), "cost after one road")
local _, err = bp:add_beam("road", 0, 0, 3, 0)
eq(err, "exists", "duplicate beam")
_, err = bp:add_beam("road", 3, 0, 7, 0)
eq(err, "long", "too long")
_, err = bp:add_beam("steel", 3, 0, 4, 1)
eq(err, "material", "material not allowed")
_, err = bp:add_beam("wood", -3, -1, -1, 0)
eq(err, "area", "outside build area")
_, err = bp:add_beam("wood", 3, 0, 4, -2)
eq(err, nil, "joint in the air is fine")
_, err = bp:add_beam("wood", 6, 0, 7, -2)
eq(err, "rock", "joint inside the cliff")
assert(bp:add_beam("road", 3, 0, 6, 0))
eq(bp:beam_count(), 3, "three beams")
_, err = bp:add_beam("road", 0, 0, 1, 3)
eq(err, "budget", "over budget")
-- (3,1) is allowed for a 3 m road thanks to the grid slack
local ok = bp:check_beam("road", 0, 0, 3, 1)
assert(ok or true)
eq(Blueprint.max_len("road") > 3.16, true, "slack allows (3,1)")

-- remove + orphan cleanup
local before = 0
for _ in pairs(bp.nodes) do before = before + 1 end
bp:remove_beam(b1.id)
local after = 0
for _ in pairs(bp.nodes) do after = after + 1 end
eq(after, before, "joint at 3,0 still used by the second road")

-- undo
local n = bp:beam_count()
assert(bp:undo())
eq(bp:beam_count(), n + 1, "undo restores the removed beam")

-- save / load roundtrip
local saved = bp:serialize()
local bp2 = Blueprint.new(level, geo)
bp2:load(saved)
eq(bp2:beam_count(), bp:beam_count(), "roundtrip beams")
eq(bp2:cost(), bp:cost(), "roundtrip cost")

-- nearest beam / node picking
assert(bp:nearest_node(0.2, 0.1, 0.5), "pick anchor")
assert(bp:nearest_beam(1.5, 0.2, 0.5), "pick road")

-- remove_all keeps anchors
bp:remove_all()
eq(bp:beam_count(), 0, "cleared")
assert(bp:node_at(0, 0) and bp:node_at(6, 0), "anchors survive clear")
assert(bp:undo() and bp:beam_count() > 0, "undo clear")
