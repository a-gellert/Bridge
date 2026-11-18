-- Poki SDK wrapper. Safe without the SDK (desktop builds, editor): ads resolve immediately.
-- Rules (AGENT_GUIDELINES.md §5): no ads during gameplay, mute audio while an ad plays, never block
-- the game waiting for an ad, commercial breaks only between levels and not more often than COOLDOWN.
local audio = require("platform.audio")

local M = {}

M.COOLDOWN = 180          -- seconds between commercial breaks (Poki also rate-limits on its side)
M.FIRST_BREAK_LEVEL = 4   -- no ads during the first three levels (green corridor for the FTUE)
M.AD_TIMEOUT = 35         -- never leave the player waiting for a stuck ad callback

local gameplay = false
local ad_active = false
local ad_pending = false
local last_break = -1e9

local function sdk()
	return rawget(_G, "poki_sdk")
end

local function now()
	return socket and socket.gettime() or os.clock()
end

local function set_ad(active)
	ad_active = active
	audio.set_ad_mute(active)
end

function M.is_ad_active()
	return ad_active
end

function M.is_busy()
	return ad_active or ad_pending
end

-- Tell Poki that the game is playable (loaded). Safe without the SDK.
-- extension-poki-sdk does not expose game_loading_finished in Lua (the HTML shell's
-- PokiSDK.gameLoadingFinished at 100% owns that measure), so this is a no-op bridge kept
-- for other SDK integrations — do not rely on it on the web.
function M.loading_finished()
	local s = sdk()
	if s and s.game_loading_finished then pcall(s.game_loading_finished) end
end

-- Optional progress hook for shell/loading widgets (the extension's HTML template normally
-- reports this from JavaScript before Lua starts).
function M.loading_progress(percent)
	local s = sdk()
	if s and s.game_loading_progress then
		pcall(s.game_loading_progress, { percentageDone = math.max(0, math.min(1, (percent or 0) / 100)) })
	end
end

-- Safety net: if an ad SDK never invokes its callback (blocked / broken network), never leave
-- the player stuck on a frozen game. 35 s is longer than a normal interstitial.
local function ad_timeout(done_ref, finish)
	if timer and timer.delay then
		timer.delay(M.AD_TIMEOUT, false, function()
			if done_ref.done then return end
			ad_pending = false
			finish()
		end)
	end
end

-- Report the player's device category to Poki (mobile / tablet / desktop).
function M.device_category()
	local s = sdk()
	if s and s.get_device_info then
		local ok, info = pcall(s.get_device_info)
		if ok and type(info) == "table" then return info.category end
	end
	return nil
end

-- Keep the Poki pill away from the game HUD on phones.
function M.move_pill(percent, px)
	local s = sdk()
	if s and s.move_pill then pcall(s.move_pill, percent or 0, px or 56) end
end

function M.gameplay_start()
	if gameplay or ad_active then return end
	gameplay = true
	local s = sdk()
	if s and s.gameplay_start then s.gameplay_start() end
end

function M.gameplay_stop()
	if not gameplay then return end
	gameplay = false
	local s = sdk()
	if s and s.gameplay_stop then s.gameplay_stop() end
end

function M.measure(category, what, action)
	local s = sdk()
	if s and s.measure then pcall(s.measure, category, tostring(what), action) end
end

-- Interstitial between levels. on_done always runs exactly once.
function M.commercial_break(level_index, on_done)
	local s = sdk()
	local skip = not (s and s.commercial_break)
		or (level_index ~= nil and level_index < M.FIRST_BREAK_LEVEL)
		or now() - last_break < M.COOLDOWN
		or ad_pending
	if skip then
		if on_done then on_done() end
		return
	end
	M.gameplay_stop()
	ad_pending = true
	set_ad(true)
	local state = { done = false }
	local function finish()
		if state.done then return end
		state.done = true
		ad_pending = false
		last_break = now()
		set_ad(false)
		if on_done then on_done() end
	end
	local ok = pcall(s.commercial_break, function(_, status)
		if s.COMMERCIAL_BREAK_START ~= nil and status == s.COMMERCIAL_BREAK_START then
			set_ad(true)
		else
			finish()
		end
	end)
	if not ok then finish() else ad_timeout(state, finish) end
end

-- Rewarded break. on_done(rewarded) always runs exactly once; without the SDK it rewards
-- (desktop builds and tests exercise every reward path).
-- `size` = "small" | "medium" | "large" (Poki extension >= 3.x).
function M.rewarded_break(on_done, size)
	local s = sdk()
	if not (s and s.rewarded_break) then
		if on_done then on_done(true) end
		return
	end
	if ad_pending then
		if on_done then on_done(false) end
		return
	end
	M.gameplay_stop()
	ad_pending = true
	set_ad(true)
	local state = { done = false }
	local function finish(rewarded)
		if state.done then return end
		state.done = true
		ad_pending = false
		set_ad(false)
		if on_done then on_done(rewarded) end
	end
	local ok = pcall(s.rewarded_break, size or "small", function(_, status)
		if s.REWARDED_BREAK_START ~= nil and status == s.REWARDED_BREAK_START then
			set_ad(true)
		else
			finish(status == s.REWARDED_BREAK_SUCCESS)
		end
	end)
	if not ok then finish(false) else ad_timeout(state, function() finish(false) end) end
end

-- Progress events: one start, then complete or fail (never both) for the same attempt.
function M.level_start(level_id)
	M.measure("level", tostring(level_id or "?"), "start")
end

function M.level_end(level_id, won)
	M.measure("level", tostring(level_id or "?"), won and "complete" or "fail")
end

return M
