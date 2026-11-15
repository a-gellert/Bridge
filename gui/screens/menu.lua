-- Main menu: title, PLAY (next level), LEVELS / GARAGE / AWARDS, wallet, sound, haptics, language.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local progress = require("game.core.progress")
local levels = require("game.levels.levels")
local layout = require("gui.layout")
local audio = require("platform.audio")
local boot = require("platform.boot")
local haptics = require("platform.haptics")

local M = {}

function M.build(app, root)
	local vw, vh = app.vw, app.vh
	local cx = vw / 2
	require("world.camera").set_insets(0, 0)
	local ml, mr, mt = layout.margins(vw, vh, 16)

	-- title
	local title_y = vh * (app.portrait and 0.75 or 0.79)
	local t = ui.text(root, i18n.t("title"), cx, title_y, app.portrait and 96 or 104, ui.YELLOW)
	gui.set_outline(t, ui.INK)
	ui.pop(t)
	local sub = ui.text(root, i18n.t("subtitle"), cx, title_y - (app.portrait and 74 or 66), app.portrait and 28 or 26, ui.WHITE)
	ui.fade_in(sub, 0.4, 0.2)

	-- play
	local nxt = progress.next_level()
	local lvl = levels.get(nxt)
	local bw = math.min(app.portrait and 520 or 440, vw - 2 * ml - 40)
	local play, _, _ = ui.btn(root, cx, title_y - (app.portrait and 210 or 178), bw, app.portrait and 116 or 104,
		i18n.t("play") .. "  " .. lvl.id, function()
			app.start_level(nxt)
		end, { color = ui.GREEN, icon = "play", icon_size = 50, size = 42 })
	ui.pop(play, 0.1)
	ui.pulse(play, 1.04, 0.8)

	-- three secondary buttons: levels / garage / awards
	local gap = 12
	local bgap = 20
	local row_w = math.min(app.portrait and 560 or 800, vw - 2 * ml)
	local bw3 = (row_w - 2 * bgap) / 3
	local row_y = title_y - (app.portrait and 350 or 292)
	local function side(index)
		return cx - row_w / 2 + bw3 / 2 + index * (bw3 + bgap)
	end
	ui.pop(ui.btn(root, side(0), row_y, bw3, app.portrait and 92 or 84, i18n.t("levels"), function()
		app.show("levels")
	end, { color = ui.BLUE, icon = "menu", icon_size = 34, size = app.portrait and 30 or 27 }), 0.16)
	ui.pop(ui.btn(root, side(1), row_y, bw3, app.portrait and 92 or 84, i18n.t("garage"), function()
		app.show("garage")
	end, { color = ui.PURPLE, icon = "garage", icon_size = 36, size = app.portrait and 30 or 27 }), 0.22)
	ui.pop(ui.btn(root, side(2), row_y, bw3, app.portrait and 92 or 84, i18n.t("achievements"), function()
		app.show("achievements")
	end, { color = ui.ORANGE, icon = "trophy", icon_size = 36, size = app.portrait and 28 or 25 }), 0.28)

	-- stars + wallet
	local info_y = row_y - (app.portrait and 122 or 108)
	local pill_w = math.min(300, (vw - 2 * ml - gap) / 2)
	local pill_h = app.portrait and 74 or 64
	local stars_pill = ui.panel(root, cx - pill_w / 2 - gap / 2, info_y, pill_w, pill_h, ui.PANEL, 30)
	ui.icon(stars_pill, "star", -pill_w / 2 + 38, 2, 42, ui.STAR)
	ui.text(stars_pill, i18n.f("total_stars", progress.total_stars(), levels.MAX_STARS), 20, 2, 30, ui.WHITE)
	local money_pill = ui.panel(root, cx + pill_w / 2 + gap / 2, info_y, pill_w, pill_h, ui.PANEL, 30)
	ui.icon(money_pill, "coin", -pill_w / 2 + 38, 2, 40, ui.STAR)
	ui.text(money_pill, "$" .. i18n.money(progress.wallet()), 20, 2, 30, ui.WHITE)

	-- corner toggles (inside the safe area)
	local m = 20
	local top_y = vh - mt - m - 40
	ui.round(root, vw - mr - m - 40, top_y, 80, audio.is_enabled() and "sound_on" or "sound_off", function()
		local on = not audio.is_enabled()
		audio.set_enabled(on)
		progress.set_setting("sound", on)
		app.rebuild()
	end)
	if boot.haptics_supported() then
		local on = haptics.is_enabled()
		ui.round(root, vw - mr - m - 140, top_y, 80, on and "vibrate_on" or "vibrate_off", function()
			local nv = not haptics.is_enabled()
			haptics.set_enabled(nv)
			progress.set_setting("haptics", nv)
			if nv then haptics.click() end
			app.rebuild()
		end)
	end
	ui.btn(root, ml + m + 60, top_y, 120, 80, i18n.lang == "ru" and "RU" or "EN", function()
		local lang = i18n.lang == "ru" and "en" or "ru"
		i18n.set_lang(lang)
		progress.set_setting("lang", lang)
		app.rebuild()
	end, { size = 34 })
end

function M.on_key(app, action_id, action)
	if not action.pressed then return false end
	local name = app.key_names[action_id]
	if name == "back" then
		if app.exit_layer then
			ui.delete(app.exit_layer)
			app.exit_layer = nil
		else
			app.confirm_exit()
		end
		return true
	end
	return false
end

return M
