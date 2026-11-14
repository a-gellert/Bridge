-- Build-mode gestures, identical on mouse and touch:
--   drag from a joint          -> ghost beam, release to build (end joint stays selected)
--   tap a joint, tap a point   -> build from the selected joint (chain building, finger never hides the target)
--   tap the selected joint     -> deselect
--   drag empty space           -> pan,  pinch / mouse wheel -> zoom
--   erase tool or right click  -> delete the beam under the pointer
-- Desktop extra: with a joint selected, the ghost follows the mouse.
-- Fed by the GUI script with raw screen coordinates (action.screen_x/screen_y), only for input
-- the HUD did not consume.
local tuning = require("game.config.tuning")
local snap = require("game.bridge.snap")
local Blueprint = require("game.bridge.blueprint")
local session = require("game.core.session")
local camera = require("world.camera")

local M = {}

local TOUCH = hash("touch")
local TOUCH_MULTI = hash("touch_multi")
local WHEEL_UP = hash("wheel_up")
local WHEEL_DOWN = hash("wheel_down")
local MOUSE_RIGHT = hash("mouse_right")

-- virtual GUI px -> screen px (set by the GUI script on resize)
M.px_scale = 1

local st = { mode = "idle" }
local pinch = nil

local function dist(ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	return math.sqrt(dx * dx + dy * dy)
end

local function tol_world()
	return tuning.TOUCH_TOLERANCE_PX * M.px_scale * camera.world_per_px()
end

local function find_node(x, y, tol)
	return session.blueprint:nearest_node(x, y, tol)
end

-- End point of a beam from joint `from` aimed at screen point (sx, sy); nil if nothing fits.
local function to_world(sx, sy)
	return camera.screen_to_world(sx, sy, tuning.BUILD_PLANE_Z)
end

local function target_from(from, sx, sy)
	local wx, wy = to_world(sx, sy)
	return snap.beam_target(from.x, from.y, wx, wy, Blueprint.max_len(session.material), find_node, tol_world())
end

local function show_preview(from, sx, sy)
	local x, y = target_from(from, sx, sy)
	if x then
		session.set_preview(from.x, from.y, x, y)
	else
		session.set_preview(nil)
	end
end

local function build_preview()
	local p = session.preview
	session.set_preview(nil)
	if not p then return false end
	local ok = session.try_build(p.x1, p.y1, p.x2, p.y2)
	if ok then
		local n = session.blueprint:node_at(p.x2, p.y2)
		session.selected_node = n and n.id or nil
	end
	return ok
end

local function selected()
	local id = session.selected_node
	return id and session.blueprint.nodes[id] or nil
end

function M.reset()
	st = { mode = "idle" }
	pinch = nil
	session.set_preview(nil)
end

-- ------------------------------------------------------------------ pointer
local function press(sx, sy)
	st = { mode = "idle", sx = sx, sy = sy, lx = sx, ly = sy, moved = false }
	local wx, wy = to_world(sx, sy)
	if session.tool == "erase" then
		st.mode = "erase_press"
		return
	end
	local node = session.blueprint:nearest_node(wx, wy, tol_world())
	if node then
		st.mode = "node_press"
		st.node = node.id
	elseif selected() then
		st.mode = "place_press"
	else
		st.mode = "pan_press"
	end
end

local function move(sx, sy)
	if st.mode == "idle" then
		-- desktop hover: ghost from the selected joint to the cursor
		local sel = selected()
		if sel and session.tool == "build" then show_preview(sel, sx, sy) end
		return
	end
	if not st.moved and dist(sx, sy, st.sx, st.sy) > tuning.DRAG_THRESHOLD_PX * M.px_scale then
		st.moved = true
		if st.mode == "node_press" then
			st.mode = "drag_beam"
			session.selected_node = st.node
		else
			st.mode = "pan"
		end
	end
	if st.mode == "drag_beam" then
		local from = session.blueprint.nodes[st.node]
		if from then show_preview(from, sx, sy) end
	elseif st.mode == "pan" then
		camera.pan_px(sx - st.lx, sy - st.ly)
	end
	st.lx, st.ly = sx, sy
end

local function release(sx, sy)
	local mode = st.mode
	st.mode = "idle"
	local bp = session.blueprint
	if mode == "drag_beam" then
		local p = session.preview
		if p and p.ok then
			build_preview()
		elseif p then
			session.try_build(p.x1, p.y1, p.x2, p.y2) -- emits build_failed with the reason
			session.set_preview(nil)
		end
	elseif mode == "node_press" then
		local sel = selected()
		local node = bp.nodes[st.node]
		if not node then return end
		if sel and sel.id == node.id then
			session.selected_node = nil
			session.set_preview(nil)
		elseif sel then
			local x, y = target_from(sel, sx, sy)
			if x then
				session.set_preview(sel.x, sel.y, x, y)
				if not build_preview() then session.selected_node = node.id end
			else
				session.selected_node = node.id
			end
		else
			session.selected_node = node.id
		end
	elseif mode == "place_press" then
		local sel = selected()
		if sel then
			local x, y = target_from(sel, sx, sy)
			if x then
				session.set_preview(sel.x, sel.y, x, y)
				build_preview()
			end
		end
	elseif mode == "erase_press" then
		local wx, wy = to_world(sx, sy)
		local bm = bp:nearest_beam(wx, wy, tol_world())
		if bm then session.erase_beam(bm.id) end
	elseif mode == "pan_press" then
		session.selected_node = nil
		session.set_preview(nil)
	end
end

-- ------------------------------------------------------------------ pinch (two fingers)
local function handle_multi(action)
	local t = action.touch
	local active = {}
	for i = 1, #t do
		if not t[i].released then active[#active + 1] = t[i] end
	end
	if #active >= 2 then
		local a, b = active[1], active[2]
		local d = dist(a.screen_x, a.screen_y, b.screen_x, b.screen_y)
		local mx, my = (a.screen_x + b.screen_x) * 0.5, (a.screen_y + b.screen_y) * 0.5
		if not pinch then
			pinch = { d = d, mx = mx, my = my }
			st = { mode = "idle" }
			session.set_preview(nil)
		else
			if d > 10 and pinch.d > 10 then camera.zoom_at(mx, my, pinch.d / d) end
			camera.pan_px(mx - pinch.mx, my - pinch.my)
			pinch.d, pinch.mx, pinch.my = d, mx, my
		end
		return true
	elseif pinch then
		pinch = nil
		st = { mode = "idle" }
		return true
	end
	return false
end

-- Returns true when the input was used.
function M.on_input(action_id, action)
	if session.state ~= "build" or not session.blueprint then return false end
	if action_id == TOUCH_MULTI then
		return handle_multi(action)
	end
	if pinch then return true end
	if action_id == WHEEL_UP or action_id == WHEEL_DOWN then
		if action.pressed or action.value then
			camera.zoom_at(action.screen_x, action.screen_y, action_id == WHEEL_UP and 0.88 or 1.14)
		end
		return true
	end
	if action_id == MOUSE_RIGHT then
		if action.pressed then
			local wx, wy = to_world(action.screen_x, action.screen_y)
			local bm = session.blueprint:nearest_beam(wx, wy, tol_world())
			if bm then session.erase_beam(bm.id) end
		end
		return true
	end
	if action_id == TOUCH then
		if action.pressed then
			press(action.screen_x, action.screen_y)
		elseif action.released then
			move(action.screen_x, action.screen_y)
			release(action.screen_x, action.screen_y)
		else
			move(action.screen_x, action.screen_y)
		end
		return true
	end
	if action_id == nil and action.screen_x then
		move(action.screen_x, action.screen_y)
		return false
	end
	return false
end

-- Pointer is down and owned by the world (the HUD must not react to it).
function M.busy()
	return st.mode ~= "idle" or pinch ~= nil
end

return M
