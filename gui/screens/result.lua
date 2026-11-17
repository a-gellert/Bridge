-- Result popup over the drive view.
-- Win: stars for the level, seamless auto-advance if 3 stars, biome switch prompt on level 8.
-- Fail: instant return to build mode (0.1s delay, 0.2s camera return, saved blueprint preserved).
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local session = require("game.core.session")
local vehicles = require("game.config.vehicles")
local levels = require("game.levels.levels")
local audio = require("platform.audio")
local ads = require("platform.ads")

local M = {}

local V3 = vmath.vector3

local function budget_color(r)
	if r <= 0.7 then return ui.GREEN elseif r <= 0.92 then return ui.YELLOW end
	return ui.ORANGE
end

function M.build(app, root, res)
	local vw, vh = app.vw, app.vh

	if not res.won then
		if not res.can_assist then
			-- Fast edit after collapse: instantly return to build mode
			session.stop_drive()
			return
		end
		-- After 3 defeats: offer rewarded budget bonus without dark backdrop
		audio.play("fail", 0.7)
		local pw = math.min(app.portrait and 660 or 680, vw - 40)
		local ph = 480
		local panel = ui.panel(root, vw / 2, vh / 2, pw, ph, ui.hex("#262D40", 0.96), 28)
		ui.blocker(panel)
		ui.pop(panel)
		local top = ph / 2

		ui.text(panel, i18n.t("fail_title"), 0, top - 60, 60, ui.RED)
		ui.label(panel, i18n.t("reason_" .. tostring(res.reason)), 0, top - 130, 32, ui.WHITE, pw - 60)
		local def = vehicles.get(res.vehicle)
		ui.icon(panel, def.icon, 0, top - 190, 60, ui.DIM)

		ads.offer_visible("budget")
		local assist = ui.btn(panel, 0, -ph / 2 + 130, pw - 60, 84, i18n.t("assist_budget"), function()
			ads.rewarded("budget", function(ok)
				if ok and session.apply_budget_bonus() then
					app.toast_next = { text = i18n.t("budget_bonus"), color = ui.GREEN }
					session.stop_drive()
				elseif not ok then
					app.toast(i18n.t("reward_failed"), ui.RED)
				end
			end)
		end, { icon = "video", icon_size = 40, color = ui.PURPLE, size = 30 })
		ui.pulse(assist, 1.03, 0.7)

		local retry = ui.btn(panel, 0, -ph / 2 + 52, pw - 60, 72, i18n.t("retry"), function()
			session.stop_drive()
		end, { icon = "retry", icon_size = 36, color = ui.GREEN, size = 28 })
		return
	end

	-- ------------------------------------------------------------------ WIN
	audio.play("win", 0.8)

	local ch_index = res.chapter_index or (session.level and session.level.chapter_index) or 1
	local lvl_num = res.level_number or (session.level and session.level.number) or 1
	local is_biome_8 = res.is_biome_milestone or (lvl_num == 8)

	if is_biome_8 then
		-- Level 8 in biome passed: offer switching to a new setting
		local next_ci = (ch_index % #levels.chapters) + 1
		local target_ch = levels.chapters[next_ci]
		local target_name = target_ch and i18n.pick(target_ch.name) or ""

		local pw = math.min(app.portrait and 660 or 700, vw - 40)
		local ph = 560
		local panel = ui.panel(root, vw / 2, vh / 2, pw, ph, ui.hex("#262D40", 0.98), 28)
		ui.blocker(panel)
		ui.pop(panel)
		local top = ph / 2

		ui.text(panel, i18n.t("biome_offer_title"), 0, top - 52, 48, ui.YELLOW)
		local stars = ui.stars(panel, 0, top - 130, 80, res.prev_stars or 0, 96)
		for i = 1, 3 do
			if i > (res.prev_stars or 0) and i <= res.stars then
				local n = stars[i]
				local gen = app.gen
				timer.delay(0.25 + (i - (res.prev_stars or 0)) * 0.2, false, function()
					if app.gen ~= gen then return end
					ui.set_star(n, true)
					ui.pop(n)
					audio.play("star", 0.7, 0.9 + i * 0.1)
				end)
			end
		end

		ui.label(panel, i18n.f("biome_offer_desc", target_name), 0, top - 210, 28, ui.WHITE, pw - 60, 2)

		-- Button 1: Go to new setting
		local btn1_lbl = i18n.f("biome_offer_go", target_name)
		local btn1 = ui.btn(panel, 0, top - 310, pw - 80, 84, btn1_lbl, function()
			app.start_level(target_ch.first)
		end, { icon = "next", icon_size = 40, color = ui.GREEN, size = 28 })
		ui.pulse(btn1, 1.05, 0.6)

		-- Button 2: Continue in current setting (Level 9)
		local btn2_lbl = i18n.f("biome_offer_stay", string.format("%d-%d", ch_index, lvl_num + 1))
		ui.btn(panel, 0, top - 410, pw - 80, 76, btn2_lbl, function()
			app.next_level()
		end, { color = ui.PANEL_LT, size = 26 })

		-- Wrench / fix button in corner
		ui.btn(panel, -pw / 2 + 50, top - 46, 68, 60, "", function()
			session.stop_drive()
		end, { icon = "wrench", icon_size = 36, color = ui.ORANGE })
		return
	end

	-- Standard Win Card (no full-screen dim: seamless celebratory overlay)
	local pw = math.min(app.portrait and 660 or 680, vw - 40)
	local ph = 600
	local panel = ui.panel(root, vw / 2, vh / 2, pw, ph, ui.hex("#262D40", 0.96), 28)
	ui.blocker(panel)
	ui.pop(panel)
	local top = ph / 2

	local title = ui.text(panel, i18n.t("win_title"), 0, top - 52, 54, ui.YELLOW)
	local stars = ui.stars(panel, 0, top - 138, 88, res.prev_stars or 0, 106)
	for i = 1, 3 do
		if i > (res.prev_stars or 0) and i <= res.stars then
			local n = stars[i]
			local gen = app.gen
			timer.delay(0.25 + (i - (res.prev_stars or 0)) * 0.2, false, function()
				if app.gen ~= gen then return end
				ui.set_star(n, true)
				ui.pop(n)
				audio.play("star", 0.7, 0.9 + i * 0.1)
			end)
		end
	end

	local def = vehicles.get(res.vehicle)
	ui.icon(panel, def.icon, -pw / 2 + 70, top - 224, 52)
	ui.label(panel, i18n.f("delivered_by", i18n.t(def.name_key)), 20, top - 224, 26, ui.WHITE, pw - 160)

	-- budget block
	local bw = pw - 80
	ui.text(panel, i18n.t("budget_used"), -bw / 2, top - 280, 24, ui.DIM, gui.PIVOT_W)
	local pct = math.floor(res.ratio * 100 + 0.5)
	ui.text(panel, i18n.f("budget_pct", pct), bw / 2, top - 280, 24, budget_color(res.ratio), gui.PIVOT_E)
	local bar = ui.bar(panel, 0, top - 314, bw, 22, budget_color(res.ratio))
	ui.set_bar(bar, 0)
	local target = math.min(1, res.ratio)
	gui.set_size(bar.fill, V3(bar.h, bar.h, 0))
	gui.set_enabled(bar.fill, true)
	gui.animate(bar.fill, "size.x", math.max(bar.h, bar.w * target), gui.EASING_OUTCUBIC, 0.8, 0.2)
	ui.text(panel, i18n.f("spent_of", i18n.money(res.cost), i18n.money(res.budget)), 0, top - 350, 26, ui.WHITE)

	if res.new_record and not res.first_clear then
		local line = ui.text(panel, i18n.t("new_record"), 0, top - 382, 26, ui.GREEN)
		ui.pulse(line, 1.08, 0.5)
	elseif res.best_cost then
		ui.text(panel, i18n.f("best_cost", i18n.money(res.best_cost)), 0, top - 382, 22, ui.DIM)
	end

	local can_next = res.has_next and res.next_unlocked
	local is_3_stars = (res.stars == 3) or (res.vehicle_stars == 3)

	if is_3_stars and can_next then
		ui.label(panel, i18n.t("auto_next"), 0, top - 418, 24, ui.GREEN, pw - 60)
		-- Seamless automatic transition on 3 stars. Long enough to watch the stars and the budget
		-- land; a draining bar above the buttons shows when it happens (FIX / menu cancel it).
		local AUTO_NEXT = 2.8
		local cd = ui.bar(panel, 0, -ph / 2 + 110, pw - 60, 8, ui.GREEN)
		gui.set_size(cd.fill, V3(cd.w, cd.h, 0))
		gui.animate(cd.fill, "size.x", cd.h, gui.EASING_LINEAR, AUTO_NEXT)
		local gen = app.gen
		timer.delay(AUTO_NEXT, false, function()
			if app.gen ~= gen then return end
			if session.state == "result" and res.won then
				app.next_level()
			end
		end)
	else
		ui.label(panel, res.stars < 3 and i18n.t("try_heavier") or i18n.t("all_stars"), 0, top - 418, 22,
			res.stars < 3 and ui.YELLOW or ui.GREEN, pw - 60)
	end

	if (res.salary or 0) > 0 then
		ui.text(panel, i18n.t("salary"), -bw / 2, top - 452, 22, ui.DIM, gui.PIVOT_W)
		ui.text(panel, i18n.f("salary_gain", i18n.money(res.salary)), bw / 2, top - 452, 24, ui.GREEN, gui.PIVOT_E)
	end

	-- buttons
	local by = -ph / 2 + 56
	local w3 = (pw - 60) / 3
	ui.btn(panel, -w3 - 10, by, w3, 80, "", function() session.stop_drive() end, { icon = "wrench", icon_size = 42, color = ui.ORANGE })
	ui.btn(panel, 0, by, w3, 80, "", function() app.show("levels") end, { icon = "menu", icon_size = 42 })
	local nb = ui.btn(panel, w3 + 10, by, w3, 80, i18n.t("next"), function() app.next_level() end,
		{ icon = "next", icon_size = 38, color = ui.GREEN, size = 28, disabled = not can_next })
	if can_next then ui.pulse(nb, 1.05, 0.6) end
end

function M.on_key(app, action_id, action, res)
	if not action.pressed then return false end
	local name = app.key_names[action_id]
	if name == "go" then
		if res.won and res.has_next and res.next_unlocked then app.next_level() else session.stop_drive() end
		return true
	elseif name == "reset" or name == "back" then
		session.stop_drive()
		return true
	end
	return false
end

return M
