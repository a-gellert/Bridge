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

function M.get(index)
	return M.list[index]
end

return M
