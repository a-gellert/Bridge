-- Poki SDK wrapper. Safe without the SDK (desktop builds, editor): ads resolve immediately.
-- Rules (AGENT_GUIDELINES.md §5): no ads during gameplay, mute audio while an ad plays, never block
-- the game waiting for an ad, commercial breaks only between levels and not more often than COOLDOWN.
local audio = require("platform.audio")

local M = {}

M.COOLDOWN = 180          -- seconds between commercial breaks (Poki also rate-limits on its side)
M.FIRST_BREAK_LEVEL = 3   -- no ads during the first levels

local gameplay = false
local ad_active = false
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
	if not (s and s.commercial_break) or (level_index or 0) < M.FIRST_BREAK_LEVEL or now() - last_break < M.COOLDOWN then
		if on_done then on_done() end
		return
	end
	M.gameplay_stop()
	set_ad(true)
	local done = false
	s.commercial_break(function(_, status)
		if status == s.COMMERCIAL_BREAK_START then
			set_ad(true)
		elseif not done then
			done = true
			last_break = now()
			set_ad(false)
			if on_done then on_done() end
		end
	end)
end

-- Rewarded break (hint). on_done(rewarded) always runs exactly once; without the SDK it rewards.
function M.rewarded_break(on_done)
	local s = sdk()
	if not (s and s.rewarded_break) then
		if on_done then on_done(true) end
		return
	end
	M.gameplay_stop()
	set_ad(true)
	local done = false
	s.rewarded_break("small", function(_, status)
		if status == s.REWARDED_BREAK_START then
			set_ad(true)
		elseif not done then
			done = true
			set_ad(false)
			if on_done then on_done(status == s.REWARDED_BREAK_SUCCESS) end
		end
	end)
end

return M
