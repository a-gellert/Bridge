-- Level geometry -> static collision segments + helpers (pure Lua).
-- Level shapes (all in meters):
--   ground = { {x0, x1, top, bottom?}, ... }   solid columns; the surface sits DECK_HALF above `top`
--                                                so a road built from an anchor at `top` is flush with it
--   ramps  = { {x0, x1, y0, y1, bottom?}, ... } sloped columns from (x0, y0) to (x1, y1), flush like ground
--   blocks = { {x0, y0, x1, y1}, ... }          floating rocks / ceilings / pillars (exact box, no offset)
local tuning = require("game.config.tuning")

local M = {}

local DEFAULT_BOTTOM = -40

local function seg(list, x1, y1, x2, y2, kind)
	list[#list + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, kind = kind }
end

-- Collision segments of the level with the deck offset `dh` applied to ground/ramp tops.
-- Side walls of neighbouring columns are trimmed to their exposed part: a hidden inner wall would
-- shove anything that dips below the surface sideways.
local function build_segments(level, dh)
	local segments = {}
	local cols = {}
	for _, g in ipairs(level.ground or {}) do
		cols[#cols + 1] = { x0 = g[1], x1 = g[2], ya = g[3] + dh, yb = g[3] + dh, bottom = g[4] or DEFAULT_BOTTOM }
	end
	for _, r in ipairs(level.ramps or {}) do
		cols[#cols + 1] = { x0 = r[1], x1 = r[2], ya = r[3] + dh, yb = r[4] + dh, bottom = r[5] or DEFAULT_BOTTOM }
	end
	-- height of the neighbour column touching x from the given side (nil = none)
	local function neighbour_top(x, side)
		local best
		for _, c in ipairs(cols) do
			local h
			if side == "left" and math.abs(c.x1 - x) < 1e-6 then h = c.yb
			elseif side == "right" and math.abs(c.x0 - x) < 1e-6 then h = c.ya end
			if h and (not best or h > best) then best = h end
		end
		return best
	end
	for _, c in ipairs(cols) do
		seg(segments, c.x0, c.ya, c.x1, c.yb, "top")
		local lb = math.max(c.bottom, neighbour_top(c.x0, "left") or c.bottom)
		if lb < c.ya - 1e-6 then seg(segments, c.x0, lb, c.x0, c.ya, "side") end
		local rb = math.max(c.bottom, neighbour_top(c.x1, "right") or c.bottom)
		if rb < c.yb - 1e-6 then seg(segments, c.x1, c.yb, c.x1, rb, "side") end
	end
	for _, b in ipairs(level.blocks or {}) do
		local x0, y0, x1, y1 = b[1], b[2], b[3], b[4]
		seg(segments, x0, y1, x1, y1, "top")
		seg(segments, x1, y1, x1, y0, "side")
		seg(segments, x1, y0, x0, y0, "bottom")
		seg(segments, x0, y0, x0, y1, "side")
	end
	return segments
end

-- Returns { segments, node_segments, solids }:
--   segments      wheels / vehicle collide with these (ground surface raised by DECK_HALF)
--   node_segments bridge joints rest on these (raw surface, so a road laid on the ground stays flush)
--   solids        convex shapes used for point tests and visuals
function M.build(level)
	local dh = tuning.DECK_HALF
	local solids = {}
	local segments = build_segments(level, dh)
	local node_segments = build_segments(level, 0)
	for _, g in ipairs(level.ground or {}) do
		local x0, x1, top, bottom = g[1], g[2], g[3] + dh, g[4] or DEFAULT_BOTTOM
		solids[#solids + 1] = { kind = "ground", x0 = x0, x1 = x1, y0 = bottom, y1 = top }
	end
	for _, r in ipairs(level.ramps or {}) do
		local x0, x1, y0, y1, bottom = r[1], r[2], r[3] + dh, r[4] + dh, r[5] or DEFAULT_BOTTOM
		solids[#solids + 1] = { kind = "ramp", x0 = x0, x1 = x1, y0 = bottom, y1 = math.max(y0, y1), ya = y0, yb = y1 }
	end
	for _, b in ipairs(level.blocks or {}) do
		solids[#solids + 1] = { kind = "block", x0 = b[1], x1 = b[3], y0 = b[2], y1 = b[4] }
	end
	return { segments = segments, node_segments = node_segments, solids = solids }
end

-- Top surface height of solid `s` at x (nil if x is outside it).
local function top_at(s, x)
	if x < s.x0 or x > s.x1 then return nil end
	if s.kind == "ramp" then
		local t = (x - s.x0) / (s.x1 - s.x0)
		return s.ya + (s.yb - s.ya) * t
	end
	return s.y1
end

-- Highest surface at x below `below` (default: anything). Returns nil over a gap.
-- Floating blocks are ignored unless include_blocks is set (spawning under an overhang).
function M.height_at(geo, x, below, include_blocks)
	local best
	for _, s in ipairs(geo.solids) do
		local h = (include_blocks or s.kind ~= "block") and top_at(s, x) or nil
		if h and (not below or h <= below) and (not best or h > best) then best = h end
	end
	return best
end

-- Is the point strictly inside some solid (with a margin)? Used to forbid nodes inside rock.
function M.point_inside(geo, x, y, margin)
	margin = margin or 0.05
	for _, s in ipairs(geo.solids) do
		if x > s.x0 + margin and x < s.x1 - margin and y > s.y0 + margin then
			local h = top_at(s, x)
			if s.kind == "block" then
				if y < s.y1 - margin then return true end
			elseif h and y < h - margin - tuning.DECK_HALF then
				return true
			end
		end
	end
	return false
end

return M
