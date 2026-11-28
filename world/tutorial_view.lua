-- First-level tutorial plan: the reference road is drawn as pulsing dashed lines and the
-- joints the player should reach are marked with glowing rings. Everything disappears as
-- soon as the banks are connected (any valid road split) and never appears in drive mode.
local spawn = require("world.spawn")
local tuning = require("game.config.tuning")

local M = {}

local atan2, sqrt, sin = math.atan2, math.sqrt, math.sin
local Z_GLOW = tuning.BUILD_PLANE_Z + 0.11
local Z_CORE = tuning.BUILD_PLANE_Z + 0.13
local Z_RING = tuning.BUILD_PLANE_Z + 0.19
local GLOW = { 0.20, 0.95, 0.45 }
local CORE = { 0.68, 1.00, 0.80 }
local DASH_LEN, GAP, WIDTH, GLOW_W = 0.50, 0.26, 0.18, 0.50

local bars = {}  -- solution index -> { segments = { { core = go, glow = go } } }
local rings = {} -- "x,y" -> { go, x, y }
local active = false
local t = 0
local cue = nil  -- animated drag gesture: a bright ring sliding A -> B with a short trail
local CUE_TRAIL = 4

local function remove(i)
	local rec = bars[i]
	if rec then
		for _, seg in ipairs(rec.segments) do
			spawn.delete(seg.core)
			spawn.delete(seg.glow)
		end
		bars[i] = nil
	end
end

local function clear()
	for i in pairs(bars) do remove(i) end
	bars = {}
	for _, rec in pairs(rings) do spawn.delete(rec.go) end
	rings = {}
	if cue then
		spawn.delete(cue.ring)
		for _, go_id in ipairs(cue.trail) do spawn.delete(go_id) end
		cue = nil
	end
	active = false
	t = 0
end

local function cue_points(session)
	local a = session.level and session.level.anchors
	if not a or #a < 2 then return nil end
	return a[1], a[2]
end

local function make_cue(session)
	local a, b = cue_points(session)
	if not a or not b then return end
	cue = { ring = spawn.create("select_ring", a[1], a[2], Z_RING, 0, 1.1, 1.1, 1), trail = {}, a = a, b = b }
	for i = 1, CUE_TRAIL do
		cue.trail[i] = spawn.create("select_ring", a[1], a[2], Z_RING - i * 0.01, 0, 0.7, 0.7, 1)
	end
end

-- Short quads separated by gaps: reads as a plan, never as a real road.
local function add_dashes(rec, s)
	local dx, dy = s[4] - s[2], s[5] - s[3]
	local len = sqrt(dx * dx + dy * dy)
	if len < 0.01 then return end
	local a = atan2(dy, dx)
	local step = DASH_LEN + GAP
	local n = math.max(1, math.floor((len + GAP) / step))
	local span = n * step - GAP
	local offset = (len - span) * 0.5 + DASH_LEN * 0.5
	for k = 0, n - 1 do
		local d = offset + k * step
		local cx = s[2] + dx / len * d
		local cy = s[3] + dy / len * d
		rec.segments[#rec.segments + 1] = {
			glow = spawn.create("zone", cx, cy, Z_GLOW, a, DASH_LEN + 0.08, GLOW_W, 1),
			core = spawn.create("zone", cx, cy, Z_CORE, a, DASH_LEN, WIDTH, 1),
		}
	end
end

local function add_ring(x, y, keep)
	local key = string.format("%.2f,%.2f", x, y)
	keep[key] = true
	if not rings[key] then
		rings[key] = { go = spawn.create("select_ring", x, y, Z_RING, 0, 1, 1, 1), x = x, y = y }
	end
end

local function prune_rings(keep)
	for key, rec in pairs(rings) do
		if not keep[key] then
			spawn.delete(rec.go)
			rings[key] = nil
		end
	end
end

-- Reconcile with the design. Completed plan segments lose their dashes; the whole
-- overlay is removed when a drivable path joins the banks (even if split differently).
function M.sync(session)
	local show = session and session.state == "build" and session.tutorial
		and session.level and session.level.tutorial and session.level.solution
	if not show then
		clear()
		return
	end
	local sol = session.level.solution
	local keep = {}
	if session.tutorial_ready() then
		for i in pairs(bars) do remove(i) end
		prune_rings(keep)
		if cue then
			spawn.delete(cue.ring)
			for _, go_id in ipairs(cue.trail) do spawn.delete(go_id) end
			cue = nil
		end
		active = false
		return
	end
	active = true
	if not cue then make_cue(session) end
	for i, s in ipairs(sol) do
		if session.guide_has_beam(s) then
			remove(i)
		else
			local rec = bars[i]
			if not rec then
				rec = { segments = {} }
				bars[i] = rec
				add_dashes(rec, s)
			end
			add_ring(s[2], s[3], keep)
			add_ring(s[4], s[5], keep)
		end
	end
	for i in pairs(bars) do
		if i > #sol then remove(i) end
	end
	prune_rings(keep)
end

-- Slow pulse so the plan feels alive without competing with the real bridge.
function M.update(dt, session)
	if not active then return end
	t = t + dt
	-- The player understood: as soon as a joint is grabbed / a beam is dragging, retire the
	-- animated gesture (the rings and dashes stay until the road is complete).
	if cue and session and (session.selected_node or session.preview) then
		spawn.delete(cue.ring)
		for _, go_id in ipairs(cue.trail) do spawn.delete(go_id) end
		cue = nil
	end
	local k = 0.62 + 0.38 * sin(t * 4.0)
	for _, rec in pairs(bars) do
		for _, seg in ipairs(rec.segments) do
			spawn.tint(seg.glow, GLOW[1], GLOW[2], GLOW[3], 0.10 + 0.10 * k)
			spawn.tint(seg.core, CORE[1], CORE[2], CORE[3], 0.62 + 0.38 * k)
		end
	end
	for _, rec in pairs(rings) do
		local s = 0.95 + 0.15 * sin(t * 5.0 + rec.x)
		spawn.set("select_ring", rec.go, rec.x, rec.y, Z_RING, 0, s, s, 1)
		spawn.tint(rec.go, 0.30, 1.00, 0.55, 0.62 + 0.38 * k)
	end
	-- Animated finger cue: slide from the first anchor to the second, pause, repeat. It
	-- communicates "drag across the gap" with no text, even before the idle plate appears.
	if cue then
		local a, b = cue.a, cue.b
		if a and b then
			local cycle = 2.4
			local p = (t % cycle) / 1.7
			if p > 1 then p = 1 end
			local e = p * p * (3 - 2 * p)
			local x = a[1] + (b[1] - a[1]) * e
			local y = a[2] + (b[2] - a[2]) * e
			local pulse = 0.95 + 0.12 * sin(t * 9)
			spawn.set("select_ring", cue.ring, x, y, Z_RING, 0, pulse, pulse, 1)
			spawn.tint(cue.ring, 0.55, 1.00, 0.68, 0.85)
			for i, go_id in ipairs(cue.trail) do
				local te = math.max(0, e - i * 0.075)
				local tx = a[1] + (b[1] - a[1]) * te
				local ty = a[2] + (b[2] - a[2]) * te
				local s = 0.62 - i * 0.09
				spawn.set("select_ring", go_id, tx, ty, Z_RING - i * 0.01, 0, s, s, 1)
				spawn.tint(go_id, 0.35, 1.00, 0.55, 0.34 - i * 0.06)
			end
		end
	end
end

function M.clear()
	clear()
end

return M
