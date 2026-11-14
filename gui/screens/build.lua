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
local poki = require("platform.poki")
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
		gui.set_enabled(b.sel, sel)
	end
	if h.erase then gui.set_color(h.erase, session.tool == "erase" and ui.RED or ui.PANEL_LT) end
	for id, node in pairs(h.vehs) do
		gui.set_color(node, session.vehicle == id and ui.BLUE or ui.PANEL_LT)
	end
	if h.undo_btn then h.undo_btn:set_enabled(bp:can_undo()) end
end

local function toggle_erase(app)
	session.set_tool(session.tool == "erase" and "build" or "erase")
	M.refresh(app)
end

local function launch(app)
	if session.blueprint:beam_count() == 0 and session.index > 1 then
		app.toast(i18n.t("tip_build_" .. (app.touch and "touch" or "pc")), ui.YELLOW)
	end
	session.start_drive(session.vehicle)
end

-- material button
local function mat_button(app, parent, x, y, w, bh, m)
	local node = ui.box(parent, "btn", x, y, w, bh, ui.PANEL_LT)
	gui.set_slice9(node, vmath.vector4(16, 16, 16, 24))
	local sel = ui.panel(node, 0, 0, w + 8, bh + 8, ui.hex("#FFFFFF", 0.0), 20)
	local ic = ui.box(node, m.icon, 0, bh * 0.16, math.min(w - 12, 84), math.min(w - 12, 84) * 0.66)
	ui.label(node, "$" .. m.cost, 0, -bh * 0.2, 24, ui.WHITE, w - 8)
	ui.label(node, m.max_len .. "m", 0, -bh * 0.38, 18, ui.DIM, w - 8)
	if m.unlock == session.index then
		local badge = ui.panel(node, w / 2 - 14, bh / 2 - 8, 56, 26, ui.RED, 12)
		ui.text(badge, "NEW", 0, 1, 18, ui.WHITE)
		ui.pulse(badge, 1.12, 0.5)
	end
	ui.button(node, function()
		session.select_material(m.id)
		M.refresh(app)
	end)
	h.mats[m.id] = { node = node, sel = sel }
	gui.set_enabled(sel, false)
	return node
end

local function veh_button(app, parent, x, y, w, bh, v)
	local node = ui.box(parent, "btn", x, y, w, bh, ui.PANEL_LT)
	gui.set_slice9(node, vmath.vector4(16, 16, 16, 24))
	ui.icon(node, v.icon, 0, bh * 0.14, math.min(w, bh) * 0.56)
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
	poki.rewarded_break(function(ok)
		if ok and session.state == "build" then
			session.apply_hint()
			app.toast(i18n.t("hint_used"), ui.GREEN)
			M.refresh(app)
		end
	end)
end

function M.build(app, root)
	h = { root = root, mats = {}, vehs = {} }
	local vw, vh = app.vw, app.vh
	local m = 14
	local lvl = session.level
	local stacked = app.portrait or vw < 1180

	-- ---------------------------------------------------------- top bar
	local top_h = stacked and 150 or 88
	local top = ui.panel(root, vw / 2, vh - m - top_h / 2, vw - 2 * m, top_h, ui.PANEL, 22)
	ui.blocker(top)
	local tw = vw - 2 * m
	local row1 = stacked and top_h / 2 - 42 or 0
	ui.btn(top, -tw / 2 + 50, row1, 80, 68, "", function()
		session.exit_to_menu()
	end, { icon = "home", icon_size = 40 })
	local title = lvl.id .. "  " .. i18n.pick(lvl.name)
	local stars = progress.stars(lvl.id)
	if stacked then
		ui.label(top, title, -tw / 2 + 100, row1, 32, ui.WHITE, tw - 330, 1, gui.PIVOT_W)
		ui.stars(top, tw / 2 - 160, row1, 30, stars, 32)
		ui.btn(top, tw / 2 - 50, row1, 80, 68, "", function() hint(app) end, { icon = "hint", icon_size = 40, color = ui.ORANGE })
	else
		ui.label(top, title, -tw / 2 + 100, 0, 32, ui.WHITE, tw * 0.3, 1, gui.PIVOT_W)
		ui.stars(top, -tw / 2 + 100 + tw * 0.3 + 60, 0, 30, stars, 32)
	end
	-- budget pill
	local row2 = stacked and -top_h / 2 + 40 or 0
	local bw = stacked and (tw - 210) or math.min(460, tw * 0.32)
	local bx = stacked and (-tw / 2 + 12 + bw / 2) or (tw / 2 - 250 - bw / 2)
	local pill = ui.panel(top, bx, row2, bw, 62, ui.hex("#151926", 0.8), 26)
	ui.icon(pill, "coin", -bw / 2 + 32, 0, 40, ui.STAR)
	h.budget_txt, h.budget_comp = ui.label(pill, "", 14, 10, 26, ui.WHITE, bw - 90)
	h.budget_bar = ui.bar(pill, 14, -16, bw - 90, 12, ui.GREEN)
	-- undo / clear (/ hint in landscape)
	local bx2 = stacked and (tw / 2 - 150) or (tw / 2 - 210)
	local _, ub = ui.btn(top, bx2, row2, 80, 62, "", function()
		if session.undo() then audio.play("erase", 0.6) end
		M.refresh(app)
	end, { icon = "undo", icon_size = 38 })
	h.undo_btn = ub
	ui.btn(top, bx2 + 92, row2, 80, 62, "", function()
		session.clear()
		M.refresh(app)
	end, { icon = "trash", icon_size = 38 })
	if not stacked then
		ui.btn(top, tw / 2 - 26 - 4, row2, 52 + 8, 62, "", function() hint(app) end, { icon = "hint", icon_size = 36, color = ui.ORANGE })
	end

	-- ---------------------------------------------------------- bottom
	local mats = session.available_materials()
	local nm = #mats + 1 -- + eraser
	local bottom_h, mat_row_y, veh_row_y
	if stacked then
		bottom_h = 252
		mat_row_y = m + bottom_h - 66
		veh_row_y = m + 64
	else
		bottom_h = 132
		mat_row_y = m + bottom_h / 2
		veh_row_y = mat_row_y
	end
	local bot = ui.panel(root, vw / 2, m + bottom_h / 2, vw - 2 * m, bottom_h, ui.PANEL, 22)
	ui.blocker(bot)

	-- vehicles + GO
	local vb_w, vb_h, go_w = 96, 108, stacked and 220 or 190
	local veh_total = 3 * vb_w + 2 * 10 + 16 + go_w
	local vx0 = stacked and (vw / 2 - veh_total / 2) or (vw - m - 14 - veh_total)
	for i, v in ipairs(vehicles.list) do
		veh_button(app, root, vx0 + vb_w / 2 + (i - 1) * (vb_w + 10), veh_row_y, vb_w, vb_h, v)
	end
	local go_x = vx0 + 3 * vb_w + 2 * 10 + 16 + go_w / 2
	local go_node = ui.btn(root, go_x, veh_row_y, go_w, vb_h, i18n.t("go"), function() launch(app) end,
		{ color = ui.GREEN, icon = "play", icon_size = 44, size = 40 })
	ui.pulse(go_node, 1.03, 0.7)

	-- materials (+ eraser)
	local mat_area_w = stacked and (vw - 2 * m - 24) or (vx0 - m - 30)
	local mb_w = math.max(62, math.min(100, (mat_area_w - (nm - 1) * 8) / nm))
	local mb_h = stacked and 116 or 112
	local mx0 = stacked and (vw / 2 - (nm * mb_w + (nm - 1) * 8) / 2) or (m + 16)
	for i, mat in ipairs(mats) do
		mat_button(app, root, mx0 + mb_w / 2 + (i - 1) * (mb_w + 8), mat_row_y, mb_w, mb_h, mat)
	end
	local ex = mx0 + mb_w / 2 + #mats * (mb_w + 8)
	local enode = ui.box(root, "btn", ex, mat_row_y, mb_w, mb_h, ui.PANEL_LT)
	gui.set_slice9(enode, vmath.vector4(16, 16, 16, 24))
	ui.icon(enode, "eraser", 0, 10, math.min(56, mb_w - 20))
	ui.label(enode, i18n.t("erase"), 0, -mb_h * 0.34, 18, ui.WHITE, mb_w - 8)
	ui.button(enode, function() toggle_erase(app) end)
	h.erase = enode

	-- HUD covers the screen top/bottom: tell the camera so the bridge stays in the free area
	camera.set_insets((top_h + m) / vh, (bottom_h + m) / vh)

	-- ghost info label (length / price / error), positioned every frame
	h.info = ui.panel(root, 0, 0, 220, 50, ui.hex("#151926", 0.85), 20)
	h.info_txt, h.info_comp = ui.label(h.info, "", 0, 2, 26, ui.WHITE, 200)
	gui.set_enabled(h.info, false)

	-- tip banner
	local tip_key = lvl.tip
	local new = session.new_materials()
	local tip_text = tip_key and i18n.t(tip_key) or nil
	if not tip_text and #new > 0 then tip_text = i18n.f("new_material", i18n.t(new[1].name_key)) end
	if session.index == 1 and not progress.get("tutorial_done") then
		tip_text = i18n.t("tip_first") .. "\n" .. i18n.t("tip_build_" .. (app.touch and "touch" or "pc"))
	end
	if tip_text and not app.tip_shown[lvl.id] then
		app.tip_shown[lvl.id] = true
		local tw2 = math.min(760, vw - 40)
		local tip = ui.panel(root, vw / 2, vh - m - top_h - 70, tw2, 110, ui.hex("#FFF6D6", 0.97), 22)
		ui.icon(tip, "hint", -tw2 / 2 + 44, 0, 52, ui.ORANGE)
		local tip_label = ui.label(tip, tip_text, 30, 0, 26, ui.INK, tw2 - 120, 3)
		gui.set_outline(tip_label, ui.CLEAR)
		ui.fade_in(tip, 0.3, 0.2)
		h.tip = tip
		h.tip_t = 9
		ui.button(tip, function() gui.set_enabled(tip, false) h.tip = nil end, { silent = true })
	end

	M.refresh(app)
end

function M.update(app, dt)
	if not h.root then return end
	-- ghost label near the beam end
	local p = session.preview
	if p and h.info then
		local sx, sy = camera.world_to_screen(p.x2, p.y2, 1.3)
		local x, y = sx / app.px_scale, sy / app.px_scale + 70
		x = math.max(120, math.min(app.vw - 120, x))
		y = math.max(60, math.min(app.vh - 60, y))
		gui.set_position(h.info, V3(x, y, 0))
		local len = math.sqrt((p.x2 - p.x1) ^ 2 + (p.y2 - p.y1) ^ 2)
		local txt
		if p.ok then
			txt = string.format("%.1fm  $%s", len, i18n.money(p.cost))
			gui.set_color(h.info, ui.hex("#151926", 0.85))
		else
			txt = i18n.t("err_" .. tostring(p.err))
			gui.set_color(h.info, ui.hex("#8A1F24", 0.92))
		end
		ui.set_label(h.info_txt, h.info_comp, txt)
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
		if session.index == 1 and not progress.get("tutorial_done") then progress.set_setting("tutorial_done", true) end
	elseif id == "erased" then
		audio.play("erase", 0.6)
	elseif id == "build_failed" then
		audio.play("error", 0.6)
		app.toast(i18n.t("err_" .. tostring(e.data.err)), ui.RED)
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
		session.exit_to_menu()
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
