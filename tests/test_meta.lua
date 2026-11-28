-- Meta layer: wallet, skin purchases/selection, fail streaks, salary and achievements.
local progress = require("game.core.progress")
local achievements = require("game.core.achievements")
local skins = require("game.config.skins")
local levels = require("game.levels.levels")

local store
progress.set_storage({
	load = function() return store end,
	save = function(d) store = d end,
})
progress.load()

local function eq(a, b, msg)
	if a ~= b then error((msg or "") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- defaults
eq(progress.wallet(), 0, "fresh wallet")
assert(progress.skin_owned("body:classic"), "classic paint owned")
assert(progress.skin_owned("wheel:classic"), "stock wheels owned")
assert(progress.skin_owned("topper:none"), "no topper owned")
eq(progress.skin_for("body", "truck"), "classic", "default paint")
eq(progress.owned_skin_count(), 3, "three default items")

-- wallet
progress.add_money(100)
eq(progress.wallet(), 100, "money added")
assert(not progress.spend(150), "cannot overspend")
assert(progress.spend(40), "spend")
eq(progress.wallet(), 60, "wallet after spend")

-- purchases
local ok, why = progress.buy_skin("body:toxic", 140)
assert(not ok and why == "money", "not enough money for paint")
progress.add_money(200)
assert(progress.buy_skin("body:toxic", 140), "buy paint")
assert(progress.skin_owned("body:toxic"), "paint owned")
progress.select_skin("body", "truck", "toxic")
eq(progress.skin_for("body", "truck"), "toxic", "paint selected")
eq(progress.skin_for("body", "car"), "classic", "selection is per vehicle")

-- fail streak and win reset
local lvl = levels.get(1)
progress.record_fail(lvl)
progress.record_fail(lvl)
eq(progress.fail_streak(lvl.id), 2, "two failures")
progress.record_fail(lvl)
eq(progress.fail_streak(lvl.id), 3, "three failures (assist available)")
local res = progress.record_win(lvl, 3, 360, { clean = true })
eq(progress.fail_streak(lvl.id), 0, "win clears the streak")
assert(res.salary and res.salary > 0, "win pays a salary")
eq(res.wallet, progress.wallet(), "result reports the wallet")

-- salary math: floor(140 * 0.12) + 3*10 + 25 = 71
eq(res.salary, 71, "salary from leftover budget + clean + stars")

-- achievements unlock once and pay the reward
local before = progress.wallet()
local list = achievements.check({ stats = { built = 1 } })
assert(#list == 1 and list[1].id == "first_bridge", "first bridge achievement")
assert(progress.wallet() == before + list[1].reward, "achievement reward paid")
assert(#achievements.check({ stats = { built = 1 } }) == 0, "no duplicate achievement")

-- golden paint + collector
progress.grant_skin("body:gold")
local list2 = achievements.check_meta()
local has_gold = false
for _, a in ipairs(list2) do if a.id == "golden" then has_gold = true end end
assert(has_gold, "golden achievement")
assert(#achievements.list == 15, "15 achievements")

-- a full chapter unlocks the champion paint requirement
for i = levels.chapters[1].first, levels.chapters[1].last do
	progress.level_state(levels.list[i].id).stars = 3
end
assert(progress.any_chapter_full(), "chapter one full")

-- skins catalog is consistent
for _, kind in ipairs(skins.kinds) do
	local list = skins.list_of(kind)
	assert(#list >= 4, kind .. " has enough items")
	for _, item in ipairs(list) do
		assert(item.key == kind .. ":" .. item.id, "key " .. item.key)
		assert(skins.get(kind, item.id) == item, "lookup " .. item.key)
	end
end

print(string.format("   wallet $%d, %d skins owned, %d achievements", progress.wallet(), progress.owned_skin_count(), progress.achievement_count()))
