-- Virtual GUI canvas shared by the render script and the GUI. On a wide screen (16:9 and wider)
-- the shorter side is 720 virtual units. Towards a square window the canvas grows to
-- NARROW_SHORT, so the HUD keeps its physical size instead of taking over the playfield:
-- a 900x900 window gets 1200x1200 virtual units (widgets shrink by 40%), while 1280x720 and
-- portrait phones stay exactly as designed. Portrait (phones held upright) and landscape
-- (desktop, tablets, phones sideways) still get different HUD layouts.
local M = {}

M.SHORT = 720
M.NARROW_SHORT = 1200
M.WIDE_ASPECT = 16 / 9
M.TALL_ASPECT = 9 / 16

-- Safe-area insets (notches, rounded corners, gesture bar) as fractions of the window.
M.safe = { top = 0, bottom = 0, left = 0, right = 0 }

-- 0 on a widescreen canvas, 1 at a square one; clamps outside that range.
local function square_blend(aspect)
	local t
	if aspect < 1 then
		t = (aspect - M.TALL_ASPECT) / (1 - M.TALL_ASPECT)
	else
		t = (M.WIDE_ASPECT - aspect) / (M.WIDE_ASPECT - 1)
	end
	return math.max(0, math.min(1, t))
end

function M.virtual_size(w, h)
	if not w or not h or w <= 0 or h <= 0 then return 1280, 720, false end
	local aspect = w / h
	local short = M.SHORT + (M.NARROW_SHORT - M.SHORT) * square_blend(aspect)
	if w < h then
		return short, h * short / w, true
	end
	return w * short / h, short, false
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
