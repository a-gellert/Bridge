-- Haptic feedback facade. Web Vibration API on HTML5; native builds use the optional
-- `vibrate` extension when present. Every call is safe to make on any platform.
local M = {}

local enabled = true
local last = 0
local STATE_KEY = "haptics"

local function now()
	if socket and socket.gettime then return socket.gettime() end
	return os.clock()
end

local function run_js(ms)
	if not (html5 and html5.run) then return false end
	local ok = pcall(html5.run, "navigator.vibrate&&navigator.vibrate(" .. ms .. ")")
	return ok
end

function M.set_enabled(on)
	enabled = on and true or false
end

function M.is_enabled()
	return enabled
end

-- pattern: number (ms) or a JS array literal such as "[60,40,80]"
function M.vibrate(pattern, cooldown)
	if not enabled then return false end
	local t = now()
	if cooldown and t - last < cooldown then return false end
	last = t
	if run_js(pattern) then return true end
	-- Defold vibration extensions expose different globals; use one if the project adds it.
	if type(vibrate) == "table" and vibrate.start then
		local ok = pcall(vibrate.start, type(pattern) == "number" and pattern or 140)
		return ok
	end
	if type(vibrate) == "function" then
		return pcall(vibrate, type(pattern) == "number" and pattern or 140)
	end
	return false
end

-- Named effects used by gameplay code.
function M.click() M.vibrate(12, 0.04) end
function M.snap() M.vibrate(18, 0.05) end
function M.build() M.vibrate(25, 0.06) end
function M.portal() M.vibrate(35, 0.1) end
function M.bounce() M.vibrate(45, 0.1) end
function M.boost() M.vibrate(30, 0.1) end
function M.break_beam() M.vibrate("[60,40,80]", 0.18) end
function M.crash() M.vibrate("[100,50,150]", 0.4) end
function M.win() M.vibrate("[30,60,30,60,100]", 0.5) end
function M.purchase() M.vibrate("[20,40,30]", 0.2) end

M.STATE_KEY = STATE_KEY

return M
