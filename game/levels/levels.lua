-- Campaign index: chapters in order, flattened into one level list.
-- Add a chapter = create game/levels/chapterN.lua and list it in CHAPTER_MODULES.
local CHAPTER_MODULES = {
	"game.levels.chapter1",
	"game.levels.chapter2",
	"game.levels.chapter3",
	"game.levels.chapter4",
}

local M = {}

M.chapters = {}
M.list = {}
M.by_id = {}

for ci, mod in ipairs(CHAPTER_MODULES) do
	local ch = require(mod)
	ch.index = ci
	ch.first = #M.list + 1
	for li, lvl in ipairs(ch.levels) do
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
