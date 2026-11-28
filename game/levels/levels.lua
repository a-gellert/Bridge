-- Campaign index: chapters in order, flattened into one level list.
-- Add a chapter = create game/levels/chapterN.lua and add a require line to CHAPTERS.
-- Requires must be string literals: Defold only bundles Lua modules it can find statically
-- (a require(variable) builds fine but fails at runtime with "module not found").
local CHAPTERS = {
	require("game.levels.chapter1"),
	require("game.levels.chapter2"),
	require("game.levels.chapter3"),
	require("game.levels.chapter4"),
}
local NAMES = require("game.core.names")

local M = {}

M.chapters = {}
M.list = {}
M.by_id = {}

-- Source data keeps en/ru inline; the other languages live in game/core/names.lua.
local function apply_names(entry, source)
	local extra = entry.name and source[entry.name.en]
	if extra then
		for lang, text in pairs(extra) do entry.name[lang] = text end
	end
end

for ci, ch in ipairs(CHAPTERS) do
	ch.index = ci
	ch.first = #M.list + 1
	apply_names(ch, NAMES.chapters)
	for li, lvl in ipairs(ch.levels) do
		apply_names(lvl, NAMES.levels)
		-- Absolute campaign index: the blueprint makes every material with unlock <= index
		-- available, so the toolbox grows and never shrinks between levels.
		lvl.index = #M.list + 1
		lvl.chapter = ch
		lvl.chapter_index = ci
		lvl.number = li
		lvl.theme = lvl.theme or ch.theme
		M.list[#M.list + 1] = lvl
		M.by_id[lvl.id] = lvl
	end
	ch.last = #M.list
	M.chapters[ci] = ch
end

M.COUNT = #M.list
M.MAX_STARS = M.COUNT * 3

-- Player path: blocks of BLOCK levels rotate through the biomes
-- (1-1..1-8, 2-1..2-8, 3-1..3-8, 4-1..4-8, 1-9..1-16, ...), so a new setting and new
-- mechanics show up every few minutes instead of after 40 levels of one chapter.
-- `path` holds campaign indices in that order, `path_pos[index]` is the reverse lookup.
M.BLOCK = 8
M.path = {}
M.path_pos = {}
local longest = 0
for _, ch in ipairs(M.chapters) do longest = math.max(longest, ch.last - ch.first + 1) end
for b = 0, math.ceil(longest / M.BLOCK) - 1 do
	for _, ch in ipairs(M.chapters) do
		for n = b * M.BLOCK + 1, (b + 1) * M.BLOCK do
			local index = ch.first + n - 1
			if index <= ch.last then
				M.path[#M.path + 1] = index
				M.path_pos[index] = #M.path
			end
		end
	end
end

-- Last level of a block: the result card offers the next biome here.
function M.is_block_end(lvl)
	return lvl ~= nil and lvl.number % M.BLOCK == 0
end

function M.get(index)
	return M.list[index]
end

return M
