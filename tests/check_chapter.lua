-- Design helper: node run.js check_chapter.lua  (edit CHAPTER below) prints every level of one chapter.
local check = require("level_check")
local CHAPTER = os.getenv and os.getenv("CHAPTER") or "1"
local ch = require("game.levels.chapter" .. CHAPTER)
for _, lvl in ipairs(ch.levels) do
	check.check(lvl)
end
