-- Level select: chapter tabs + paginated grid of level cards with stars and locks.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local progress = require("game.core.progress")
local levels = require("game.levels.levels")
local layout = require("gui.layout")

local M = {}

local CH_COLORS = { ui.GREEN, ui.ORANGE, ui.BLUE, ui.PURPLE }
local PER_PAGE = 8

function M.build(app, root)
	local vw, vh = app.vw, app.vh
	local ml, mr, mt, mb = layout.margins(vw, vh, 20)
	local top_w = vw - ml - mr
	app.chapter = app.chapter or levels.get(progress.next_level()).chapter_index

	-- top bar
	local top = ui.panel(root, vw / 2, vh - mt - 52, top_w, 88, ui.PANEL, 22)
	ui.blocker(top)
	ui.btn(top, -top_w / 2 + 70, 0, 120, 68, "", function() app.show("menu") end, { icon = "back", icon_size = 40 })
	ui.text(top, i18n.t("levels"), 0, 2, 40, ui.WHITE)
	ui.icon(top, "star", top_w / 2 - 150, 2, 40, ui.STAR)
	ui.text(top, i18n.f("total_stars", progress.total_stars(), levels.MAX_STARS), top_w / 2 - 70, 2, 30, ui.WHITE)

	-- chapter tabs
	local n = #levels.chapters
	local tab_y = vh - mt - 150
	local tab_w = math.min(290, (top_w - (n - 1) * 12) / n)
	for ci, ch in ipairs(levels.chapters) do
		local x = vw / 2 + (ci - (n + 1) / 2) * (tab_w + 12)
		local unlocked = progress.chapter_unlocked(ci)
		local sel = ci == app.chapter
		local color = sel and CH_COLORS[ci] or (unlocked and ui.BTN_LIGHT or ui.PANEL)
		local text_color = sel and ui.WHITE or (unlocked and ui.INK or ui.DIM)
		local label = app.portrait and tostring(ci) or i18n.pick(ch.name)
		ui.btn(root, x, tab_y, tab_w, 76, label, function()
			app.chapter = ci
			app.level_page = 1
			for idx = ch.first, ch.last do
				if progress.level_unlocked(idx) and progress.stars(levels.get(idx).id) == 0 then
					app.level_page = math.floor((idx - ch.first) / PER_PAGE) + 1
					break
				end
			end
			app.rebuild()
		end, { color = color, text_color = text_color, icon = (not unlocked) and "lock" or nil, icon_size = 30, size = app.portrait and 34 or 26 })
	end

	-- chapter title
	local ch = levels.chapters[app.chapter]
	local title = i18n.f("chapter", app.chapter) .. "  " .. i18n.pick(ch.name)
	ui.label(root, title, vw / 2, tab_y - 65, 30, CH_COLORS[app.chapter], vw - 60)
	ui.text(root, string.format("%d / %d", progress.chapter_stars(ch), (ch.last - ch.first + 1) * 3), vw / 2, tab_y - 100, 24, ui.DIM)

	-- level pagination & grid
	local total_levels = ch.last - ch.first + 1
	local total_pages = math.max(1, math.ceil(total_levels / PER_PAGE))
	app.level_page = math.max(1, math.min(total_pages, app.level_page or 1))

	local start_k = (app.level_page - 1) * PER_PAGE
	local end_k = math.min(total_levels - 1, start_k + PER_PAGE - 1)

	local cols = app.portrait and 2 or 4
	local rows = app.portrait and 4 or 2
	local area_top, area_bottom = tab_y - 125, mb + 65
	local gap = 16
	local card_w = math.min(270, (top_w - (cols - 1) * gap) / cols)
	local card_h = math.min(170, (area_top - area_bottom - (rows - 1) * gap) / rows)
	local grid_h = rows * card_h + (rows - 1) * gap
	local y0 = area_top - (area_top - area_bottom - grid_h) / 2 - card_h / 2

	for k = start_k, end_k do
		local page_idx = k - start_k
		local col, row = page_idx % cols, math.floor(page_idx / cols)
		local x = vw / 2 + (col - (cols - 1) / 2) * (card_w + gap)
		local y = y0 - row * (card_h + gap)
		local i = ch.first + k
		local lvl = levels.get(i)
		local open = progress.level_unlocked(i)
		local stars = progress.stars(lvl.id)
		local card = ui.panel(root, x, y, card_w, card_h, open and ui.CARD or ui.hex("#232838"), 20)
		ui.text(card, lvl.id, 0, card_h / 2 - 30, 34, open and ui.WHITE or ui.DIM)
		ui.label(card, i18n.pick(lvl.name), 0, 4, 22, open and ui.DIM or ui.hex("#5B647C"), card_w - 20)
		if open then
			ui.stars(card, 0, -card_h / 2 + 32, 34, stars)
			ui.button(card, function() app.start_level(i) end)
			if i == progress.next_level() and stars == 0 then ui.pulse(card, 1.03, 0.6) end
		else
			ui.icon(card, "lock", 0, -card_h / 2 + 32, 36, ui.DIM)
			ui.button(card, nil, { disabled = true })
		end
	end

	-- Pagination controls
	if total_pages > 1 then
		local py = mb + 32
		if app.level_page > 1 then
			ui.btn(root, vw / 2 - 150, py, 72, 46, "<", function()
				app.level_page = app.level_page - 1
				app.rebuild()
			end, { color = ui.PANEL_LT, size = 30 })
		end
		ui.text(root, i18n.f("page_fmt", app.level_page, total_pages), vw / 2, py, 26, ui.WHITE)
		if app.level_page < total_pages then
			ui.btn(root, vw / 2 + 150, py, 72, 46, ">", function()
				app.level_page = app.level_page + 1
				app.rebuild()
			end, { color = ui.PANEL_LT, size = 30 })
		end
	end
end

return M
