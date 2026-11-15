-- One-time app setup shared by every script (init order between scripts is not guaranteed, so each
-- script calls boot.init() and only the first call does the work).
local progress = require("game.core.progress")
local i18n = require("game.core.i18n")
local audio = require("platform.audio")
local device = require("platform.device")
local haptics = require("platform.haptics")
local poki = require("platform.poki")

local M = {}

local done = false
local SAVE_NAME = "bridge_mad"

local function save_path()
	return sys.get_save_file(SAVE_NAME, "progress")
end

function M.init()
	if done then return end
	done = true
	math.randomseed(os.time())
	progress.set_storage({
		load = function()
			local t = sys.load(save_path())
			if t and next(t) then return t end
			return nil
		end,
		save = function(data)
			sys.save(save_path(), data)
		end,
	})
	progress.load()
	local lang = progress.get("lang")
	if not lang or lang == "" then
		local info = sys.get_sys_info()
		lang = i18n.detect(info.language or info.device_language)
	end
	i18n.set_lang(lang)
	audio.set_enabled(progress.get("sound") ~= false)
	haptics.set_enabled(progress.get("haptics") ~= false)
	poki.loading_finished()
end

-- Touch-first device? (mobile apps and mobile browsers)
function M.is_touch()
	return device.is_touch()
end

function M.haptics_supported()
	return device.vibrate_supported() or device.is_mobile_native()
end

return M
