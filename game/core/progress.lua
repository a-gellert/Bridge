-- Player progress: stars and best spend per level, saved designs, unlocks, wallet, skins,
-- achievements and settings. Pure Lua. The storage backend is injected by platform/boot.lua.
local levels = require("game.levels.levels")
local skins = require("game.config.skins")

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

local function default_stats()
	return {
		attempts = 0, runs = 0, wins = 0, losses = 0, crashes = 0,
		built = 0, erased = 0, portals = 0, bounces = 0, boosts = 0, tricks = 0,
	}
end

local function default_skins()
	return {
		owned = { ["body:classic"] = true, ["wheel:classic"] = true, ["topper:none"] = true },
		body = {}, wheel = {}, topper = {},
	}
end

local function default()
	return {
		version = VERSION,
		levels = {},      -- [id] = { stars = 0..3, best_cost = number|nil, attempts = n, fails = n }
		designs = {},     -- [id] = serialized blueprint
		sound = true,
		music = true,
		haptics = true,
		lang = "",
		last_level = 1,
		tutorial_done = false,
		runs = 0,
		wallet = 0,       -- leftover budget dollars, spent in the garage
		skins = default_skins(),
		achievements = {}, -- [id] = true
		stats = default_stats(),
	}
end

local function merge_defaults(d)
	local def = default()
	for k, v in pairs(def) do
		if d[k] == nil then d[k] = v end
	end
	-- nested tables from older saves
	local ds = default_stats()
	for k, v in pairs(ds) do
		if d.stats[k] == nil then d.stats[k] = v end
	end
	local dk = default_skins()
	if type(d.skins.owned) ~= "table" then d.skins.owned = {} end
	for k, v in pairs(dk.owned) do
		if d.skins.owned[k] == nil then d.skins.owned[k] = v end
	end
	for _, kind in ipairs(skins.kinds) do
		if type(d.skins[kind]) ~= "table" then d.skins[kind] = {} end
	end
	return d
end

function M.load()
	local ok, d = pcall(storage.load)
	if not ok or type(d) ~= "table" or d.version ~= VERSION then d = default() end
	M.data = merge_defaults(d)
	return M.data
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
	return levels.chapters[ci] ~= nil
end

function M.level_unlocked(index)
	local lvl = levels.list[index]
	if not lvl then return false end
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
-- `opts.clean` = no beam broke, `opts.broken` = beams broken during the run.
function M.record_win(level, vehicle_stars, cost, opts)
	opts = opts or {}
	local d = ensure()
	local st = M.level_state(level.id)
	local prev = st.stars
	local prev_best = st.best_cost
	st.stars = math.max(prev, vehicle_stars)
	st.fails = 0
	if not st.best_cost or cost < st.best_cost then st.best_cost = cost end
	d.runs = (d.runs or 0) + 1
	d.stats = d.stats or default_stats()
	d.stats.runs = (d.stats.runs or 0) + 1
	d.stats.wins = (d.stats.wins or 0) + 1
	-- leftover budget becomes spendable money, plus a clean-run and a star bonus.
	-- Replaying an already-solved level pays a small fraction, so skins are not farmed instantly.
	local first_or_record = prev == 0 or prev_best == nil or cost < prev_best
	local leftover = math.max(0, (level.budget or 0) - cost)
	local salary = math.floor(leftover * 0.12) + vehicle_stars * 10
	if opts.clean then salary = salary + 25 end
	if not first_or_record then salary = math.max(5, math.floor(salary * 0.25)) end
	d.wallet = (d.wallet or 0) + salary
	M.save()
	return {
		stars = st.stars,
		prev_stars = prev,
		new_stars = st.stars - prev,
		best_cost = st.best_cost,
		new_record = prev_best == nil or cost < prev_best,
		first_clear = prev == 0,
		salary = salary,
		wallet = d.wallet,
	}
end

function M.record_attempt(level)
	local st = M.level_state(level.id)
	local d = ensure()
	st.attempts = (st.attempts or 0) + 1
	d.last_level = level.index
	d.stats = d.stats or default_stats()
	d.stats.attempts = (d.stats.attempts or 0) + 1
	M.save()
end

-- Consecutive defeats on a level (drives the dynamic hint / +25% budget assist).
function M.record_fail(level)
	local st = M.level_state(level.id)
	st.fails = (st.fails or 0) + 1
	local d = ensure()
	d.stats = d.stats or default_stats()
	d.stats.losses = (d.stats.losses or 0) + 1
	M.save()
	return st.fails
end

function M.fail_streak(id)
	local st = ensure().levels[id]
	return st and st.fails or 0
end

function M.stats()
	local d = ensure()
	d.stats = d.stats or default_stats()
	return d.stats
end

function M.bump(kind, n)
	local d = ensure()
	d.stats = d.stats or default_stats()
	d.stats[kind] = (d.stats[kind] or 0) + (n or 1)
	M.save()
end

-- ------------------------------------------------------------------ wallet / skins
function M.wallet()
	return ensure().wallet or 0
end

function M.add_money(n)
	local d = ensure()
	d.wallet = (d.wallet or 0) + math.max(0, math.floor((n or 0) + 0.5))
	M.save()
	return d.wallet
end

function M.spend(n)
	local d = ensure()
	n = math.max(0, math.floor((n or 0) + 0.5))
	if (d.wallet or 0) < n then return false end
	d.wallet = d.wallet - n
	M.save()
	return true
end

function M.skin_owned(key)
	return ensure().skins.owned[key] == true
end

function M.owned_skin_count()
	local n = 0
	for _, v in pairs(ensure().skins.owned) do
		if v then n = n + 1 end
	end
	return n
end

-- Grants a skin without spending (rewarded video, achievement, star unlock).
function M.grant_skin(key)
	local d = ensure()
	if d.skins.owned[key] then return false end
	d.skins.owned[key] = true
	M.save()
	return true
end

-- Buys a skin with the wallet. Returns ok, reason ("owned" | "money" | "price").
function M.buy_skin(key, price)
	local d = ensure()
	if d.skins.owned[key] then return false, "owned" end
	price = math.max(0, math.floor((price or 0) + 0.5))
	if price > 0 then
		if (d.wallet or 0) < price then return false, "money" end
		d.wallet = d.wallet - price
	end
	d.skins.owned[key] = true
	M.save()
	return true
end

function M.select_skin(kind, vehicle, id)
	local d = ensure()
	d.skins[kind][vehicle] = id
	M.save()
end

-- Selected id of a cosmetic category for one vehicle.
function M.skin_for(kind, vehicle)
	local d = ensure()
	local id = d.skins[kind] and d.skins[kind][vehicle]
	if id and d.skins.owned[kind .. ":" .. id] then return id end
	return skins.default_id(kind)
end

-- ------------------------------------------------------------------ achievements
function M.has_achievement(id)
	return ensure().achievements[id] == true
end

function M.achievement_count()
	local n = 0
	for _, v in pairs(ensure().achievements) do
		if v then n = n + 1 end
	end
	return n
end

function M.unlock_achievement(id, reward)
	local d = ensure()
	if d.achievements[id] then return false end
	d.achievements[id] = true
	if reward and reward > 0 then d.wallet = (d.wallet or 0) + reward end
	M.save()
	return true
end

-- Every level of at least one chapter has 3 stars (18 stars per chapter).
function M.any_chapter_full()
	for _, ch in ipairs(levels.chapters) do
		local full = true
		for i = ch.first, ch.last do
			if M.stars(levels.list[i].id) < 3 then full = false break end
		end
		if full then return true end
	end
	return false
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
