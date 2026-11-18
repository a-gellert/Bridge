-- GUI toolkit on top of Druid: palette, node factories, buttons, bars, stars, toasts.
-- Nodes are created in code (the .gui file is empty) and laid out in virtual units (gui/layout.lua).
local druid = require("druid.druid")
local druid_style = require("gui.druid_style")
local audio = require("platform.audio")

local M = {}

local V3, V4 = vmath.vector3, vmath.vector4

M.TEX = "ui"
M.FONT = "main"
M.FONT_SIZE = 48

local function hex(h, a)
	return V4(tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, a or 1)
end
M.hex = hex

M.WHITE = V4(1, 1, 1, 1)
M.CLEAR = V4(1, 1, 1, 0)
M.INK = hex("#1A202C")
M.PANEL = hex("#2D3748", 0.94)
M.PANEL_LT = hex("#3D4A5C", 0.96)
M.CARD = hex("#323A4E", 1)
M.DIM = hex("#A0AEC0")
M.GREEN = hex("#4EBAA6")     -- Two Dots Mint
M.YELLOW = hex("#F6B73C")    -- Two Dots Mustard
M.ORANGE = hex("#F9A36B")    -- Two Dots Peach
M.RED = hex("#F57268")       -- Two Dots Coral
M.BLUE = hex("#63B3ED")      -- Two Dots Sky
M.CYAN = hex("#4FD1C5")      -- Two Dots Soft Cyan
M.PURPLE = hex("#9F7AEA")    -- Two Dots Lavender/Purple
M.STAR = hex("#F6B73C")      -- Two Dots Mustard
M.STAR_OFF = hex("#718096")  -- Two Dots Slate Slot
M.BTN_LIGHT = hex("#FFFFFF") -- Two Dots Light Tactile Card
M.BTN_SEL_MAT = hex("#FFFBF0")
M.BTN_SEL_VEH = hex("#F0F8FF")
M.BTN_SEL_ERA = hex("#FFF2F0")

M.druid = nil
M.context = nil

function M.init(context)
	M.context = context
	druid.set_default_style(druid_style)
	druid_style.on_settle = function(node) M.resume_pulse(node) end
	druid.set_sound_function(function(id) audio.play(id, 0.6) end)
end

-- Fresh Druid instance for a rebuilt screen (the previous one must be finalized first).
function M.new_druid()
	if M.druid then M.druid:final() end
	M.druid = druid.new(M.context)
	return M.druid
end

function M.final()
	if M.druid then M.druid:final() end
	M.druid = nil
end

-- ------------------------------------------------------------------ nodes
function M.pane(parent, x, y)
	local n = gui.new_box_node(V3(x or 0, y or 0, 0), V3(1, 1, 0))
	gui.set_visible(n, false)
	if parent then gui.set_parent(n, parent) end
	return n
end

function M.box(parent, image, x, y, w, h, color)
	local n = gui.new_box_node(V3(x, y, 0), V3(w, h, 0))
	gui.set_texture(n, M.TEX)
	gui.play_flipbook(n, image or "white")
	gui.set_color(n, color or M.WHITE)
	gui.set_inherit_alpha(n, true)
	if parent then gui.set_parent(n, parent) end
	return n
end

function M.panel(parent, x, y, w, h, color, radius)
	local n = M.box(parent, "panel", x, y, w, h, color or M.PANEL)
	local r = radius or 18
	gui.set_slice9(n, V4(r, r, r, r))
	return n
end

function M.text(parent, str, x, y, size, color, pivot)
	local n = gui.new_text_node(V3(x, y, 0), str or "")
	gui.set_font(n, M.FONT)
	local s = (size or 30) / M.FONT_SIZE
	gui.set_scale(n, V3(s, s, 1))
	gui.set_color(n, color or M.WHITE)
	gui.set_outline(n, M.INK)
	gui.set_shadow(n, V4(0, 0, 0, 0))
	gui.set_pivot(n, pivot or gui.PIVOT_CENTER)
	gui.set_inherit_alpha(n, true)
	gui.set_size(n, V3(4000, M.FONT_SIZE * 1.5, 0))
	if parent then gui.set_parent(n, parent) end
	return n
end

-- Text that shrinks to fit `max_w` (virtual px); optional multi-line wrap with `lines`.
function M.label(parent, str, x, y, size, color, max_w, lines, pivot)
	local n = M.text(parent, str, x, y, size, color, pivot)
	local comp
	if max_w then
		local s = (size or 30) / M.FONT_SIZE
		lines = lines or 1
		gui.set_line_break(n, lines > 1)
		gui.set_size(n, V3(max_w / s, M.FONT_SIZE * (lines > 1 and (1.2 * lines + 0.2) or 1.4), 0))
		if M.druid then comp = M.druid:new_text(n, str, "downscale") end
	end
	return n, comp
end

-- Update a label created by M.label (keeps the fit).
function M.set_label(n, comp, str)
	if comp then comp:set_text(str) else gui.set_text(n, str) end
end

local PRIMITIVES = {
	white = true,
	panel = true,
	circle = true,
	ring = true,
	glow = true,
	btn = true,
}

function M.icon(parent, image, x, y, size, color)
	local c = color or M.WHITE
	if not PRIMITIVES[image] and color and color ~= M.WHITE and color ~= M.DIM then
		if c.w < 0.99 then
			c = V4(1, 1, 1, c.w)
		else
			c = M.WHITE
		end
	end
	return M.box(parent, image, x, y, size, size, c)
end

function M.delete(n)
	if n then gui.delete_node(n) end
end

-- ------------------------------------------------------------------ buttons
-- Generic Druid button on any node. opts: disabled, silent
function M.button(node, fn, opts)
	opts = opts or {}
	local b = M.druid:new_button(node, function() if fn then fn() end end)
	b.silent = opts.silent
	if opts.disabled then b:set_enabled(false) end
	return b
end

-- Rounded button with optional icon and label.
-- opts: color, icon, icon_size, text_color, size (text), disabled, silent, well
function M.btn(parent, x, y, w, h, label, fn, opts)
	opts = opts or {}
	local is_light = opts.color == nil or opts.color == M.WHITE or opts.color == M.BTN_LIGHT
	local bg_color = opts.color or M.BTN_LIGHT
	local node = M.box(parent, "btn", x, y, w, h, bg_color)
	local r = math.min(20, math.floor(math.min(w, h) * 0.4))
	gui.set_slice9(node, V4(r, r, r, r + 8))
	local has_label = label and label ~= ""
	local icon_node
	if opts.icon then
		local isz = opts.icon_size or math.min(h - 26, 44)
		local ix = has_label and (-w / 2 + 16 + isz / 2) or 0
		-- If button is colored (not light), add an inner contrast well behind the icon!
		if not is_light and opts.well ~= false then
			local well_sz = isz + 10
			M.box(node, "circle", ix, 4, well_sz, well_sz, hex("#FFFFFF", 0.94))
		end
		icon_node = M.icon(node, opts.icon, ix, 4, isz, opts.icon_color or M.WHITE)
	end
	local txt
	if has_label then
		local isz = opts.icon and (opts.icon_size or math.min(h - 26, 44)) + 12 or 0
		local def_text_color = is_light and M.INK or M.WHITE
		txt = M.label(node, label, isz / 2, 4, opts.size or 30, opts.text_color or def_text_color, w - 24 - isz)
	end
	local b = M.button(node, fn, opts)
	return node, b, txt, icon_node
end

-- Round icon button (Two Dots booster style with white outer stroke & inner contrast well).
function M.round(parent, x, y, size, image, fn, opts)
	opts = opts or {}
	local is_light = opts.color == nil or opts.color == M.WHITE or opts.color == M.BTN_LIGHT
	local bg_color = opts.color or M.BTN_LIGHT
	local node = M.box(parent, "circle", x, y, size, size, bg_color)
	if opts.stroke ~= false then
		local stroke_col = is_light and hex("#D2DAE4", 0.9) or hex("#FFFFFF", 0.95)
		M.box(node, "ring", 0, 0, size, size, opts.stroke_color or stroke_col)
	end
	if not is_light and opts.well ~= false then
		local well_sz = size * 0.74
		M.box(node, "circle", 0, 0, well_sz, well_sz, hex("#FFFFFF", 0.94))
	end
	local icon_sz = opts.icon_size or (size * 0.52)
	local icon_node = M.icon(node, image, 0, 0, icon_sz, opts.icon_color or M.WHITE)
	local b = M.button(node, fn, opts)
	return node, b, icon_node
end

-- Absorbs touches on a panel so they never reach the world behind it.
function M.blocker(node)
	if M.druid then M.druid:new_blocker(node) end
	return node
end

-- ------------------------------------------------------------------ widgets
-- Horizontal bar; returns { bg, fill, w } (fill scales from the left edge).
function M.bar(parent, x, y, w, h, color, bg)
	local holder = M.pane(parent, x, y)
	local back = M.panel(holder, 0, 0, w, h, bg or M.hex("#151926", 0.9), h / 2)
	local fill = M.panel(holder, -w / 2, 0, w, h, color or M.GREEN, h / 2)
	gui.set_pivot(fill, gui.PIVOT_W)
	return { holder = holder, bg = back, fill = fill, w = w, h = h }
end

function M.set_bar(bar, ratio, color)
	ratio = math.max(0, math.min(1, ratio or 0))
	gui.set_size(bar.fill, V3(math.max(bar.h, bar.w * ratio), bar.h, 0))
	gui.set_enabled(bar.fill, ratio > 0.001)
	if color then gui.set_color(bar.fill, color) end
end

-- Row of 3 stars; returns the star nodes.
function M.stars(parent, x, y, size, count, gap)
	local out = {}
	gap = gap or size * 1.05
	for i = 1, 3 do
		local n = M.icon(parent, i <= count and "star" or "star_slot", x + (i - 2) * gap, y, size, M.WHITE)
		out[i] = n
	end
	return out
end

function M.set_star(n, on)
	gui.play_flipbook(n, on and "star" or "star_slot")
	gui.set_color(n, M.WHITE)
end

-- Rest scale of nodes that are popping in or pulsing (weak keys: deleted nodes drop out).
-- pulse() must breathe around the rest scale, not around the 1% scale a running pop() starts from.
local rest = setmetatable({}, { __mode = "k" })
local pulses = setmetatable({}, { __mode = "k" })

local function rest_scale(n)
	return rest[n] or gui.get_scale(n)
end

-- Pop-in animation
function M.pop(n, delay)
	local s = rest_scale(n)
	rest[n] = s
	gui.set_scale(n, s * 0.01)
	gui.animate(n, gui.PROP_SCALE, s, gui.EASING_OUTBACK, 0.35, delay or 0, function()
		local p = pulses[n]
		if p then M.pulse(n, p.k, p.period) end
	end)
end

function M.fade_in(n, time, delay)
	local c = gui.get_color(n)
	local a = c.w
	c.w = 0
	gui.set_color(n, c)
	gui.animate(n, "color.w", a, gui.EASING_OUTQUAD, time or 0.25, delay or 0)
end

-- Breathing scale loop around the node's rest scale. Safe to call right after pop() (it starts
-- when the pop lands) and restarted by the Druid button style after a press / hover.
function M.pulse(n, k, period)
	local s = rest_scale(n)
	rest[n] = s
	pulses[n] = { k = k or 1.06, period = period or 0.7 }
	if gui.get_scale(n).x < s.x * 0.5 then return end -- still popping in: pop() starts the pulse
	gui.animate(n, gui.PROP_SCALE, s * (k or 1.06), gui.EASING_INOUTSINE, period or 0.7, 0, nil, gui.PLAYBACK_LOOP_PINGPONG)
end

-- Druid style hook: a pressed / hovered button settled back to its rest scale.
function M.resume_pulse(n)
	local p = pulses[n]
	if p then
		gui.set_scale(n, rest[n])
		M.pulse(n, p.k, p.period)
	end
end

return M
