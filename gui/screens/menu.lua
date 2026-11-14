-- Main menu: title, PLAY (next level), LEVELS, stars counter, sound and language toggles.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local progress = require("game.core.progress")
local levels = require("game.levels.levels")
local audio = require("platform.audio")

local M = {}

function M.build(app, root)
	local vw, vh = app.vw, app.vh
	local cx = vw / 2
	require("world.camera").set_insets(0, 0)
	local title_y = app.portrait and vh * 0.72 or vh * 0.7

	-- title
	local t = ui.text(root, i18n.t("title"), cx, title_y, app.portrait and 96 or 110, ui.YELLOW)
	gui.set_outline(t, ui.INK)
	ui.pop(t)
	local sub = ui.text(root, i18n.t("subtitle"), cx, title_y - 74, 30, ui.WHITE)
	ui.fade_in(sub, 0.4, 0.2)

	-- play
	local nxt = progress.next_level()
	local lvl = levels.get(nxt)
	local bw = app.portrait and 440 or 420
	local play, _, _ = ui.btn(root, cx, title_y - 210, bw, 110, i18n.t("play") .. "  " .. lvl.id, function()
		app.start_level(nxt)
	end, { color = ui.GREEN, icon = "play", icon_size = 54, size = 44 })
	ui.pop(play, 0.1)
	ui.pulse(play, 1.04, 0.8)

	local lv = ui.btn(root, cx, title_y - 340, bw * 0.8, 88, i18n.t("levels"), function()
		app.show("levels")
	end, { color = ui.BLUE, icon = "menu", icon_size = 40, size = 34 })
	ui.pop(lv, 0.18)

	-- stars total
	local total = progress.total_stars()
	local pill = ui.panel(root, cx, title_y - 450, 260, 64, ui.PANEL, 30)
	ui.icon(pill, "star", -84, 2, 44, ui.STAR)
	ui.text(pill, i18n.f("total_stars", total, levels.MAX_STARS), 22, 2, 32, ui.WHITE)

	-- corner toggles
	local m = 20
	ui.round(root, vw - m - 40, vh - m - 40, 80, audio.is_enabled() and "sound_on" or "sound_off", function()
		local on = not audio.is_enabled()
		audio.set_enabled(on)
		progress.set_setting("sound", on)
		app.rebuild()
	end)
	local lang_btn = ui.btn(root, m + 60, vh - m - 40, 120, 80, i18n.lang == "ru" and "RU" or "EN", function()
		local lang = i18n.lang == "ru" and "en" or "ru"
		i18n.set_lang(lang)
		progress.set_setting("lang", lang)
		app.rebuild()
	end, { size = 34 })
end

return M
