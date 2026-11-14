-- Minimal Defold API mock for headless runtime tests of the game scripts (fengari / Lua 5.3).
-- It implements just enough of vmath, gui, go, factory, msg, sys, sound, window, timer and render to
-- run world.script, app.gui_script and the render script, plus a tiny Druid stand-in.
local M = {}

-- ------------------------------------------------------------------ hash
local hashes = {}
function hash(s)
	local h = hashes[s]
	if not h then
		h = setmetatable({ name = s }, { __tostring = function(t) return "hash(" .. t.name .. ")" end })
		hashes[s] = h
	end
	return h
end

-- ------------------------------------------------------------------ vmath
vmath = {}
local V3mt, V4mt, Qmt, Mmt = {}, {}, {}, {}

local function v3(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3mt) end
local function v4(x, y, z, w) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 0 }, V4mt) end
V3mt.__add = function(a, b) return v3(a.x + b.x, a.y + b.y, a.z + b.z) end
V3mt.__sub = function(a, b) return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
V3mt.__unm = function(a) return v3(-a.x, -a.y, -a.z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.x, a * b.y, a * b.z) end
	if type(b) == "number" then return v3(a.x * b, a.y * b, a.z * b) end
	return v3(a.x * b.x, a.y * b.y, a.z * b.z)
end
V4mt.__add = function(a, b) return v4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w) end
V4mt.__mul = function(a, b)
	if type(a) == "number" then return v4(a * b.x, a * b.y, a * b.z, a * b.w) end
	if type(b) == "number" then return v4(a.x * b, a.y * b, a.z * b, a.w * b) end
	return v4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w)
end

function vmath.vector3(x, y, z)
	if type(x) == "table" then return v3(x.x, x.y, x.z) end
	if x and y == nil then return v3(x, x, x) end
	return v3(x, y, z)
end
function vmath.vector4(x, y, z, w)
	if type(x) == "table" then return v4(x.x, x.y, x.z, x.w) end
	if x and y == nil then return v4(x, x, x, x) end
	return v4(x, y, z, w)
end
function vmath.quat(x, y, z, w) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 1 }, Qmt) end
function vmath.quat_rotation_z(a) return vmath.quat(0, 0, math.sin(a / 2), math.cos(a / 2)) end
function vmath.rotate(q, v)
	-- v' = q v q*
	local qx, qy, qz, qw = q.x, q.y, q.z, q.w
	local ix = qw * v.x + qy * v.z - qz * v.y
	local iy = qw * v.y + qz * v.x - qx * v.z
	local iz = qw * v.z + qx * v.y - qy * v.x
	local iw = -qx * v.x - qy * v.y - qz * v.z
	return v3(ix * qw + iw * -qx + iy * -qz - iz * -qy, iy * qw + iw * -qy + iz * -qx - ix * -qz, iz * qw + iw * -qz + ix * -qy - iy * -qx)
end

-- matrices: m[r][c], column vectors
local function mat(rows) return setmetatable({ m = rows }, Mmt) end
local function ident() return mat({ { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } }) end
Mmt.__mul = function(a, b)
	if getmetatable(b) == V4mt then
		local r = {}
		local v = { b.x, b.y, b.z, b.w }
		for i = 1, 4 do r[i] = a.m[i][1] * v[1] + a.m[i][2] * v[2] + a.m[i][3] * v[3] + a.m[i][4] * v[4] end
		return v4(r[1], r[2], r[3], r[4])
	end
	local out = {}
	for i = 1, 4 do
		out[i] = {}
		for j = 1, 4 do
			local s = 0
			for k = 1, 4 do s = s + a.m[i][k] * b.m[k][j] end
			out[i][j] = s
		end
	end
	return mat(out)
end
vmath.matrix4 = ident
function vmath.matrix4_look_at(eye, target, up)
	local f = target - eye
	local fl = math.sqrt(f.x * f.x + f.y * f.y + f.z * f.z)
	f = f * (1 / fl)
	local s = v3(f.y * up.z - f.z * up.y, f.z * up.x - f.x * up.z, f.x * up.y - f.y * up.x)
	local sl = math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z)
	s = s * (1 / sl)
	local u = v3(s.y * f.z - s.z * f.y, s.z * f.x - s.x * f.z, s.x * f.y - s.y * f.x)
	return mat({
		{ s.x, s.y, s.z, -(s.x * eye.x + s.y * eye.y + s.z * eye.z) },
		{ u.x, u.y, u.z, -(u.x * eye.x + u.y * eye.y + u.z * eye.z) },
		{ -f.x, -f.y, -f.z, (f.x * eye.x + f.y * eye.y + f.z * eye.z) },
		{ 0, 0, 0, 1 },
	})
end
function vmath.matrix4_perspective(fov, aspect, near, far)
	local f = 1 / math.tan(fov / 2)
	return mat({
		{ f / aspect, 0, 0, 0 },
		{ 0, f, 0, 0 },
		{ 0, 0, (far + near) / (near - far), 2 * far * near / (near - far) },
		{ 0, 0, -1, 0 },
	})
end
function vmath.matrix4_orthographic(l, r, b, t, n, f)
	return mat({
		{ 2 / (r - l), 0, 0, -(r + l) / (r - l) },
		{ 0, 2 / (t - b), 0, -(t + b) / (t - b) },
		{ 0, 0, -2 / (f - n), -(f + n) / (f - n) },
		{ 0, 0, 0, 1 },
	})
end
function vmath.inv(a)
	local n = 4
	local A, I = {}, {}
	for i = 1, n do
		A[i], I[i] = {}, {}
		for j = 1, n do A[i][j] = a.m[i][j]; I[i][j] = (i == j) and 1 or 0 end
	end
	for c = 1, n do
		local p = c
		for r = c + 1, n do if math.abs(A[r][c]) > math.abs(A[p][c]) then p = r end end
		A[c], A[p] = A[p], A[c]
		I[c], I[p] = I[p], I[c]
		local d = A[c][c]
		assert(math.abs(d) > 1e-12, "singular matrix")
		for j = 1, n do A[c][j] = A[c][j] / d; I[c][j] = I[c][j] / d end
		for r = 1, n do
			if r ~= c then
				local k = A[r][c]
				for j = 1, n do A[r][j] = A[r][j] - k * A[c][j]; I[r][j] = I[r][j] - k * I[c][j] end
			end
		end
	end
	return mat(I)
end

-- ------------------------------------------------------------------ go / factory / msg
M.objects = {}
M.factory_names = {}
M.posted = {}
local next_id = 0

go = {}
local function obj(id)
	local o = M.objects[id]
	assert(o, "go: object does not exist: " .. tostring(id))
	return o
end
function go.set_position(p, id) obj(id).pos = vmath.vector3(p) end
function go.get_position(id) return vmath.vector3(obj(id).pos) end
function go.set_rotation(q, id) obj(id).rot = q end
function go.set_scale(s, id) obj(id).scale = type(s) == "number" and vmath.vector3(s) or vmath.vector3(s) end
function go.delete(id)
	assert(M.objects[id], "go.delete of a missing object " .. tostring(id))
	M.objects[id] = nil
end
function go.set(url, prop, value)
	local id = type(url) == "table" and url.path or url
	if type(id) == "string" and id:sub(1, 1) == "/" then return end -- component of a static object (sounds)
	local o = obj(id)
	assert(prop == "tint" or prop == "overlay" or prop == "speed", "unexpected property " .. tostring(prop))
	o.props[prop] = value
end

factory = {}
function factory.create(url, pos, rot, props, scale)
	local name = url:match("#(.+)$")
	assert(M.factory_names[name], "factory.create: unknown factory " .. tostring(url))
	next_id = next_id + 1
	local id = hash("/instance" .. next_id)
	M.objects[id] = { factory = name, pos = pos, rot = rot, scale = scale, props = {} }
	return id
end

msg = {}
function msg.post(url, id, data)
	M.posted[#M.posted + 1] = { url = url, id = id, data = data }
end
function msg.url(a, b, c) return { socket = a, path = b, fragment = c } end

-- ------------------------------------------------------------------ sys / window / sound / timer
M.window_w, M.window_h = 1280, 720
M.saved = {}
sys = {}
function sys.get_save_file(app, name) return app .. "/" .. name end
function sys.save(path, t) M.saved[path] = t return true end
function sys.load(path) return M.saved[path] or {} end
function sys.get_sys_info() return { system_name = "Windows", language = "ru", device_language = "ru-RU" } end
function sys.get_config_int(key, def)
	if key == "display.width" then return 1280 elseif key == "display.height" then return 720 end
	return def
end
function sys.get_config_number(key, def) return def end
function sys.get_config_string(key, def) return def end
window = {}
function window.get_size() return M.window_w, M.window_h end
M.sounds = {}
sound = {}
function sound.play(url, opts) M.sounds[#M.sounds + 1] = url end
function sound.stop(url) end
function sound.set_group_gain(group, g) end
M.timers = {}
timer = {}
function timer.delay(t, rep, cb) M.timers[#M.timers + 1] = { t = t, cb = cb } return #M.timers end
function M.tick_timers(dt)
	for i = #M.timers, 1, -1 do
		local tm = M.timers[i]
		tm.t = tm.t - dt
		if tm.t <= 0 then
			table.remove(M.timers, i)
			tm.cb()
		end
	end
end
socket = { gettime = function() return os.clock() end }
html5 = nil

-- ------------------------------------------------------------------ gui
gui = {}
gui.PIVOT_CENTER, gui.PIVOT_W, gui.PIVOT_E, gui.PIVOT_N, gui.PIVOT_S, gui.PIVOT_NW = "c", "w", "e", "n", "s", "nw"
gui.PROP_SCALE, gui.PROP_POSITION, gui.PROP_COLOR = "scale", "position", "color"
for _, e in ipairs({ "EASING_OUTQUAD", "EASING_OUTBACK", "EASING_OUTSINE", "EASING_INOUTSINE", "EASING_INQUAD", "EASING_OUTCUBIC", "EASING_LINEAR" }) do gui[e] = e end
gui.PLAYBACK_LOOP_PINGPONG, gui.PLAYBACK_ONCE_FORWARD = "pingpong", "once"
M.nodes = {}
local function node(kind, pos, size)
	local n = { kind = kind, pos = vmath.vector3(pos), size = vmath.vector3(size or vmath.vector3(1, 1, 0)), scale = vmath.vector3(1, 1, 1),
		color = vmath.vector4(1, 1, 1, 1), enabled = true, visible = true, pivot = "c", children = {}, alive = true }
	M.seq = (M.seq or 0) + 1
	n.seq = M.seq
	M.nodes[n] = true
	return n
end
local function live(n)
	assert(n and n.alive, "gui: using a deleted node")
	return n
end
function gui.new_box_node(pos, size) return node("box", pos, size) end
function gui.new_text_node(pos, text) local n = node("text", pos) n.text = text return n end
function gui.set_texture(n, t) live(n).texture = t end
function gui.play_flipbook(n, a) live(n).anim = a end
function gui.set_color(n, c) live(n).color = vmath.vector4(c) end
function gui.get_color(n) return vmath.vector4(live(n).color) end
function gui.set_inherit_alpha(n, v) live(n) end
function gui.set_slice9(n, v) live(n) end
function gui.set_visible(n, v) live(n).visible = v end
function gui.set_enabled(n, v) live(n).enabled = v end
function gui.is_enabled(n, recursive)
	live(n)
	if not recursive then return n.enabled end
	local p = n
	while p do
		if not p.enabled then return false end
		p = p.parent
	end
	return true
end
function gui.set_scale(n, s) live(n).scale = vmath.vector3(s) end
function gui.get_scale(n) return vmath.vector3(live(n).scale) end
function gui.set_size(n, s) live(n).size = vmath.vector3(s) end
function gui.get_size(n) return vmath.vector3(live(n).size) end
function gui.set_position(n, p) live(n).pos = vmath.vector3(p) end
function gui.get_position(n) return vmath.vector3(live(n).pos) end
function gui.set_pivot(n, p) live(n).pivot = p end
function gui.set_font(n, f) live(n) end
function gui.set_outline(n, c) live(n) end
function gui.set_shadow(n, c) live(n) end
function gui.set_line_break(n, v) live(n) end
function gui.set_text(n, t) live(n).text = t end
function gui.get_text(n) return live(n).text end
function gui.set_parent(n, p)
	live(n)
	if n.parent then n.parent.children[n] = nil end
	n.parent = p
	if p then live(p).children[n] = true end
end
function gui.delete_node(n)
	live(n)
	for c in pairs(n.children) do gui.delete_node(c) end
	n.alive = false
	if n.parent then n.parent.children[n] = nil end
	M.nodes[n] = nil
end
function gui.animate(n, prop, to, easing, dur, delay, cb)
	live(n)
	if prop == "scale" and type(to) == "table" then n.scale = vmath.vector3(to) end
	if prop == "position.x" then n.pos.x = to end
	if cb then M.timers[#M.timers + 1] = { t = (dur or 0) + (delay or 0), cb = function() if n.alive then cb(nil, n) end end } end
end
function gui.cancel_animation(n, p) end

-- absolute bounds in virtual units (ignores rotation)
function M.bounds(n)
	local x, y, sx, sy = n.pos.x, n.pos.y, n.scale.x, n.scale.y
	local p = n.parent
	while p do
		x, y = p.pos.x + x * p.scale.x, p.pos.y + y * p.scale.y
		sx, sy = sx * p.scale.x, sy * p.scale.y
		p = p.parent
	end
	local w, h = n.size.x * sx, n.size.y * sy
	local cx, cy = x, y
	if n.pivot == "w" then cx = x + w / 2 elseif n.pivot == "e" then cx = x - w / 2 end
	return cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
end
-- Defold multiplies the pick point by (window / display) before testing (see app.gui_script)
function gui.pick_node(n, x, y)
	live(n)
	local vx, vy = x * M.window_w / 1280, y * M.window_h / 720
	local x0, y0, x1, y1 = M.bounds(n)
	return vx >= x0 and vx <= x1 and vy >= y0 and vy <= y1
end

-- ------------------------------------------------------------------ render
render = {}
graphics = {
	BUFFER_TYPE_COLOR0_BIT = 1, BUFFER_TYPE_DEPTH_BIT = 2, BUFFER_TYPE_STENCIL_BIT = 3,
	STATE_DEPTH_TEST = 1, STATE_CULL_FACE = 2, STATE_BLEND = 3, STATE_STENCIL_TEST = 4,
	BLEND_FACTOR_SRC_ALPHA = 1, BLEND_FACTOR_ONE_MINUS_SRC_ALPHA = 2,
}
function render.predicate(t) return t end
function render.get_window_width() return M.window_w end
function render.get_window_height() return M.window_h end
for _, f in ipairs({ "set_depth_mask", "set_stencil_mask", "clear", "set_viewport", "set_view", "set_projection", "enable_state", "disable_state", "set_blend_func", "draw" }) do
	render[f] = function() end
end

-- ------------------------------------------------------------------ Druid stand-in
M.buttons = {}
package.preload["druid.system.settings"] = function()
	return { play_sound = function() end }
end
package.preload["druid.druid"] = function()
	local D = {}
	function D.set_default_style() end
	function D.set_sound_function() end
	function D.new(context)
		local inst = { comps = {} }
		function inst:new_button(n, cb)
			local b = { node = n, cb = cb, enabled = true, kind = "button" }
			function b:set_enabled(v) self.enabled = v end
			function b:is_enabled() return self.enabled end
			self.comps[#self.comps + 1] = b
			return b
		end
		function inst:new_text(n, text)
			local t = { node = n }
			function t:set_text(s) gui.set_text(n, s) end
			gui.set_text(n, text)
			return t
		end
		function inst:new_blocker(n)
			self.comps[#self.comps + 1] = { node = n, kind = "blocker" }
		end
		function inst:on_input(action_id, action)
			if action_id ~= hash("touch") then return false end
			for i = #self.comps, 1, -1 do
				local c = self.comps[i]
				if c.node.alive and gui.is_enabled(c.node, true) and gui.pick_node(c.node, action.x, action.y) then
					if c.kind == "button" then
						if action.pressed then self.pressed = c end
						if action.released and self.pressed == c then
							self.pressed = nil
							if c.enabled and c.cb then c.cb() end
						end
					end
					return true
				end
			end
			return false
		end
		function inst:update(dt) end
		function inst:final() self.comps = {} end
		return inst
	end
	return D
end

-- ------------------------------------------------------------------ script loading
function M.load_script(path)
	local src = assert(readfile(path), "cannot read " .. path)
	local env = setmetatable({}, { __index = _G })
	local chunk = assert(load(src, "@" .. path, "t", env))
	chunk()
	return env
end

-- read factory ids from world/world.go so factory.create validates names
function M.read_factories(path)
	local src = assert(readfile(path), "cannot read " .. path)
	for id in src:gmatch('id: "(f_[%w_]+)"') do M.factory_names[id] = true end
end

return M
