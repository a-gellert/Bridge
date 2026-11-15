-- Virtual GUI canvas shared by the render script and the GUI: the shorter screen side is always
-- 720 virtual units, the longer one stretches with the window. Portrait (phones held upright) and
-- landscape (desktop, tablets, phones sideways) get different HUD layouts.
local M = {}

M.SHORT = 720

-- Safe-area insets (notches, rounded corners, gesture bar) as fractions of the window.
M.safe = { top = 0, bottom = 0, left = 0, right = 0 }

function M.virtual_size(w, h)
	if not w or not h or w <= 0 or h <= 0 then return 1280, 720, false end
	if w < h then
		local s = w / M.SHORT
		return M.SHORT, h / s, true
	end
	local s = h / M.SHORT
	return w / s, M.SHORT, false
end

function M.set_safe_insets(top, bottom, left, right)
	M.safe.top = top or 0
	M.safe.bottom = bottom or 0
	M.safe.left = left or 0
	M.safe.right = right or 0
end

-- Insets in virtual canvas units for the current canvas size.
function M.insets(vw, vh)
	return M.safe.left * vw, M.safe.right * vw, M.safe.top * vh, M.safe.bottom * vh
end

-- Convenience margins for HUD corners.
function M.margins(vw, vh, base)
	base = base or 0
	local l, r, t, b = M.insets(vw, vh)
	return base + math.max(l, r), base + math.max(l, r), base + t, base + b
end

return M
