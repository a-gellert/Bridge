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

local lang_layer

local function close_language()
	if lang_layer then
		ui.delete(lang_layer)
		lang_layer = nil
	end
end

-- Called by app.rebuild() before the GUI root is recreated.
function M.clear()
	lang_layer = nil
end

-- Language picker: all supported Poki locales, in native spelling, two columns.
local function open_language(app)
	if lang_layer then return end
	local vw, vh = app.vw, app.vh
	local dim = ui.box(app.root, "white", vw / 2, vh / 2, vw, vh, ui.hex("#0B0E16", 0.7))
	ui.blocker(dim)
	local pw = math.min(720, vw - 36)
	local cols, gap = 2, 10
	local rows = math.ceil(#i18n.languages / cols)
	local bh = app.portrait and 72 or 64
	local header, footer = 84, 84
	local ph = header + rows * bh + (rows - 1) * gap + footer
	local panel = ui.panel(dim, 0, 0, pw, ph, ui.PANEL, 28)
	ui.blocker(panel)
	ui.text(panel, i18n.t("language"), 0, ph / 2 - 44, app.portrait and 34 or 32, ui.YELLOW)
	local bw = (pw - 50) / cols
	local top = ph / 2 - header - bh / 2
	for idx, code in ipairs(i18n.languages) do
		local col = (idx - 1) % cols
		local row = math.floor((idx - 1) / cols)
		local x = -bw / 2 - gap / 2 + col * (bw + gap)
		local y = top - row * (bh + gap)
		ui.btn(panel, x, y, bw, bh, i18n.native[code] or code, function()
			i18n.set_lang(code)
			progress.set_setting("lang", code)
			close_language()
			app.rebuild()
		end, { color = code == i18n.lang and ui.GREEN or ui.PANEL_LT, size = app.portrait and 25 or 23 })
	end
	ui.btn(panel, 0, -ph / 2 + 44, 220, 62, i18n.t("close"), close_language, { size = 24 })
	lang_layer = dim
	ui.fade_in(dim, 0.18)
end

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
	local sub = ui.text(root, i18n.t("subtitle"), cx, title_y - (app.portrait and 74 or 66), app.portrait and 32 or 30, ui.WHITE)
	ui.fade_in(sub, 0.4, 0.2)

	-- play
	local nxt = progress.next_level()
	local lvl = levels.get(nxt)
	local bw = math.min(app.portrait and 664 or 440, vw - 2 * ml - 24)
	local play, _, _ = ui.btn(root, cx, title_y - (app.portrait and 210 or 178), bw, app.portrait and 116 or 104,
		i18n.t("play") .. "  " .. lvl.id, function()
			app.start_level(nxt)
		end, { color = ui.GREEN, icon = "play", icon_size = 50, size = 42 })
	ui.pop(play, 0.1)
	ui.pulse(play, 1.04, 0.8)

	-- three secondary buttons: levels / garage / awards
	local gap = 12
	local bgap = app.portrait and 12 or 20
	local row_w = math.min(800, vw - 2 * ml - 24)
	local bw3 = (row_w - 2 * bgap) / 3
	local row_y = title_y - (app.portrait and 350 or 292)
	local function side(index)
		return cx - row_w / 2 + bw3 / 2 + index * (bw3 + bgap)
	end
	ui.pop(ui.btn(root, side(0), row_y, bw3, app.portrait and 92 or 84, i18n.t("levels"), function()
		app.show("levels")
	end, { color = ui.BLUE, icon = "menu", icon_size = 34, size = app.portrait and 28 or 25 }), 0.16)
	ui.pop(ui.btn(root, side(1), row_y, bw3, app.portrait and 92 or 84, i18n.t("garage"), function()
		app.show("garage")
	end, { color = ui.PURPLE, icon = "garage", icon_size = 36, size = app.portrait and 28 or 25 }), 0.22)
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
	ui.btn(root, ml + m + 60, top_y, 120, 80, (i18n.lang or "en"):upper(), function()
		open_language(app)
	end, { size = 30 })
end

function M.on_key(app, action_id, action)
	if not action.pressed then return false end
	local name = app.key_names[action_id]
	if name == "back" then
		if lang_layer then
			close_language()
			return true
		end
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
