-- Virtual GUI canvas shared by the render script and the GUI: the shorter screen side is always
-- 720 virtual units, the longer one stretches with the window. Portrait (phones held upright) and
-- landscape (desktop, tablets, phones sideways) get different HUD layouts.
local M = {}

M.SHORT = 720

function M.virtual_size(w, h)
	if not w or not h or w <= 0 or h <= 0 then return 1280, 720, false end
	if w < h then
		local s = w / M.SHORT
		return M.SHORT, h / s, true
	end
	local s = h / M.SHORT
	return w / s, M.SHORT, false
end

return M
