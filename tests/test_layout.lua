-- Virtual GUI canvas: wide screens keep the 720-unit design size, while square-ish windows grow
-- it so the HUD does not take over the playfield.
local layout = require("gui.layout")

local function near(actual, expected, what)
	assert(math.abs(actual - expected) < 1e-6, what .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

-- 16:9 and wider: the canvas is exactly the 720p design space
local vw, vh, portrait = layout.virtual_size(1280, 720)
near(vw, 1280, "16:9 width")
near(vh, 720, "16:9 height")
assert(not portrait, "16:9 is landscape")

vw, vh = layout.virtual_size(1920, 1080)
near(vw, 1280, "widescreen width")
near(vh, 720, "widescreen height")

-- square: short side grows to NARROW_SHORT, so every HUD widget shrinks by the same factor
local canvas = layout.NARROW_SHORT
vw, vh = layout.virtual_size(900, 900)
near(vw, canvas, "square width")
near(vh, canvas, "square height")

-- tablets / near-square portrait use the same canvas, so resizing across 1:1 does not jump
local nw, nh = layout.virtual_size(899, 900)
assert(math.abs(nw - canvas) < 2 and math.abs(nh - canvas) < 2, "no layout jump at the square boundary")

-- phone portrait stays at the original 720-unit width
vw, vh, portrait = layout.virtual_size(405, 720)
near(vw, 720, "portrait width")
near(vh, 1280, "portrait height")
assert(portrait, "405x720 is portrait")

-- invalid sizes fall back to the desktop design canvas
vw, vh, portrait = layout.virtual_size(0, 0)
near(vw, 1280, "fallback width")
near(vh, 720, "fallback height")
assert(not portrait, "fallback is landscape")
