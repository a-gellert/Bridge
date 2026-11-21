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
	ui.btn(top, -top_w / 2 + 70, 0, 120, app.touch and 74 or 68, "", function() app.show("menu") end, { icon = "back", icon_size = 40 })
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
		local color = sel and CH_COLORS[ci] or (unlocked and ui.PANEL_LT or ui.CARD)
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
		end, { color = color, icon = (not unlocked) and "lock" or nil, icon_size = 30, size = app.portrait and 34 or 26 })
	end

	-- chapter title
	local ch = levels.chapters[app.chapter]
	local title = i18n.f("chapter", app.chapter) .. "  " .. i18n.pick(ch.name)
	-- chapter header on its own pill so it reads over any sky / grass behind it
	local hw = math.min(620, top_w)
	local head = ui.panel(root, vw / 2, tab_y - 80, hw, 64, ui.PANEL, 24)
	ui.label(head, title, -36, 2, 28, CH_COLORS[app.chapter], hw - 190)
	ui.icon(head, "star", hw / 2 - 118, 2, 28, ui.STAR)
	ui.text(head, string.format("%d / %d", progress.chapter_stars(ch), (ch.last - ch.first + 1) * 3), hw / 2 - 58, 2, 24, ui.WHITE)

	-- level pagination & grid
	local total_levels = ch.last - ch.first + 1
	local total_pages = math.max(1, math.ceil(total_levels / PER_PAGE))
	app.level_page = math.max(1, math.min(total_pages, app.level_page or 1))

	local start_k = (app.level_page - 1) * PER_PAGE
	local end_k = math.min(total_levels - 1, start_k + PER_PAGE - 1)

	local cols = app.portrait and 2 or 4
	local rows = app.portrait and 4 or 2
	local area_top, area_bottom = tab_y - 126, mb + 80
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
		-- short cards (portrait tablets) pull the rows apart so id, name and stars never touch
		local short = card_h < 150
		ui.text(card, lvl.id, 0, card_h / 2 - (short and 24 or 30), short and 30 or 34, open and ui.WHITE or ui.hex("#8089A4"))
		ui.label(card, i18n.pick(lvl.name), 0, short and 8 or 4, 22, open and ui.DIM or ui.hex("#8089A4"), card_w - 20)
		if open then
			ui.stars(card, 0, -card_h / 2 + (short and 24 or 32), short and 28 or 34, stars)
			ui.button(card, function() app.start_level(i) end)
			if i == progress.next_level() and stars == 0 then ui.pulse(card, 1.03, 0.6) end
		else
			ui.icon(card, "lock", 0, -card_h / 2 + (short and 24 or 32), short and 34 or 42, ui.DIM)
			ui.button(card, nil, { disabled = true })
			-- Druid fades disabled buttons; a locked card stays solid so the world never shows through
			gui.set_color(card, ui.hex("#1E2334", 0.96))
		end
	end

	-- Pagination controls
	if total_pages > 1 then
		local py = mb + 34
		local pill = ui.panel(root, vw / 2, py, 220, 56, ui.PANEL, 24)
		ui.text(pill, i18n.f("page_fmt", app.level_page, total_pages), 0, 2, 24, ui.WHITE)
		-- both arrows are always there (dimmed at the ends) so the paging reads as symmetric
		for _, d in ipairs({ -1, 1 }) do
			local target = app.level_page + d
			local ok = target >= 1 and target <= total_pages
			local node = ui.btn(root, vw / 2 + d * 170, py, 96, app.touch and 72 or 64, "", function()
				app.level_page = target
				app.rebuild()
			end, { color = ok and ui.BLUE or ui.CARD, icon = d < 0 and "back" or "next", icon_size = 34,
				disabled = not ok, silent = not ok })
			-- Druid fades disabled buttons; keep the dimmed end arrow solid
			if not ok then gui.set_color(node, ui.hex("#2A3044", 0.9)) end
		end
	end
end

return M
