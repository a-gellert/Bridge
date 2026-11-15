-- Garage: spend leftover budget dollars on chassis paint, wheels and roof toppers.
-- Nothing here touches physics; skins only tint/attach visuals.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local progress = require("game.core.progress")
local skins = require("game.config.skins")
local vehicles = require("game.config.vehicles")
local achievements = require("game.core.achievements")
local layout = require("gui.layout")
local ads = require("platform.ads")
local poki = require("platform.poki")
local events = require("game.core.events")
local audio = require("platform.audio")
local haptics = require("platform.haptics")

local M = {}

local KIND_ICON = { body = "circle", wheel = "ring", topper = "star" }

local function announce(list)
	for _, a in ipairs(list or {}) do
		events.emit("achievement", { id = a.id, icon = a.icon })
	end
end

local function tint_of(item)
	local t = item.tint or { 1, 1, 1 }
	return ui.hex(string.format("#%02X%02X%02X",
		math.floor(math.max(0, math.min(1, t[1])) * 255 + 0.5),
		math.floor(math.max(0, math.min(1, t[2])) * 255 + 0.5),
		math.floor(math.max(0, math.min(1, t[3])) * 255 + 0.5)), 1)
end

local function owned(item)
	return progress.skin_owned(item.key)
end

local function selected(vehicle, kind, item)
	return progress.skin_for(kind, vehicle) == item.id
end

local function apply(app, kind, vehicle, item)
	progress.select_skin(kind, vehicle, item.id)
	audio.play("click", 0.6)
	haptics.click()
	poki.measure("cosmetic", item.key, "select")
	app.toast_next = { text = i18n.f("skin_equipped", i18n.pick(item.name)), color = ui.GREEN }
	app.rebuild()
end

local function unlock(app, kind, vehicle, item)
	if owned(item) then
		apply(app, kind, vehicle, item)
		return
	end
	local u = skins.unlock(item)
	if u.kind == "stars" then
		if progress.total_stars() >= u.value and (not item.chapter or progress.any_chapter_full()) then
			progress.grant_skin(item.key)
		else
			app.toast(i18n.f("need_stars", u.value), ui.YELLOW)
			return
		end
	elseif u.kind == "rewarded" then
		ads.offer_visible("garage_" .. item.key)
		ads.rewarded("garage_" .. item.key, function(ok)
			if ok then
				progress.grant_skin(item.key)
				announce(achievements.check_meta())
				progress.select_skin(kind, vehicle, item.id)
				app.toast_next = { text = i18n.f("skin_bought", i18n.pick(item.name)), color = ui.YELLOW }
				audio.play("purchase", 0.8)
				haptics.purchase()
				app.rebuild()
			else
				app.toast(i18n.t("reward_failed"), ui.RED)
			end
		end)
		return
	elseif u.kind == "price" then
		local ok, why = progress.buy_skin(item.key, u.value)
		if not ok and why == "money" then
			app.toast(i18n.t("not_enough_money"), ui.RED)
			return
		end
	else
		progress.grant_skin(item.key)
	end
	poki.measure("cosmetic", item.key, "unlock")
	announce(achievements.check_meta())
	progress.select_skin(kind, vehicle, item.id)
	audio.play("purchase", 0.8)
	haptics.purchase()
	app.toast_next = { text = i18n.f("skin_bought", i18n.pick(item.name)), color = ui.YELLOW }
	app.rebuild()
end

local function card(app, root, x, y, w, h, kind, vehicle, item)
	local is_owned = owned(item)
	local is_sel = selected(vehicle, kind, item)
	local unlocked = is_owned or is_sel
	local panel = ui.panel(root, x, y, w, h, is_sel and ui.hex("#2C4B39") or (is_owned and ui.CARD or ui.hex("#232838")), 20)
	-- colour swatch / generic icon
	local sw = math.min(w - 30, h * 0.4, 84)
	local icon_y = h / 2 - sw / 2 - 10
	local icon = ui.box(panel, "circle", 0, icon_y, sw, sw,
		(kind == "topper" and not item.visual) and ui.hex("#4A536D") or tint_of(item))
	if kind == "topper" and item.visual then
		ui.icon(panel, KIND_ICON[kind], 0, icon_y, sw * 0.62, ui.WHITE)
	end
	ui.label(panel, i18n.pick(item.name), 0, -h / 2 + 36, 21, unlocked and ui.WHITE or ui.DIM, w - 14)
	local u = skins.unlock(item)
	local tag
	if is_sel then
		tag = i18n.t("selected")
	elseif is_owned then
		tag = i18n.t("equip")
	elseif u.kind == "price" then
		tag = i18n.f("unlock_price", i18n.money(u.value))
	elseif u.kind == "stars" then
		tag = item.chapter and i18n.t("unlock_chapter") or i18n.f("unlock_stars", u.value)
	elseif u.kind == "rewarded" then
		tag = i18n.t("unlock_rewarded")
	end
	if tag then
		ui.text(panel, tag, 0, -h / 2 + 20, 17,
			is_sel and ui.GREEN or (is_owned and ui.BLUE or (u.kind == "rewarded" and ui.PURPLE or ui.YELLOW)))
	end
	if u.kind == "rewarded" and not is_owned then
		ui.icon(panel, "video", w / 2 - 20, h / 2 - 18, 24, ui.PURPLE)
	end
	if is_sel then
		ui.icon(panel, "check", w / 2 - 20, h / 2 - 18, 26, ui.GREEN)
	end
	ui.button(panel, function() unlock(app, kind, vehicle, item) end)
end

function M.build(app, root)
	local vw, vh = app.vw, app.vh
	local ml, mr, mt, mb = layout.margins(vw, vh, 16)
	local top_w = vw - ml - mr
	local top_h = 84

	local kind = app.garage_kind or "body"
	local vehicle = app.garage_vehicle or "truck"
	app.garage_kind, app.garage_vehicle = kind, vehicle

	-- top bar
	local top = ui.panel(root, vw / 2, vh - mt - top_h / 2, top_w, top_h, ui.PANEL, 22)
	ui.blocker(top)
	ui.btn(top, -top_w / 2 + 66, 0, 112, 64, "", function() app.show("menu") end, { icon = "back", icon_size = 38 })
	ui.text(top, i18n.t("garage"), 0, 2, 38, ui.WHITE)
	local wallet = ui.panel(top, top_w / 2 - 130, 0, 230, 60, ui.hex("#151926", 0.8), 26)
	ui.icon(wallet, "coin", -84, 2, 38, ui.STAR)
	ui.text(wallet, "$" .. i18n.money(progress.wallet()), 20, 2, 28, ui.WHITE)

	-- vehicle tabs
	local vgap = 10
	local vw3 = math.min(220, (top_w - 2 * vgap) / 3)
	local vy = vh - mt - top_h - 50
	for i, v in ipairs(vehicles.list) do
		local x = vw / 2 + (i - 2) * (vw3 + vgap)
		local sel = v.id == vehicle
		local node = ui.btn(root, x, vy, vw3, 72, i18n.t(v.name_key), function()
			app.garage_vehicle = v.id
			app.rebuild()
		end, { icon = v.icon, icon_size = 34, color = sel and ui.BLUE or ui.PANEL_LT, size = 22 })
		ui.pop(node, 0.02 * i)
	end

	-- cosmetic category tabs
	local kgap = 10
	local kw = math.min(250, (top_w - 2 * kgap) / 3)
	local ky = vy - 72
	for i, k in ipairs(skins.kinds) do
		local x = vw / 2 + (i - 2) * (kw + kgap)
		local sel = k == kind
		ui.btn(root, x, ky, kw, 64, i18n.t("kind_" .. k), function()
			app.garage_kind = k
			app.rebuild()
		end, { icon = KIND_ICON[k], icon_size = 28, color = sel and ui.PURPLE or ui.PANEL_LT, size = 22 })
	end

	-- item grid
	local list = skins.list_of(kind)
	local cols = app.portrait and 3 or 5
	local rows = math.ceil(#list / cols)
	local gap = 12
	local area_top = ky - 44
	local area_bottom = mb + 16
	local card_w = math.min(260, (top_w - (cols - 1) * gap) / cols)
	local card_h = math.min(app.portrait and 220 or 200, (area_top - area_bottom - (rows - 1) * gap) / rows)
	local grid_h = rows * card_h + (rows - 1) * gap
	local y0 = area_top - math.max(0, (area_top - area_bottom - grid_h) / 2) - card_h / 2
	for i, item in ipairs(list) do
		local k = i - 1
		local col, row = k % cols, math.floor(k / cols)
		local x = vw / 2 + (col - (cols - 1) / 2) * (card_w + gap)
		local y = y0 - row * (card_h + gap)
		card(app, root, x, y, card_w, card_h, kind, vehicle, item)
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
