-- Onboarding "ghost plan": the reference bridge drawn as translucent glowing bars in the
-- build plane on the first levels. Bars disappear one by one as the player repeats them,
-- so the deck is traced first and the braces/struts that hold it are taught next.
local spawn = require("world.spawn")
local materials = require("game.config.materials")
local tuning = require("game.config.tuning")

local M = {}

local atan2, sqrt, sin = math.atan2, math.sqrt, math.sin
local Z_GLOW = tuning.BUILD_PLANE_Z + 0.10 -- just in front of the terrain / beams
local Z_CORE = tuning.BUILD_PLANE_Z + 0.13
local CORE = { 0.72, 1.0, 1.0 }
local GLOW = { 0.25, 0.90, 1.0 }

local bars = {} -- solution index -> { core, glow, mat, deck }
local active = false
local fade = 0
local t = 0

local function remove(i)
	local rec = bars[i]
	if rec then
		spawn.delete(rec.core)
		spawn.delete(rec.glow)
		bars[i] = nil
	end
end

local function clear()
	for i in pairs(bars) do remove(i) end
	bars = {}
end

-- Two stacked quads per beam: a soft wide halo and a bright core line.
local function place(rec, s)
	local dx, dy = s[4] - s[2], s[5] - s[3]
	local len = sqrt(dx * dx + dy * dy)
	local cx, cy = (s[2] + s[4]) * 0.5, (s[3] + s[5]) * 0.5
	local a = atan2(dy, dx)
	local core_w, glow_w = rec.deck and 0.34 or 0.20, rec.deck and 0.92 or 0.60
	local pad = rec.deck and 0.14 or 0.06
	spawn.set("zone", rec.core, cx, cy, Z_CORE, a, len + pad, core_w, 1)
	spawn.set("zone", rec.glow, cx, cy, Z_GLOW, a, len + pad + 0.2, glow_w, 1)
end

-- Reconcile the ghost with the design: built beams (same joints, any material) lose their bar.
function M.sync(session)
	local show = session and session.state == "build" and session.guide
		and session.level and session.level.solution ~= nil
	active = show and true or false
	if not show then
		clear()
		fade = 0
		return
	end
	local sol = session.level.solution
	for i, s in ipairs(sol) do
		if session.guide_has_beam(s) then
			remove(i)
		else
			local rec = bars[i]
			if not rec or rec.mat ~= s[1] then
				remove(i)
				rec = {
					mat = s[1],
					deck = materials.get(s[1]).drivable and true or false,
					core = spawn.create("zone", 0, 0, Z_CORE),
					glow = spawn.create("zone", 0, 0, Z_GLOW),
				}
				bars[i] = rec
				place(rec, s)
			end
		end
	end
	for i in pairs(bars) do
		if i > #sol then remove(i) end
	end
end

-- Pulse the hologram; fades in when the level opens and blinks out on GO.
function M.update(dt)
	if not active then return end
	t = t + dt
	fade = math.min(1, fade + dt * 2.4)
	local k = 0.5 + 0.5 * sin(t * 3.2)
	for _, rec in pairs(bars) do
		spawn.tint(rec.glow, GLOW[1], GLOW[2], GLOW[3], (0.16 + 0.08 * k) * fade)
		spawn.tint(rec.core, CORE[1], CORE[2], CORE[3], (0.55 + 0.18 * k) * fade)
	end
end

function M.clear()
	clear()
	active = false
	fade = 0
end

return M
