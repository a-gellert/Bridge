-- Level select: chapter tabs + a grid of level cards with stars and locks.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local progress = require("game.core.progress")
local levels = require("game.levels.levels")

local M = {}

local CH_COLORS = { ui.GREEN, ui.ORANGE, ui.BLUE, ui.PURPLE }

function M.build(app, root)
	local vw, vh = app.vw, app.vh
	local m = 20
	app.chapter = app.chapter or levels.get(progress.next_level()).chapter_index

	-- top bar
	local top = ui.panel(root, vw / 2, vh - 52, vw - 2 * m, 88, ui.PANEL, 22)
	ui.blocker(top)
	ui.btn(top, -(vw - 2 * m) / 2 + 70, 0, 120, 68, "", function() app.show("menu") end, { icon = "back", icon_size = 40 })
	ui.text(top, i18n.t("levels"), 0, 2, 40, ui.WHITE)
	ui.icon(top, "star", (vw - 2 * m) / 2 - 150, 2, 40, ui.STAR)
	ui.text(top, i18n.f("total_stars", progress.total_stars(), levels.MAX_STARS), (vw - 2 * m) / 2 - 70, 2, 30, ui.WHITE)

	-- chapter tabs
	local n = #levels.chapters
	local tab_y = vh - 150
	local tab_w = math.min(290, (vw - 2 * m - (n - 1) * 12) / n)
	for ci, ch in ipairs(levels.chapters) do
		local x = vw / 2 + (ci - (n + 1) / 2) * (tab_w + 12)
		local unlocked = progress.chapter_unlocked(ci)
		local sel = ci == app.chapter
		local color = sel and CH_COLORS[ci] or (unlocked and ui.PANEL_LT or ui.CARD)
		local label = app.portrait and tostring(ci) or i18n.pick(ch.name)
		local node = ui.btn(root, x, tab_y, tab_w, 76, label, function()
			app.chapter = ci
			app.rebuild()
		end, { color = color, icon = (not unlocked) and "lock" or nil, icon_size = 30, size = app.portrait and 34 or 26 })
	end

	-- chapter title (portrait shows the name here)
	local ch = levels.chapters[app.chapter]
	local unlocked = progress.chapter_unlocked(app.chapter)
	local title = i18n.f("chapter", app.chapter) .. "  " .. i18n.pick(ch.name)
	ui.label(root, title, vw / 2, tab_y - 70, 32, CH_COLORS[app.chapter], vw - 60)
	ui.text(root, string.format("%d / %d", progress.chapter_stars(ch), (ch.last - ch.first + 1) * 3), vw / 2, tab_y - 110, 26, ui.DIM)

	-- level grid
	local cols = app.portrait and 2 or 3
	local rows = math.ceil((ch.last - ch.first + 1) / cols)
	local area_top, area_bottom = tab_y - 140, 30
	local gap = 18
	local card_w = math.min(330, (vw - 2 * m - (cols - 1) * gap) / cols)
	local card_h = math.min(200, (area_top - area_bottom - (rows - 1) * gap) / rows)
	local grid_h = rows * card_h + (rows - 1) * gap
	local y0 = area_top - (area_top - area_bottom - grid_h) / 2 - card_h / 2
	for i = ch.first, ch.last do
		local k = i - ch.first
		local col, row = k % cols, math.floor(k / cols)
		local x = vw / 2 + (col - (cols - 1) / 2) * (card_w + gap)
		local y = y0 - row * (card_h + gap)
		local lvl = levels.get(i)
		local open = progress.level_unlocked(i)
		local stars = progress.stars(lvl.id)
		local card = ui.panel(root, x, y, card_w, card_h, open and ui.CARD or ui.hex("#232838"), 22)
		ui.text(card, lvl.id, 0, card_h / 2 - 34, 40, open and ui.WHITE or ui.DIM)
		ui.label(card, i18n.pick(lvl.name), 0, 0, 26, open and ui.DIM or ui.hex("#5B647C"), card_w - 24)
		if open then
			ui.stars(card, 0, -card_h / 2 + 40, 40, stars)
			ui.button(card, function() app.start_level(i) end)
			if i == progress.next_level() and stars == 0 then ui.pulse(card, 1.03, 0.6) end
		else
			ui.icon(card, "lock", 0, -card_h / 2 + 40, 44, ui.DIM)
			ui.button(card, nil, { disabled = true })
		end
	end
	if not unlocked then
		local prev_done = app.chapter == 1 or (function()
			local p = levels.chapters[app.chapter - 1]
			for i = p.first, p.last do
				if progress.stars(levels.get(i).id) == 0 then return false end
			end
			return true
		end)()
		local msg = prev_done and i18n.f("need_stars", ch.stars_required) or i18n.t("finish_prev")
		local banner = ui.panel(root, vw / 2, (area_top + area_bottom) / 2, math.min(560, vw - 60), 110, ui.hex("#151926", 0.95), 24)
		ui.icon(banner, "lock", -math.min(560, vw - 60) / 2 + 60, 0, 56, ui.YELLOW)
		ui.label(banner, msg, 30, 0, 32, ui.WHITE, math.min(560, vw - 60) - 150)
	end
end

return M
