-- Result popup over the drive view.
-- Win: stars for the level (best vehicle so far), which vehicle made it, how much of the budget was used.
-- Fail: the reason and a one-tap way back to the bridge.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local session = require("game.core.session")
local vehicles = require("game.config.vehicles")
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
	local dim = ui.box(root, "white", vw / 2, vh / 2, vw, vh, ui.hex("#0B0E16", 0.55))
	ui.blocker(dim)
	ui.fade_in(dim, 0.25)

	local pw = math.min(app.portrait and 660 or 680, vw - 40)
	local ph = res.won and 640 or (res.can_assist and 520 or 400)
	local panel = ui.panel(root, vw / 2, vh / 2, pw, ph, ui.hex("#262D40", 0.98), 28)
	ui.blocker(panel)
	ui.pop(panel)
	local top = ph / 2

	if res.won then
		audio.play("win", 0.8)
		local title = ui.text(panel, i18n.t("win_title"), 0, top - 56, 56, ui.YELLOW)
		-- stars: earned before stay lit, new ones pop in one by one
		local stars = ui.stars(panel, 0, top - 150, 92, res.prev_stars or 0, 110)
		for i = 1, 3 do
			if i > (res.prev_stars or 0) and i <= res.stars then
				local n = stars[i]
				local gen = app.gen
				timer.delay(0.35 + (i - (res.prev_stars or 0)) * 0.3, false, function()
					if app.gen ~= gen then return end -- popup was rebuilt or closed
					ui.set_star(n, true)
					ui.pop(n)
					audio.play("star", 0.7, 0.9 + i * 0.1)
				end)
			end
		end
		local def = vehicles.get(res.vehicle)
		ui.icon(panel, def.icon, -pw / 2 + 70, top - 238, 56)
		ui.label(panel, i18n.f("delivered_by", i18n.t(def.name_key)), 20, top - 238, 28, ui.WHITE, pw - 160)

		-- budget block
		local bw = pw - 80
		ui.text(panel, i18n.t("budget_used"), -bw / 2, top - 300, 26, ui.DIM, gui.PIVOT_W)
		local pct = math.floor(res.ratio * 100 + 0.5)
		ui.text(panel, i18n.f("budget_pct", pct), bw / 2, top - 300, 26, budget_color(res.ratio), gui.PIVOT_E)
		local bar = ui.bar(panel, 0, top - 338, bw, 24, budget_color(res.ratio))
		ui.set_bar(bar, 0)
		-- animated fill
		local target = math.min(1, res.ratio)
		gui.set_size(bar.fill, V3(bar.h, bar.h, 0))
		gui.set_enabled(bar.fill, true)
		gui.animate(bar.fill, "size.x", math.max(bar.h, bar.w * target), gui.EASING_OUTCUBIC, 0.9, 0.3)
		ui.text(panel, i18n.f("spent_of", i18n.money(res.cost), i18n.money(res.budget)), 0, top - 376, 26, ui.WHITE)
		local line
		if res.new_record and not res.first_clear then
			line = ui.text(panel, i18n.t("new_record"), 0, top - 410, 28, ui.GREEN)
			ui.pulse(line, 1.08, 0.5)
		elseif res.best_cost then
			ui.text(panel, i18n.f("best_cost", i18n.money(res.best_cost)), 0, top - 410, 24, ui.DIM)
		end
		ui.label(panel, res.stars < 3 and i18n.t("try_heavier") or i18n.t("all_stars"), 0, top - 446, 22, res.stars < 3 and ui.YELLOW or ui.GREEN, pw - 60)
		-- leftover budget becomes garage money
		if (res.salary or 0) > 0 then
			ui.text(panel, i18n.t("salary"), -bw / 2, top - 480, 24, ui.DIM, gui.PIVOT_W)
			ui.text(panel, i18n.f("salary_gain", i18n.money(res.salary)), bw / 2, top - 480, 26, ui.GREEN, gui.PIVOT_E)
		end
		ui.text(panel, i18n.f("salary_line", "$" .. i18n.money(res.wallet or 0)), 0, top - 514, 22, ui.DIM)

		-- buttons
		local by = -ph / 2 + 58
		local w3 = (pw - 60) / 3
		ui.btn(panel, -w3 - 10, by, w3, 84, "", function() session.stop_drive() end, { icon = "wrench", icon_size = 44, color = ui.ORANGE })
		ui.btn(panel, 0, by, w3, 84, "", function() app.show("levels") end, { icon = "menu", icon_size = 44 })
		local can_next = res.has_next and res.next_unlocked
		local nb = ui.btn(panel, w3 + 10, by, w3, 84, i18n.t("next"), function() app.next_level() end,
			{ icon = "next", icon_size = 40, color = ui.GREEN, size = 30, disabled = not can_next })
		if can_next then ui.pulse(nb, 1.05, 0.6) end
	else
		audio.play("fail", 0.7)
		ui.text(panel, i18n.t("fail_title"), 0, top - 60, 60, ui.RED)
		ui.label(panel, i18n.t("reason_" .. tostring(res.reason)), 0, top - 140, 34, ui.WHITE, pw - 60)
		local def = vehicles.get(res.vehicle)
		ui.icon(panel, def.icon, 0, top - 206, 66, ui.DIM)
		local by = -ph / 2 + (res.can_assist and 168 or 64)
		local bw = math.min(380, pw - 80)
		local retry = ui.btn(panel, 0, by, bw, 88, i18n.t("retry"), function() session.stop_drive() end,
			{ icon = "retry", icon_size = 42, color = ui.GREEN, size = 32 })
		ui.pulse(retry, 1.05, 0.6)
		if res.can_assist then
			-- Dynamic assist: after 3 defeats a rewarded offer adds +25% budget.
			ads.offer_visible("budget")
			local assist = ui.btn(panel, 0, -ph / 2 + 62, pw - 50, 88, i18n.t("assist_budget"), function()
				ads.rewarded("budget", function(ok)
					if ok and session.apply_budget_bonus() then
						app.toast_next = { text = i18n.t("budget_bonus"), color = ui.GREEN }
						session.stop_drive()
					elseif not ok then
						app.toast(i18n.t("reward_failed"), ui.RED)
					end
				end)
			end, { icon = "video", icon_size = 42, color = ui.PURPLE, size = 30 })
			ui.pulse(assist, 1.03, 0.7)
		end
	end
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
