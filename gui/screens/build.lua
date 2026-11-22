-- Build HUD. Landscape (wide): one bottom bar with materials on the left, vehicles + GO on the right.
-- Portrait / narrow: two bottom rows (materials, then vehicles + GO) and a two-row top bar.
local ui = require("gui.ui")
local i18n = require("game.core.i18n")
local session = require("game.core.session")
local materials = require("game.config.materials")
local vehicles = require("game.config.vehicles")
local progress = require("game.core.progress")
local Blueprint = require("game.bridge.blueprint")
local camera = require("world.camera")
local layout = require("gui.layout")
local ads = require("platform.ads")
local haptics = require("platform.haptics")
local audio = require("platform.audio")

local M = {}

local V3 = vmath.vector3
local h = {} -- node handles of the current build

local function budget_color(r)
	if r < 0.7 then return ui.GREEN elseif r < 0.92 then return ui.YELLOW end
	return ui.RED
end

function M.refresh(app)
	if not h.root then return end
	local bp = session.blueprint
	if not bp then return end
	local cost, budget = bp:cost(), bp.budget
	ui.set_label(h.budget_txt, h.budget_comp, "$" .. i18n.money(cost) .. " / $" .. i18n.money(budget))
	ui.set_bar(h.budget_bar, cost / budget, budget_color(cost / budget))
	for id, b in pairs(h.mats) do
		local sel = session.tool == "build" and session.material == id
		gui.set_color(b.node, sel and ui.YELLOW or ui.PANEL_LT)
		-- dark text on the yellow selected tile (white on yellow is unreadable)
		gui.set_color(b.price, sel and ui.INK or ui.WHITE)
		gui.set_outline(b.price, sel and ui.CLEAR or ui.INK)
		gui.set_color(b.len, sel and ui.hex("#5A4A12") or ui.DIM)
		gui.set_outline(b.len, sel and ui.CLEAR or ui.INK)
	end
	if h.erase then gui.set_color(h.erase, session.tool == "erase" and ui.RED or ui.PANEL_LT) end
	for id, node in pairs(h.vehs) do
		gui.set_color(node, session.vehicle == id and ui.BLUE or ui.PANEL_LT)
	end
	if h.undo_btn then h.undo_btn:set_enabled(bp:can_undo()) end
	if h.clear_node then
		local n = bp:beam_count()
		-- an armed clear only applies to the bridge it was armed on
		if h.clear_armed and n ~= h.clear_count then h.clear_armed = nil end
		local c = h.clear_armed and ui.RED or ui.PANEL_LT
		gui.set_color(h.clear_node, vmath.vector4(c.x, c.y, c.z, n == 0 and 0.45 or 1))
	end
end

local function toggle_erase(app)
	session.set_tool(session.tool == "erase" and "build" or "erase")
	M.refresh(app)
end

local function launch(app)
	-- Level 1 teaches by consequence. Elsewhere the empty-build nudge waits for a real fall.
	local learned = progress.stats().losses > 0
	if session.blueprint:beam_count() == 0 and session.index ~= 1 and learned then
		app.toast(i18n.t("tip_build_" .. (app.touch and "touch" or "pc")), ui.YELLOW)
	end
	session.start_drive(session.vehicle)
end

-- material button
local function mat_button(app, parent, x, y, w, bh, m)
	local node = ui.box(parent, "btn", x, y, w, bh, ui.PANEL_LT)
	gui.set_slice9(node, vmath.vector4(16, 16, 16, 24))
	ui.icon(node, m.icon, 0, bh * 0.16, math.min(w - 12, 84))
	local price = ui.label(node, "$" .. m.cost, 0, -bh * 0.2, 24, ui.WHITE, w - 8)
	local len = ui.label(node, m.max_len .. "m", 0, -bh * 0.38, app.portrait and 22 or 18, ui.DIM, w - 8)
	if m.unlock == session.index then
		-- sticker inside the tile's corner (it used to hang over the neighbouring button)
		local bw2, bh2 = app.portrait and 60 or 50, app.portrait and 26 or 22
		local badge = ui.panel(node, w / 2 - bw2 / 2 - 4, bh / 2 - bh2 / 2 - 4, bw2, bh2, ui.RED, 10)
		ui.text(badge, i18n.t("new_badge"), 0, 1, app.portrait and 18 or 15, ui.WHITE)
		ui.pulse(badge, 1.1, 0.5)
	end
	ui.button(node, function()
		session.select_material(m.id)
		M.refresh(app)
	end)
	h.mats[m.id] = { node = node, price = price, len = len }
	return node
end

local function veh_button(app, parent, x, y, w, bh, v)
	local node = ui.box(parent, "btn", x, y, w, bh, ui.PANEL_LT)
	gui.set_slice9(node, vmath.vector4(16, 16, 16, 24))
	ui.vehicle(node, v.id, 0, bh * 0.14, w - 8)
	for i = 1, 3 do
		ui.icon(node, i <= v.stars and "star" or "star_slot", (i - 2) * 20, -bh * 0.3, 20, i <= v.stars and ui.STAR or ui.STAR_OFF)
	end
	ui.button(node, function()
		session.select_vehicle(v.id)
		M.refresh(app)
	end)
	h.vehs[v.id] = node
	return node
end

local function hint(app)
	ads.offer_visible("hint")
	ads.rewarded("hint", function(ok)
		if ok and session.state == "build" then
			session.apply_hint()
			app.toast(i18n.t("hint_used"), ui.GREEN)
			M.refresh(app)
		elseif not ok then
			app.toast(i18n.t("reward_failed"), ui.RED)
		end
	end)
end

function M.build(app, root)
	h = { root = root, mats = {}, vehs = {} }
	local vw, vh = app.vw, app.vh
	local ml, mr, mt, mb = layout.margins(vw, vh, 14)
	local m = ml
	local lvl = session.level
	-- the top bar needs ~1180 units for one row; the bottom bar only as much as its buttons take,
	-- so 4:3 / 16:10 screens keep a single bottom row and more room for the bridge
	local mats = session.available_materials()
	local nm = #mats + 1 -- + eraser
	local tstk = app.portrait or vw < 1180
	local stacked = app.portrait or vw < ml + mr + 590 + nm * 70
	local top_w = vw - ml - mr

	-- ---------------------------------------------------------- top bar
	-- portrait buttons are taller: a virtual unit is about half a CSS pixel on a phone
	local top_h = tstk and 168 or 88
	local top = ui.panel(root, vw / 2, vh - mt - top_h / 2, top_w, top_h, ui.PANEL, 22)
	ui.blocker(top)
	local tw = top_w
	-- touch screens get 72-unit buttons in any orientation (a phone held sideways is just as small)
	local bh_top = (tstk or app.touch) and 72 or 62
	local row1 = tstk and top_h / 2 - 44 or 0
	ui.btn(top, -tw / 2 + (tstk and 54 or 50), row1, tstk and 88 or 80, math.max(bh_top, 68), "", function()
		session.exit_to_menu()
	end, { icon = "home", icon_size = 40 })
	local title = lvl.id .. "  " .. i18n.pick(lvl.name)
	local stars = progress.stars(lvl.id)
	-- rewarded hint: an ad marker in the corner tells the player a video plays
	local function hint_button(x, y, w, bh, isz)
		local node = ui.btn(top, x, y, w, bh, "", function() hint(app) end, { icon = "hint", icon_size = isz, color = ui.ORANGE })
		local badge = ui.box(node, "circle", w / 2 - 13, bh / 2 - 12, 24, 24, ui.PURPLE)
		ui.icon(badge, "video", 0, 0, 16, ui.WHITE)
		h.hint_btn = node
		if progress.fail_streak(lvl.id) >= 3 then
			gui.set_color(node, ui.YELLOW)
			ui.pulse(node, 1.12, 0.55)
		end
	end
	if tstk then
		ui.label(top, title, -tw / 2 + 108, row1, 32, ui.WHITE, tw - 340, 1, gui.PIVOT_W)
		ui.stars(top, tw / 2 - 168, row1, 30, stars, 32)
		hint_button(tw / 2 - 54, row1, 88, 72, 42)
	else
		-- stars follow the title; the title zone is capped so they never reach the budget pill
		local title_w = math.min(tw * 0.26, 360)
		ui.label(top, title, -tw / 2 + 100, 0, 32, ui.WHITE, title_w, 1, gui.PIVOT_W)
		ui.stars(top, -tw / 2 + 100 + title_w + 60, 0, 30, stars, 32)
	end
	-- budget pill
	local row2 = tstk and -top_h / 2 + 44 or 0
	local bw = tstk and (tw - 236) or math.min(460, tw * 0.3)
	local bx = tstk and (-tw / 2 + 12 + bw / 2) or (tw / 2 - 266 - bw / 2)
	local pill = ui.panel(top, bx, row2, bw, 62, ui.hex("#151926", 0.8), 26)
	ui.icon(pill, "coin", -bw / 2 + 32, 0, 40, ui.STAR)
	h.budget_txt, h.budget_comp = ui.label(pill, "", 14, 10, 26, ui.WHITE, bw - 90)
	h.budget_bar = ui.bar(pill, 14, -16, bw - 90, 12, ui.GREEN, ui.hex("#3A4360", 0.95))
	-- undo / clear (/ hint in landscape); clear needs a second tap within 2 s
	local bw_btn = tstk and 88 or 80
	local bx2 = tstk and (tw / 2 - 166) or (tw / 2 - 210)
	local _, ub = ui.btn(top, bx2, row2, bw_btn, bh_top, "", function()
		session.undo() -- the "erased" event plays the sound
		M.refresh(app)
	end, { icon = "undo", icon_size = 38 })
	h.undo_btn = ub
	local clear_node
	clear_node = ui.btn(top, bx2 + bw_btn + (tstk and 16 or 12), row2, bw_btn, bh_top, "", function()
		if session.blueprint:beam_count() == 0 then return end
		if h.clear_armed and h.clear_armed > 0 then
			h.clear_armed = nil
			session.clear()
			M.refresh(app)
		else
			h.clear_armed, h.clear_count = 2, session.blueprint:beam_count()
			M.refresh(app)
			app.toast(i18n.t("clear_confirm"), ui.RED)
		end
	end, { icon = "trash", icon_size = 38 })
	h.clear_node = clear_node
	if not tstk then
		hint_button(tw / 2 - 30, row2, 60, bh_top, 36)
	end

	-- ---------------------------------------------------------- bottom
	local bottom_h, mat_row_y, veh_row_y
	if stacked then
		bottom_h = 252
		mat_row_y = mb + bottom_h - 66
		veh_row_y = mb + 64
	else
		bottom_h = 132
		mat_row_y = mb + bottom_h / 2
		veh_row_y = mat_row_y
	end
	local bot = ui.panel(root, vw / 2, mb + bottom_h / 2, top_w, bottom_h, ui.PANEL, 22)
	ui.blocker(bot)

	-- vehicles + GO
	local vb_w, vb_h, go_w = 96, 108, stacked and 220 or 190
	local veh_total = 3 * vb_w + 2 * 10 + 16 + go_w
	local vx0 = stacked and (vw / 2 - veh_total / 2) or (vw - mr - 14 - veh_total)
	for i, v in ipairs(vehicles.list) do
		veh_button(app, root, vx0 + vb_w / 2 + (i - 1) * (vb_w + 10), veh_row_y, vb_w, vb_h, v)
	end
	local go_x = vx0 + 3 * vb_w + 2 * 10 + 16 + go_w / 2
	local go_node = ui.btn(root, go_x, veh_row_y, go_w, vb_h, i18n.t("go"), function() launch(app) end,
		{ color = ui.GREEN, icon = "play", icon_size = 44, size = 40 })
	ui.pulse(go_node, 1.03, 0.7)

	-- materials (+ eraser)
	local mat_area_w = stacked and (top_w - 24) or (vx0 - m - 30)
	local mb_w = math.max(62, math.min(100, (mat_area_w - (nm - 1) * 8) / nm))
	local mb_h = stacked and 116 or 112
	local mx0 = stacked and (vw / 2 - (nm * mb_w + (nm - 1) * 8) / 2) or (m + 16)
	for i, mat in ipairs(mats) do
		mat_button(app, root, mx0 + mb_w / 2 + (i - 1) * (mb_w + 8), mat_row_y, mb_w, mb_h, mat)
	end
	local ex = mx0 + mb_w / 2 + #mats * (mb_w + 8)
	local enode = ui.box(root, "btn", ex, mat_row_y, mb_w, mb_h, ui.PANEL_LT)
	gui.set_slice9(enode, vmath.vector4(16, 16, 16, 24))
	ui.icon(enode, "eraser", 0, mb_h * 0.14, math.min(56, mb_w - 16))
	ui.label(enode, i18n.t("erase"), 0, -mb_h * 0.28, 20, ui.WHITE, mb_w - 8)
	ui.button(enode, function() toggle_erase(app) end)
	h.erase = enode

	-- HUD covers the screen top/bottom: tell the camera so the bridge stays in the free area
	camera.set_insets((top_h + mt + 6) / vh, (bottom_h + mb + 6) / vh)
	h.free_lo, h.free_hi = mb + bottom_h + 34, vh - mt - top_h - 34
	app.hud_bottom = mb + bottom_h -- toasts sit just above the bottom bar

	-- quick "fit the whole build zone" button (after panning / zooming away)
	local fit_size = (app.portrait or app.touch) and 80 or 62
	ui.round(root, ml + 11 + fit_size / 2, mb + bottom_h + 19 + fit_size / 2, fit_size, "fit", function()
		local a = session.level.area or { session.level.start, -4, session.level.finish, 6 }
		camera.fit(a[1] - 1.5, a[2] - 1, a[3] + 1.5, a[4] + 1.5, false)
	end, { color = ui.PANEL, icon_size = 30 })

	-- ghost info label (length / price / error), positioned every frame
	-- one line for "3.0m $120", a wider two-line box for errors (they are long sentences)
	h.info = ui.panel(root, 0, 0, 220, 50, ui.hex("#151926", 0.85), 20)
	h.info_txt, h.info_comp = ui.label(h.info, "", 0, 2, 26, ui.WHITE, 200)
	h.err_w = math.min(420, vw - 40)
	h.err_txt, h.err_comp = ui.label(h.info, "", 0, 2, 24, ui.WHITE, h.err_w - 28, 2)
	gui.set_enabled(h.info, false)

	-- tip banner: early levels teach only after the player has actually fallen.
	local tip_key = lvl.tip
	local new = session.new_materials()
	local tip_text = tip_key and i18n.t(tip_key) or nil
	if not tip_text and #new > 0 then tip_text = i18n.f("new_material", i18n.t(new[1].name_key)) end
	local early = lvl.index <= 5
	local learned = progress.stats().losses > 0 or progress.fail_streak(lvl.id) > 0
	if lvl.index == 1 or (early and not learned) then tip_text = nil end
	if tip_text and not app.tip_shown[lvl.id] then
		app.tip_shown[lvl.id] = true
		local tw2 = math.min(760, vw - 40)
		-- same dark panel family as the HUD; an orange edge and bulb tie it to the hint button
		local tip = ui.panel(root, vw / 2, vh - mt - top_h - 70, tw2, 110, ui.hex("#262D40", 0.97), 22)
		ui.panel(tip, -tw2 / 2 + 6, 0, 12, 110, ui.ORANGE, 6)
		ui.box(tip, "circle", -tw2 / 2 + 50, 0, 64, 64, ui.hex("#FF8A1C", 0.18))
		ui.icon(tip, "hint", -tw2 / 2 + 50, 0, 46, ui.ORANGE)
		ui.label(tip, tip_text, 36, 0, 26, ui.WHITE, tw2 - 130, 3)
		ui.fade_in(tip, 0.3, 0.2)
		h.tip = tip
		h.tip_t = 9
		ui.button(tip, function() gui.set_enabled(tip, false) h.tip = nil end, { silent = true })
	end

	M.refresh(app)
end

function M.update(app, dt)
	if not h.root then return end
	if h.clear_armed then
		h.clear_armed = h.clear_armed - dt
		if h.clear_armed <= 0 then
			h.clear_armed = nil
			M.refresh(app)
		end
	end
	-- ghost label near the beam end, kept in the free band between the top bar and the bottom bar
	local p = session.preview
	if p and h.info then
		local sx, sy = camera.world_to_screen(p.x2, p.y2, 1.3)
		local w, bh = 220, 50
		if not p.ok then w, bh = h.err_w, 74 end
		local x, y = sx / app.px_scale, sy / app.px_scale + 70
		x = math.max(w / 2 + 10, math.min(app.vw - w / 2 - 10, x))
		y = math.max(h.free_lo or 60, math.min(h.free_hi or (app.vh - 60), y))
		gui.set_position(h.info, V3(x, y, 0))
		gui.set_size(h.info, V3(w, bh, 0))
		local len = math.sqrt((p.x2 - p.x1) ^ 2 + (p.y2 - p.y1) ^ 2)
		if p.ok then
			ui.set_label(h.info_txt, h.info_comp, string.format("%.1fm  $%s", len, i18n.money(p.cost)))
			gui.set_color(h.info, ui.hex("#151926", 0.85))
		else
			ui.set_label(h.err_txt, h.err_comp, i18n.t("err_" .. tostring(p.err)))
			gui.set_color(h.info, ui.hex("#8A1F24", 0.92))
		end
		gui.set_enabled(h.info_txt, p.ok)
		gui.set_enabled(h.err_txt, not p.ok)
		gui.set_enabled(h.info, true)
	elseif h.info then
		gui.set_enabled(h.info, false)
	end
	if h.tip and h.tip_t then
		h.tip_t = h.tip_t - dt
		if h.tip_t <= 0 then
			local tip = h.tip
			h.tip = nil
			gui.animate(tip, "color.w", 0, gui.EASING_OUTQUAD, 0.4, 0, function() gui.set_enabled(tip, false) end)
		end
	end
end

function M.on_event(app, e)
	local id = e.id
	if id == "design_changed" then
		M.refresh(app)
	elseif id == "built" then
		audio.play("build", 0.8, 0.9 + math.random() * 0.2)
		haptics.build()
		if session.index == 1 and not progress.get("tutorial_done") then progress.set_setting("tutorial_done", true) end
		if session.guide and session.guide_done() then
			app.toast(i18n.t("plan_done"), ui.CYAN)
		end
	elseif id == "erased" then
		audio.play("erase", 0.6)
		haptics.click()
	elseif id == "build_failed" then
		audio.play("error", 0.6)
		haptics.vibrate("[30,30,30]", 0.2)
		app.toast(i18n.t("err_" .. tostring(e.data.err)), ui.RED)
	elseif id == "budget_bonus" then
		app.toast(i18n.t("budget_bonus"), ui.GREEN)
	end
end

-- Keyboard shortcuts in build mode.
function M.on_key(app, action_id, action)
	if not action.pressed then return false end
	local name = app.key_names[action_id]
	if not name then return false end
	if name == "go" then
		launch(app)
	elseif name == "undo" then
		session.undo()
	elseif name == "erase" then
		toggle_erase(app)
	elseif name == "back" then
		-- Esc peels one layer at a time: selection / ghost -> eraser -> menu
		if session.selected_node or session.preview then
			session.selected_node = nil
			session.set_preview(nil)
		elseif session.tool == "erase" then
			session.set_tool("build")
		else
			session.exit_to_menu()
		end
	elseif name == "zoom_in" then
		camera.zoom_at(camera.w / 2, camera.h / 2, 0.85)
	elseif name == "zoom_out" then
		camera.zoom_at(camera.w / 2, camera.h / 2, 1.18)
	elseif name:sub(1, 4) == "mat_" then
		local mats = session.available_materials()
		local m = mats[tonumber(name:sub(5))]
		if m then session.select_material(m.id) end
	elseif name:sub(1, 4) == "veh_" then
		local v = vehicles.list[tonumber(name:sub(5))]
		if v then session.select_vehicle(v.id) end
	else
		return false
	end
	M.refresh(app)
	return true
end

function M.clear()
	h = {}
end

return M
