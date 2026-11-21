-- GUI toolkit on top of Druid: palette, node factories, buttons, bars, stars, toasts.
-- Nodes are created in code (the .gui file is empty) and laid out in virtual units (gui/layout.lua).
local druid = require("druid.druid")
local druid_style = require("gui.druid_style")
local audio = require("platform.audio")
local icon_sizes = require("gui.icon_sizes")
local skins = require("game.config.skins")
local vehicles = require("game.config.vehicles")
local progress = require("game.core.progress")

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
M.INK = hex("#1B2030")
M.PANEL = hex("#262D40", 0.96)
M.PANEL_LT = hex("#39425E", 0.96)
M.CARD = hex("#323A52", 1)
M.DIM = hex("#A9B3C9")
M.GREEN = hex("#35C97E")
M.YELLOW = hex("#FFC93C")
M.ORANGE = hex("#FF8A1C")
M.RED = hex("#E5484D")
M.BLUE = hex("#3E8EF7")
M.PURPLE = hex("#8E6CF0")
M.STAR = hex("#FFD23F")
M.STAR_OFF = hex("#7D87A8")

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

-- Icon fitted into a size x size box, keeping the image's aspect ratio (gui/icon_sizes.lua).
function M.icon(parent, image, x, y, size, color)
	local s = icon_sizes[image]
	local w, h = size, size
	if s and s[1] ~= s[2] then
		if s[1] > s[2] then h = size * s[2] / s[1] else w = size * s[1] / s[2] end
	end
	return M.box(parent, image, x, y, w, h, color)
end

local function rgba(t)
	return t and vmath.vector4(t[1], t[2], t[3], 1) or M.WHITE
end

-- Vehicle preview stacked from the garage layers (tools/gen/ui.js renders them in one frame):
-- outline, body, the white paint layer coloured with the paint, wheels tinted by the wheel skin,
-- then the topper — the same recipe the world uses on the models. `sk` overrides the
-- player's current choice per kind: { body = item, wheel = item, topper = item } (skins.lua items).
-- Returns the holder node; `w` is the preview width (height follows the image aspect).
function M.vehicle(parent, vehicle_id, x, y, w, sk)
	sk = sk or {}
	local function pick(kind)
		return sk[kind] or skins.get(kind, progress.skin_for(kind, vehicle_id))
	end
	local body, wheel, topper = pick("body"), pick("wheel"), pick("topper")
	local g = "gv_" .. vehicle_id
	local ref = icon_sizes[g .. "_sil"]
	assert(ref, "ui.vehicle: no garage layers for vehicle '" .. tostring(vehicle_id) .. "'")
	local k = w / ref[5]
	local h = ref[6] * k
	local holder = M.pane(parent, x, y)
	-- layers are trimmed to their opaque box: place each at its offset inside the shared frame
	local function layer(name, color)
		local s = icon_sizes[name]
		if not s then return end
		local cx = (s[3] + s[1] / 2 - s[5] / 2) * k
		local cy = -(s[4] + s[2] / 2 - s[6] / 2) * k
		M.box(holder, name, cx, cy, s[1] * k, s[2] * k, color)
	end
	layer(g .. "_sil")
	layer(g .. "_body")
	layer(g .. "_paint", rgba(skins.paint_color(vehicles.get(vehicle_id), body)))
	local big = wheel and wheel.scale and wheel.scale > 1
	layer(g .. (big and "_wheel_xl" or "_wheel"), rgba(wheel and wheel.tint))
	if topper and topper.visual then layer(g .. "_" .. topper.id, rgba(topper.tint)) end
	return holder, h
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
-- opts: color, icon, icon_size, text_color, size (text), disabled, silent
function M.btn(parent, x, y, w, h, label, fn, opts)
	opts = opts or {}
	local node = M.box(parent, "btn", x, y, w, h, opts.color or M.PANEL_LT)
	local r = math.min(20, math.floor(math.min(w, h) * 0.4))
	gui.set_slice9(node, V4(r, r, r, r + 8))
	local has_label = label and label ~= ""
	local icon_node
	if opts.icon then
		local isz = opts.icon_size or math.min(h - 26, 44)
		local ix = has_label and (-w / 2 + 16 + isz / 2) or 0
		icon_node = M.icon(node, opts.icon, ix, 4, isz, opts.icon_color or M.WHITE)
	end
	local txt
	if has_label then
		local isz = opts.icon and (opts.icon_size or math.min(h - 26, 44)) + 12 or 0
		txt = M.label(node, label, isz / 2, 4, opts.size or 30, opts.text_color or M.WHITE, w - 24 - isz)
	end
	local b = M.button(node, fn, opts)
	return node, b, txt, icon_node
end

-- Round icon button.
function M.round(parent, x, y, size, image, fn, opts)
	opts = opts or {}
	local node = M.box(parent, "circle", x, y, size, size, opts.color or M.PANEL_LT)
	M.icon(node, image, 0, 0, size * 0.56, opts.icon_color or M.WHITE)
	local b = M.button(node, fn, opts)
	return node, b
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
	-- thin bars use the 12 px capsule image (round ends at any length); thick ones the panel
	local function shape(node_color, px)
		local n
		if h <= 14 then
			n = M.box(holder, "pill", px, 0, w, h, node_color)
			gui.set_slice9(n, V4(6, 6, 6, 6))
		else
			n = M.panel(holder, px, 0, w, h, node_color, h / 2)
		end
		return n
	end
	local back = shape(bg or M.hex("#151926", 0.9), 0)
	local fill = shape(color or M.GREEN, -w / 2)
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
		local n = M.icon(parent, i <= count and "star" or "star_slot", x + (i - 2) * gap, y, size, i <= count and M.STAR or M.STAR_OFF)
		out[i] = n
	end
	return out
end

function M.set_star(n, on)
	gui.play_flipbook(n, on and "star" or "star_slot")
	gui.set_color(n, on and M.STAR or M.STAR_OFF)
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
