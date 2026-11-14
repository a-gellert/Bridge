-- Player progress: stars and best spend per level, saved designs, unlocks, settings.
-- Pure Lua. The storage backend is injected (platform/storage.lua in the game, memory in tests).
local levels = require("game.levels.levels")

local M = {}

local VERSION = 1
local storage = {
	load = function() return nil end,
	save = function() end,
}

M.data = nil

function M.set_storage(s)
	storage = s
end

local function default()
	return {
		version = VERSION,
		levels = {},      -- [id] = { stars = 0..3, best_cost = number|nil, attempts = n }
		designs = {},     -- [id] = serialized blueprint
		sound = true,
		music = true,
		lang = "",
		last_level = 1,
		tutorial_done = false,
		runs = 0,
	}
end

function M.load()
	local ok, d = pcall(storage.load)
	if not ok or type(d) ~= "table" or d.version ~= VERSION then d = default() end
	local def = default()
	for k, v in pairs(def) do
		if d[k] == nil then d[k] = v end
	end
	M.data = d
	return d
end

function M.save()
	if M.data then pcall(storage.save, M.data) end
end

local function ensure()
	if not M.data then M.load() end
	return M.data
end

function M.level_state(id)
	local d = ensure()
	local st = d.levels[id]
	if not st then
		st = { stars = 0, attempts = 0 }
		d.levels[id] = st
	end
	return st
end

function M.stars(id)
	local st = ensure().levels[id]
	return st and st.stars or 0
end

function M.total_stars()
	local n = 0
	for _, st in pairs(ensure().levels) do n = n + (st.stars or 0) end
	return n
end

function M.chapter_stars(ch)
	local n = 0
	for i = ch.first, ch.last do n = n + M.stars(levels.list[i].id) end
	return n
end

function M.chapter_unlocked(ci)
	local ch = levels.chapters[ci]
	if not ch then return false end
	if ci == 1 then return true end
	-- previous chapter finished (every level has at least 1 star) and enough stars overall
	local prev = levels.chapters[ci - 1]
	for i = prev.first, prev.last do
		if M.stars(levels.list[i].id) == 0 then return false end
	end
	return M.total_stars() >= (ch.stars_required or 0)
end

function M.level_unlocked(index)
	local lvl = levels.list[index]
	if not lvl then return false end
	if not M.chapter_unlocked(lvl.chapter_index) then return false end
	if index == lvl.chapter.first then return true end
	return M.stars(levels.list[index - 1].id) > 0
end

-- First unlocked level without stars, else the last level played.
function M.next_level()
	for i = 1, levels.COUNT do
		if M.level_unlocked(i) and M.stars(levels.list[i].id) == 0 then return i end
	end
	local d = ensure()
	return math.max(1, math.min(levels.COUNT, d.last_level or 1))
end

-- Called when a vehicle reaches point B. Returns a summary for the result screen.
function M.record_win(level, vehicle_stars, cost)
	local st = M.level_state(level.id)
	local prev = st.stars
	local prev_best = st.best_cost
	st.stars = math.max(prev, vehicle_stars)
	if not st.best_cost or cost < st.best_cost then st.best_cost = cost end
	ensure().runs = (ensure().runs or 0) + 1
	M.save()
	return {
		stars = st.stars,
		prev_stars = prev,
		new_stars = st.stars - prev,
		best_cost = st.best_cost,
		new_record = prev_best == nil or cost < prev_best,
		first_clear = prev == 0,
	}
end

function M.record_attempt(level)
	local st = M.level_state(level.id)
	st.attempts = (st.attempts or 0) + 1
	ensure().last_level = level.index
end

function M.design(id)
	return ensure().designs[id]
end

function M.save_design(id, list)
	ensure().designs[id] = list
	M.save()
end

function M.set_setting(key, value)
	ensure()[key] = value
	M.save()
end

function M.get(key)
	return ensure()[key]
end

return M
