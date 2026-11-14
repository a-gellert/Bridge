-- Sound effects (components in main/sounds.go). Callable from any script; the engine loop is driven
-- by world.script (it needs go.set for the playback speed).
local M = {}

local URL = "/sounds#"
local enabled = true
local ad_mute = false
local last = {}

local COOLDOWN = {
	build = 0.05, erase = 0.05, error = 0.15, click = 0.04,
	break_wood = 0.06, break_steel = 0.08, snap = 0.06, bounce = 0.2, boost = 0.4,
}

local function sync()
	sound.set_group_gain(hash("master"), (enabled and not ad_mute) and 1 or 0)
end

function M.set_enabled(on)
	enabled = on and true or false
	sync()
end

function M.is_enabled()
	return enabled
end

function M.set_ad_mute(on)
	ad_mute = on and true or false
	sync()
end

function M.play(id, gain, speed)
	if not enabled or ad_mute then return end
	local t = socket.gettime()
	local cd = COOLDOWN[id]
	if cd and last[id] and t - last[id] < cd then return end
	last[id] = t
	sound.play(URL .. id, { gain = gain or 0.8, speed = speed or 1 })
end

function M.stop(id)
	sound.stop(URL .. id)
end

return M
