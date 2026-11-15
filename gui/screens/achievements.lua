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
	ui.btn(top, -top_w / 2 + 66, 0, 112, 64, "", function() app.show("menu") end, { icon = "back", icon_size = 38 })
	ui.text(top, i18n.t("achievements"), 0, 2, 36, ui.WHITE)
	ui.icon(top, "trophy", top_w / 2 - 190, 2, 38, ui.STAR)
	ui.text(top, i18n.f("ach_unlocked", progress.achievement_count(), achievements.count()), top_w / 2 - 88, 2, 26, ui.WHITE)

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
		local icon_bg = ui.box(card, "circle", -card_w / 2 + 44, 0, 62, 62, done and ui.hex("#3FA86B") or ui.hex("#3A4157"))
		ui.icon(card, a.icon, -card_w / 2 + 44, 0, 34, done and ui.WHITE or ui.DIM)
		local tx = -card_w / 2 + 90
		ui.label(card, i18n.t("ach_" .. a.id), tx, card_h / 2 - 24, 23, done and ui.WHITE or ui.DIM,
			card_w - 108, 1, gui.PIVOT_W)
		ui.label(card, i18n.t("ach_" .. a.id .. "_d"), tx, -card_h / 2 + 34, 17, done and ui.hex("#C8E9D5") or ui.hex("#7C859C"),
			card_w - 108, 2, gui.PIVOT_W)
		if done then
			ui.icon(card, "check", card_w / 2 - 26, card_h / 2 - 26, 28, ui.GREEN)
		else
			ui.icon(card, "lock", card_w / 2 - 26, card_h / 2 - 26, 26, ui.DIM)
			ui.text(card, i18n.f("ach_reward", i18n.money(a.reward)), tx, -card_h / 2 + 20, 16, ui.YELLOW, gui.PIVOT_W)
		end
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
