-- Local achievements (no backend). Definitions live here; progress.lua stores which are unlocked.
-- `M.check(ctx)` is called by the session at meaningful moments and returns the newly unlocked list.
-- `ctx` may contain:
--   built (beams in the current design), beams, run (Run object), result (session result),
--   level, stats (progress counters), meta (true when checking shop/progress screens).
local progress = require("game.core.progress")

local M = {}

local function run_flag(ctx, name)
	return ctx.run and ctx.run[name] or false
end

local function won(ctx)
	return ctx.result and ctx.result.won or false
end

M.list = {
	{
		id = "first_bridge", icon = "bridge", reward = 25,
		test = function(ctx) return (ctx.stats and ctx.stats.built or 0) >= 1 end,
	},
	{
		id = "engineer", icon = "wrench", reward = 50,
		test = function(ctx) return (ctx.beams or 0) >= 10 end,
	},
	{
		id = "thrifty", icon = "coin", reward = 75,
		test = function(ctx) return won(ctx) and ctx.result.ratio <= 0.5 end,
	},
	{
		id = "acrobat", icon = "flip", reward = 100,
		test = function(ctx) return run_flag(ctx, "trick_landed") end,
	},
	{
		id = "heavy_artillery", icon = "truck", reward = 100,
		test = function(ctx)
			return won(ctx) and ctx.result.vehicle == "truck" and (ctx.result.broken or 0) == 0
		end,
	},
	{
		id = "quantum", icon = "portal", reward = 75,
		test = function(ctx) return (ctx.run and ctx.run.portals or 0) >= 3 end,
	},
	{
		id = "on_a_wing", icon = "bandage", reward = 125,
		test = function(ctx)
			return won(ctx) and (ctx.result.broken or 0) >= math.max(1, math.floor((ctx.result.beams or 0) * 0.8))
		end,
	},
	{
		id = "star_collector", icon = "star", reward = 150,
		test = function() return progress.total_stars() >= 72 end,
	},
	{
		id = "chapter_two", icon = "flag", reward = 50,
		test = function() return progress.chapter_stars(2) > 0 end,
	},
	{
		id = "speedrun", icon = "stopwatch", reward = 100,
		test = function(ctx) return won(ctx) and (ctx.result.time or 99) <= 8 end,
	},
	{
		id = "no_brake", icon = "nobrake", reward = 100,
		test = function(ctx) return won(ctx) and not run_flag(ctx, "used_brake") end,
	},
	{
		id = "crash_test", icon = "boom", reward = 50,
		test = function(ctx) return (ctx.stats and ctx.stats.crashes or 0) >= 10 end,
	},
	{
		id = "collector", icon = "brush", reward = 100,
		test = function() return progress.owned_skin_count() >= 5 end,
	},
	{
		id = "persistent", icon = "heart", reward = 75,
		test = function(ctx) return (ctx.stats and ctx.stats.attempts or 0) >= 50 end,
	},
	{
		id = "golden", icon = "trophy", reward = 200,
		test = function() return progress.skin_owned("body:gold") end,
	},
}

M.by_id = {}
for _, a in ipairs(M.list) do M.by_id[a.id] = a end

function M.count()
	return #M.list
end

function M.unlocked_count()
	return progress.achievement_count()
end

-- Returns the definitions unlocked by this check (and persists them).
function M.check(ctx)
	ctx = ctx or {}
	if not ctx.stats then ctx.stats = progress.stats() end
	local out = {}
	for _, a in ipairs(M.list) do
		if not progress.has_achievement(a.id) then
			local ok, unlocked = pcall(a.test, ctx)
			if ok and unlocked then
				progress.unlock_achievement(a.id, a.reward)
				out[#out + 1] = a
			end
		end
	end
	return out
end

-- Checks that only need saved progress (shop purchases, level select, menu).
function M.check_meta()
	return M.check({ meta = true })
end

return M
