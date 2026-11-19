-- Post-failure brace hint: after two consecutive collapses on levels 3-5, the non-deck
-- beams of the reference solution (the struts / triangles that hold the deck up) are drawn
-- as pulsing dashed lines. It is never shown on entry and vanishes on the first screen touch.
local spawn = require("world.spawn")
local materials = require("game.config.materials")
local tuning = require("game.config.tuning")

local M = {}

local atan2, sqrt, sin = math.atan2, math.sqrt, math.sin
local Z_GLOW = tuning.BUILD_PLANE_Z + 0.11
local Z_HINT = tuning.BUILD_PLANE_Z + 0.13
local CORE = { 0.55, 1.0, 0.68 }
local GLOW = { 0.20, 0.95, 0.42 }
local DASH_LEN, GAP, WIDTH, GLOW_W = 0.55, 0.25, 0.22, 0.58

local bars = {} -- solution index -> { mat, segments = { { core = go, glow = go } } }
local active = false
local t = 0

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
end

-- Break one brace into short quads separated by gaps: a dashed line that reads as a hint,
-- not as a real beam that the player could confuse with the finished bridge.
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
			core = spawn.create("zone", cx, cy, Z_HINT, a, DASH_LEN, WIDTH, 1),
		}
	end
end

-- Reconcile the hint with the design: a brace the player already repeated loses its dashes.
function M.sync(session)
	local show = session and session.state == "build" and session.guide
		and session.level and session.level.brace_hint and session.level.solution ~= nil
	active = show and true or false
	if not show then
		clear()
		return
	end
	local sol = session.level.solution
	for i, s in ipairs(sol) do
		local mat = materials.get(s[1])
		local brace = mat and not mat.drivable and math.abs(s[5] - s[3]) > 0.01
		if not brace or session.guide_has_beam(s) then
			remove(i)
		else
			local rec = bars[i]
			if not rec or rec.mat ~= s[1] then
				remove(i)
				rec = { mat = s[1], segments = {} }
				bars[i] = rec
				add_dashes(rec, s)
			end
		end
	end
	for i in pairs(bars) do
		if i > #sol then remove(i) end
	end
end

-- Slow pulse so the dashes read as a hint rather than solid geometry.
function M.update(dt)
	if not active then return end
	t = t + dt
	local k = 0.62 + 0.38 * sin(t * 4.2)
	for _, rec in pairs(bars) do
		for _, seg in ipairs(rec.segments) do
			spawn.tint(seg.glow, GLOW[1], GLOW[2], GLOW[3], 0.10 + 0.10 * k)
			spawn.tint(seg.core, CORE[1], CORE[2], CORE[3], 0.65 + 0.35 * k)
		end
	end
end

function M.clear()
	clear()
	active = false
	t = 0
end

return M
