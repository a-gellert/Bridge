-- Player path: biome blocks rotate (1-1..1-8, 2-1..2-8, 3-1..3-8, 4-1..4-8, 1-9..), the menu
-- "Play" follows that path, and the biome card at a block end targets another chapter.
local progress = require("game.core.progress")
local levels = require("game.levels.levels")

local store = nil
progress.set_storage({
	load = function() return store end,
	save = function(d) store = d end,
})
progress.load()

local function id(index) return levels.list[index].id end
local function index_of(lid) return levels.by_id[lid].index end
local function solve(lid) progress.level_state(lid).stars = 1 end

-- the path is a permutation of every level
assert(#levels.path == levels.COUNT, "path covers every level")
local seen = {}
for pos, i in ipairs(levels.path) do
	assert(not seen[i], "level twice on the path: " .. id(i))
	seen[i] = true
	assert(levels.path_pos[i] == pos, "path_pos mismatch at " .. id(i))
end

-- block order
local expect = { [1] = "1-1", [8] = "1-8", [9] = "2-1", [17] = "3-1", [25] = "4-1", [33] = "1-9", [41] = "2-9" }
for pos, lid in pairs(expect) do
	assert(id(levels.path[pos]) == lid, string.format("path[%d] = %s, expected %s", pos, id(levels.path[pos]), lid))
end
assert(levels.is_block_end(levels.by_id["1-8"]) and levels.is_block_end(levels.by_id["2-16"]))
assert(not levels.is_block_end(levels.by_id["1-9"]))

-- fresh profile starts at 1-1
assert(id(progress.next_level()) == "1-1")

-- 1-1..1-8 done: the biome card targets 2-1, the menu continues there too
for n = 1, 8 do solve("1-" .. n) end
assert(id(progress.next_biome_level(index_of("1-8"))) == "2-1", "1-8 -> Red Canyon")
assert(id(progress.next_level()) == "2-1", "menu follows the path, not 1-9")

-- the portal shortcut skipped the Canyon: after 3-8 the card goes back to 2-1
for n = 1, 8 do solve("3-" .. n) end
assert(id(progress.next_biome_level(index_of("3-8"))) == "2-1", "unvisited biome first")

-- first round complete: the next round starts in the Valley at 1-9
for n = 1, 8 do solve("2-" .. n) end
for n = 1, 8 do solve("4-" .. n) end
assert(id(progress.next_biome_level(index_of("4-8"))) == "1-9", "round 2 starts at 1-9")
assert(id(progress.next_level()) == "1-9")

-- a chapter's own levels are never the biome target
for n = 9, 16 do solve("1-" .. n) end
local t = progress.next_biome_level(index_of("1-16"))
assert(levels.list[t].chapter_index ~= 1 and id(t) == "2-9", "1-16 -> 2-9, got " .. id(t))

-- nothing left elsewhere: no target
for _, lvl in ipairs(levels.list) do
	if lvl.chapter_index ~= 1 then solve(lvl.id) end
end
assert(progress.next_biome_level(index_of("1-16")) == nil, "no other chapter left")
