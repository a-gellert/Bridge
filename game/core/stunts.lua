-- Stunt combo scoring, kept pure so the headless tests can exercise it.
-- A stunt is any boost, bounce, portal, long air or clean flip. Each one within the
-- combo window raises the multiplier; the run pays a small stunt bonus into the garage fund.
local M = {}

M.WINDOW = 4.0       -- seconds to chain the next stunt
M.MAX_MULT = 5.0
M.MAX_CASH = 60      -- per run, so a lucky chain cannot inflate the garage economy

function M.new()
	return { score = 0, combo = 0, max_combo = 0, combo_t = 0, cash = 0 }
end

function M.multiplier(s)
	if not s or s.combo <= 0 then return 1 end
	return math.min(M.MAX_MULT, 1 + (s.combo - 1) * 0.35)
end

-- Register a stunt. Returns the awarded points and the multiplier at that moment.
function M.add(s, kind, points)
	points = math.max(0, math.floor((points or 0) + 0.5))
	s.combo = s.combo + 1
	if s.combo > s.max_combo then s.max_combo = s.combo end
	s.combo_t = M.WINDOW
	local mult = M.multiplier(s)
	local gain = math.floor(points * mult + 0.5)
	s.score = s.score + gain
	s.cash = math.min(M.MAX_CASH, s.cash + math.floor(gain / 10))
	return gain, mult, kind
end

function M.tick(s, dt)
	if s.combo_t <= 0 then
		s.combo = 0
		return
	end
	s.combo_t = s.combo_t - dt
	if s.combo_t <= 0 then s.combo = 0 end
end

return M
