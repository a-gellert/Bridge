-- Grid snapping and beam length clamping (pure Lua).
local tuning = require("game.config.tuning")

local M = {}

local floor, sqrt = math.floor, math.sqrt

function M.snap(v, grid)
	grid = grid or tuning.GRID
	return floor(v / grid + 0.5) * grid
end

function M.snap_point(x, y, grid)
	return M.snap(x, grid), M.snap(y, grid)
end

local function dist(ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	return sqrt(dx * dx + dy * dy)
end
M.dist = dist

-- End point for a beam that starts at (sx, sy) and is aimed at (wx, wy):
--  1) an existing node near the aim point (within `tol`) if it is in reach,
--  2) otherwise the grid point closest to the aim, pulled back inside `max_len`.
-- `find_node(x, y, tol)` returns a node table {x, y} or nil. Returns x, y (or nil when nothing fits).
function M.beam_target(sx, sy, wx, wy, max_len, find_node, tol, grid)
	grid = grid or tuning.GRID
	local eps = 1e-6
	if find_node then
		local n = find_node(wx, wy, tol)
		if n and not (n.x == sx and n.y == sy) then
			local d = dist(sx, sy, n.x, n.y)
			if d <= max_len + eps and d >= tuning.MIN_BEAM then return n.x, n.y end
		end
	end
	local d = dist(sx, sy, wx, wy)
	if d < grid * 0.5 then return nil end -- still on the start joint
	local cx, cy = wx, wy
	if d > max_len then
		local k = max_len / d
		cx, cy = sx + (wx - sx) * k, sy + (wy - sy) * k
	end
	-- nearest grid point first, then the 4 cell corners around the clamped aim
	local best_x, best_y, best_d
	local gx0, gy0 = floor(cx / grid) * grid, floor(cy / grid) * grid
	local cands = {
		{ M.snap(cx, grid), M.snap(cy, grid) },
		{ gx0, gy0 }, { gx0 + grid, gy0 }, { gx0, gy0 + grid }, { gx0 + grid, gy0 + grid },
	}
	for _, c in ipairs(cands) do
		local len = dist(sx, sy, c[1], c[2])
		if len <= max_len + eps and len >= tuning.MIN_BEAM then
			local e = dist(cx, cy, c[1], c[2])
			if not best_d or e < best_d - 1e-9 then
				best_x, best_y, best_d = c[1], c[2], e
			end
		end
	end
	return best_x, best_y
end

return M
