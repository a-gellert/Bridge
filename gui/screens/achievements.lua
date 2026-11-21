-- Achievements: a simple grid of 15 local awards with unlock state and reward.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local progress = require("game.core.progress")
local achievements = require("game.core.achievements")
local layout = require("gui.layout")

local M = {}

function M.build(app, root)
	local vw, vh = app.vw, app.vh
	local ml, mr, mt, mb = layout.margins(vw, vh, 16)
	local top_w = vw - ml - mr
	local top_h = 84

	local top = ui.panel(root, vw / 2, vh - mt - top_h / 2, top_w, top_h, ui.PANEL, 22)
	ui.blocker(top)
	ui.btn(top, -top_w / 2 + 66, 0, 112, app.touch and 72 or 64, "", function() app.show("menu") end, { icon = "back", icon_size = 38 })
	ui.text(top, i18n.t("achievements"), 0, 2, 36, ui.WHITE)
	-- trophy + counter hug the right edge (clear of the centred title even on a 720-wide portrait bar)
	ui.icon(top, "trophy", top_w / 2 - 212, 2, 36, ui.STAR)
	ui.label(top, i18n.f("ach_unlocked", progress.achievement_count(), achievements.count()), top_w / 2 - 104, 2, 24, ui.WHITE, 170)

	-- narrow cards (portrait, 4:3) move the reward under the icon so the title gets the whole row
	local narrow = app.portrait or top_w < 1100
	local list = achievements.list
	local cols = app.portrait and 2 or 3
	local rows = math.ceil(#list / cols)
	local gap = 12
	local area_top = vh - mt - top_h - 26
	local area_bottom = mb + 16
	local card_w = math.min(app.portrait and 470 or 430, (top_w - (cols - 1) * gap) / cols)
	local card_h = math.min(app.portrait and 150 or 132, (area_top - area_bottom - (rows - 1) * gap) / rows)
	local grid_h = rows * card_h + (rows - 1) * gap
	local y0 = area_top - math.max(0, (area_top - area_bottom - grid_h) / 2) - card_h / 2
	for i, a in ipairs(list) do
		local k = i - 1
		local col, row = k % cols, math.floor(k / cols)
		local x = vw / 2 + (col - (cols - 1) / 2) * (card_w + gap)
		local y = y0 - row * (card_h + gap)
		local done = progress.has_achievement(a.id)
		local card = ui.panel(root, x, y, card_w, card_h, done and ui.hex("#2C4B39") or ui.hex("#232838"), 18)
		-- icon disc with a small state badge (check / lock) on its corner
		local ix = -card_w / 2 + 46
		local disc = math.min(64, card_h - 30)
		-- portrait cards are narrow: the reward moves under the icon so the title gets the full row
		local iy = narrow and 10 or 0
		ui.box(card, "circle", ix, iy, disc, disc, done and ui.hex("#3FA86B") or ui.hex("#3A4157"))
		ui.icon(card, a.icon, ix, iy, disc * 0.56, done and ui.WHITE or ui.DIM)
		local badge = ui.box(card, "circle", ix + disc * 0.36, iy - disc * 0.36, 26, 26, done and ui.GREEN or ui.hex("#4A536D"))
		ui.icon(badge, done and "check" or "lock", 0, 0, 15, ui.WHITE)
		-- title + reward on the first row, description below
		local tx = -card_w / 2 + 92
		local row1 = card_h / 2 - 22
		local reward = i18n.f("ach_reward", i18n.money(a.reward))
		local reward_color = done and ui.GREEN or ui.YELLOW
		if narrow then
			ui.text(card, reward, ix, -card_h / 2 + 15, 17, reward_color)
		else
			ui.text(card, reward, card_w / 2 - 14, row1, 18, reward_color, gui.PIVOT_E)
		end
		ui.label(card, i18n.t("ach_" .. a.id), tx, row1, 22, done and ui.WHITE or ui.hex("#C9D0E0"),
			card_w - 108 - (narrow and 0 or 78), 1, gui.PIVOT_W)
		ui.label(card, i18n.t("ach_" .. a.id .. "_d"), tx, -12, app.portrait and 19 or 17, done and ui.hex("#C8E9D5") or ui.hex("#8F98AE"),
			card_w - 108, 2, gui.PIVOT_W)
	end
end

function M.on_key(app, action_id, action)
	if action.pressed and app.key_names[action_id] == "back" then
		app.show("menu")
		return true
	end
	return false
end

return M
