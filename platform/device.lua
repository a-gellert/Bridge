-- Device helpers: touch-first detection, safe-area insets for notched phones and small
-- platform probes. All calls are defensive: the same code runs on desktop, native and in tests.
local M = {}

local cached_touch = nil
local cached_insets = nil

local function sys_info()
	if sys and sys.get_sys_info then
		local ok, info = pcall(sys.get_sys_info)
		if ok and info then return info end
	end
	return {}
end

function M.is_mobile_native()
	local name = sys_info().system_name or ""
	return name == "Android" or name == "iPhone OS"
end

-- Touch-first device (mobile app or a coarse-pointer browser).
function M.is_touch()
	if cached_touch ~= nil then return cached_touch end
	local info = sys_info()
	local name = info.system_name or ""
	if name == "Android" or name == "iPhone OS" then
		cached_touch = true
		return true
	end
	if html5 and html5.run then
		local ok, r = pcall(html5.run,
			"(window.matchMedia && window.matchMedia('(pointer: coarse)').matches) ? 1 : 0")
		cached_touch = ok and r == "1" or false
		return cached_touch
	end
	cached_touch = false
	return false
end

-- CSS env(safe-area-inset-*) exposed by the custom HTML shell as CSS variables.
-- Returns fractions of the window (0..1): top, bottom, left, right.
local function read_web_insets()
	if not (html5 and html5.run) then return 0, 0, 0, 0 end
	local js = table.concat({
		"(function(){",
		"var s=getComputedStyle(document.documentElement);",
		"var w=window.innerWidth||1,h=window.innerHeight||1;",
		"function v(n){var x=parseFloat(s.getPropertyValue(n));return isFinite(x)?x:0}",
		"return [v('--sat')/h,v('--sab')/h,v('--sal')/w,v('--sar')/w].join(',');",
		"})()",
	}, "")
	local ok, res = pcall(html5.run, js)
	if not ok or type(res) ~= "string" then return 0, 0, 0, 0 end
	local a, b, c, d = res:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
	return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0, tonumber(d) or 0
end

-- top, bottom, left, right as fractions of the window size. Cached: insets only change on
-- rotation, and the GUI re-reads them after a resize.
function M.safe_insets(refresh)
	if cached_insets and not refresh then
		return cached_insets[1], cached_insets[2], cached_insets[3], cached_insets[4]
	end
	local top, bottom, left, right = read_web_insets()
	-- native builds have no CSS env(); a small breathing room keeps controls off the gesture bar
	if not html5 and M.is_mobile_native() then
		top = math.max(top, 0.015)
		bottom = math.max(bottom, 0.02)
	end
	local function clamp(v) return math.max(0, math.min(0.12, v or 0)) end
	cached_insets = { clamp(top), clamp(bottom), clamp(left), clamp(right) }
	return cached_insets[1], cached_insets[2], cached_insets[3], cached_insets[4]
end

function M.vibrate_supported()
	if not (html5 and html5.run) then return false end
	local ok, r = pcall(html5.run, "(navigator.vibrate ? 1 : 0)")
	return ok and r == "1"
end

function M.set_fullscreen(on)
	if not (html5 and html5.run) then return false end
	local js = on
		and "(function(){var e=document.documentElement;var f=e.requestFullscreen||e.webkitRequestFullscreen;if(f)f.call(e);return 1})()"
		or "(function(){if(document.exitFullscreen)document.exitFullscreen();return 1})()"
	local ok = pcall(html5.run, js)
	return ok
end

return M
