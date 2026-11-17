-- 2.5D side camera: perspective, slightly from above and from the front.
-- Shared module: world.script updates it and sends the matrices to the render script; the GUI script
-- uses it for screen <-> world conversions (building) and tells it how much screen the HUD covers.
local tuning = require("game.config.tuning")

local M = {}

local tan, sin, cos, max, min = math.tan, math.sin, math.cos, math.max, math.min

M.w, M.h = 1280, 720
M.cx, M.cy, M.vh = 0, 2, 16          -- current center (world) and visible world height
M.tx, M.ty, M.tvh = 0, 2, 16         -- smoothing targets
M.insets = { top = 0, bottom = 0 }   -- fraction of screen height covered by HUD bars
M.bounds = nil                       -- {x0, y0, x1, y1} the center may move in
M.follow_rate = 6
M.shake_t, M.shake_amp = 0, 0
M.fov_add, M.fov_target = 0, 0   -- dynamic FOV (speed / boost)
M.drama_t, M.drama_amp = 0, 0    -- extra FOV on slow-mo / heavy hits
M.view = vmath.matrix4()
M.proj = vmath.matrix4()

local inv_vp = vmath.matrix4()

function M.set_window(w, h)
	if w > 0 and h > 0 then M.w, M.h = w, h end
end

function M.set_insets(top, bottom)
	top, bottom = top or 0, bottom or 0
	local changed = math.abs(top - M.insets.top) > 1e-3 or math.abs(bottom - M.insets.bottom) > 1e-3
	M.insets.top, M.insets.bottom = top, bottom
	-- keep the last framed rectangle in the free area when the HUD changes
	if changed and M.fit_rect then
		local r = M.fit_rect
		M.fit(r[1], r[2], r[3], r[4], false)
	end
end

function M.world_per_px()
	return M.vh / M.h
end

local function clamp_view(vh)
	return max(tuning.CAM_MIN_VIEW, min(tuning.CAM_MAX_VIEW, vh))
end

local function clamp_center(x, y)
	local b = M.bounds
	if not b then return x, y end
	return max(b[1], min(b[3], x)), max(b[2], min(b[4], y))
end

-- vertical shift (world) that puts the HUD-free area's center under the given point
local function inset_shift(vh)
	return (M.insets.bottom - M.insets.top) * 0.5 * vh
end

function M.transition_to(tx, ty, tvh, duration)
	duration = duration or 0.2
	M.transition = {
		from_x = M.cx,
		from_y = M.cy,
		from_vh = M.vh,
		to_x = tx,
		to_y = ty,
		to_vh = tvh,
		duration = duration,
		elapsed = 0,
	}
	M.tx, M.ty, M.tvh = tx, ty, tvh
end

-- Frame a world rectangle inside the part of the screen not covered by the HUD.
function M.fit(x0, y0, x1, y1, immediate, duration)
	M.fit_rect = { x0, y0, x1, y1 }
	local usable_h = M.h * max(0.2, 1 - M.insets.top - M.insets.bottom)
	local usable_w = M.w * 0.94
	local wpp = max((y1 - y0) / usable_h, (x1 - x0) / usable_w)
	local vh = clamp_view(wpp * M.h)
	local cx = (x0 + x1) * 0.5
	local cy = (y0 + y1) * 0.5 - inset_shift(vh)
	M.tx, M.ty, M.tvh = cx, cy, vh
	if immediate then
		M.cx, M.cy, M.vh = cx, cy, vh
		M.transition = nil
	elseif duration and duration > 0 then
		M.transition_to(cx, cy, vh, duration)
	else
		M.transition = nil
	end
end

-- Follow a point (drive mode): keeps `span` meters of width visible.
function M.follow(x, y, span, lead)
	M.fit_rect = nil
	M.transition = nil
	local aspect = M.w / max(1, M.h)
	local vh = clamp_view(max(span / aspect, span * 0.45))
	M.tvh = vh
	M.tx = x + (lead or 0)
	M.ty = y + vh * 0.12 - inset_shift(vh)
end

-- Pan by a screen-space delta (pixels).
function M.pan_px(dx, dy)
	M.fit_rect = nil
	M.transition = nil
	local k = M.world_per_px()
	M.cx, M.cy = clamp_center(M.cx - dx * k, M.cy - dy * k)
	M.tx, M.ty = M.cx, M.cy
end

-- Zoom keeping the world point under the screen point (sx, sy) fixed.
function M.zoom_at(sx, sy, factor)
	M.fit_rect = nil
	M.transition = nil
	local wx, wy = M.screen_to_world(sx, sy)
	local nvh = clamp_view(M.vh * factor)
	local k = nvh / M.vh
	M.vh = nvh
	M.cx, M.cy = clamp_center(wx + (M.cx - wx) * k, wy + (M.cy - wy) * k)
	M.tx, M.ty, M.tvh = M.cx, M.cy, M.vh
	M.compute()
end

function M.shake(amp, time)
	M.shake_amp = max(M.shake_amp, amp)
	M.shake_t = max(M.shake_t, time or 0.3)
end

-- Wide-angle speed feel: 0 = normal, 1 = top speed.
function M.set_speed_fov(k)
	M.fov_target = (k or 0) * tuning.CAM_SPEED_FOV
end

-- Short cinematic punch (slow motion, big crash).
function M.drama(amp, time)
	M.drama_amp = max(M.drama_amp, (amp or 0.5) * tuning.CAM_DRAMA_FOV)
	M.drama_t = max(M.drama_t, time or 0.45)
end

function M.compute()
	local drama = 0
	if M.drama_t > 0 then drama = M.drama_amp * min(1, M.drama_t * 3) end
	local fov = tuning.CAM_FOV + M.fov_add + drama
	local dist = (M.vh * 0.5) / tan(tuning.CAM_FOV * 0.5)
	local sx, sy = 0, 0
	if M.shake_t > 0 then
		local a = M.shake_amp * min(1, M.shake_t * 3)
		sx, sy = (math.random() - 0.5) * a, (math.random() - 0.5) * a
	end
	local target = vmath.vector3(M.cx + sx, M.cy + sy, 0)
	local p, yw = tuning.CAM_PITCH, tuning.CAM_YAW
	local eye = target + vmath.vector3(sin(yw) * cos(p), sin(p), cos(yw) * cos(p)) * dist
	M.view = vmath.matrix4_look_at(eye, target, vmath.vector3(0, 1, 0))
	M.proj = vmath.matrix4_perspective(fov, M.w / max(1, M.h), 0.5, dist + 220)
	inv_vp = vmath.inv(M.proj * M.view)
end

function M.update(dt)
	if M.transition then
		M.transition.elapsed = M.transition.elapsed + dt
		local p = math.min(1, M.transition.elapsed / math.max(1e-4, M.transition.duration))
		local ease = 1 - (1 - p) * (1 - p) * (1 - p)
		M.cx = M.transition.from_x + (M.transition.to_x - M.transition.from_x) * ease
		M.cy = M.transition.from_y + (M.transition.to_y - M.transition.from_y) * ease
		M.vh = M.transition.from_vh + (M.transition.to_vh - M.transition.from_vh) * ease
		if p >= 1 then
			M.cx, M.cy, M.vh = M.tx, M.ty, M.tvh
			M.transition = nil
		end
	else
		local k = 1 - math.exp(-M.follow_rate * dt)
		M.cx = M.cx + (M.tx - M.cx) * k
		M.cy = M.cy + (M.ty - M.cy) * k
		M.vh = M.vh + (M.tvh - M.vh) * k
	end
	local fk = 1 - math.exp(-5 * dt)
	M.fov_add = M.fov_add + (M.fov_target - M.fov_add) * fk
	if M.shake_t > 0 then
		M.shake_t = M.shake_t - dt
		if M.shake_t <= 0 then M.shake_amp = 0 end
	end
	if M.drama_t > 0 then M.drama_t = M.drama_t - dt end
	M.compute()
end

-- Screen pixel (origin bottom-left, like action.screen_x/y) -> point on the plane z = plane_z (default 0).
function M.screen_to_world(sx, sy, plane_z)
	local nx = sx / M.w * 2 - 1
	local ny = sy / M.h * 2 - 1
	local a = inv_vp * vmath.vector4(nx, ny, -1, 1)
	local b = inv_vp * vmath.vector4(nx, ny, 1, 1)
	local ax, ay, az = a.x / a.w, a.y / a.w, a.z / a.w
	local bx, by, bz = b.x / b.w, b.y / b.w, b.z / b.w
	local pz = plane_z or 0
	local t = (az - pz) / (az - bz)
	return ax + (bx - ax) * t, ay + (by - ay) * t
end

-- World point -> screen pixel.
function M.world_to_screen(x, y, z)
	local p = M.proj * M.view * vmath.vector4(x, y, z or 0, 1)
	return (p.x / p.w * 0.5 + 0.5) * M.w, (p.y / p.w * 0.5 + 0.5) * M.h
end

M.compute()

return M
