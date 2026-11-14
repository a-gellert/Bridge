-- One-time app setup shared by every script (init order between scripts is not guaranteed, so each
-- script calls boot.init() and only the first call does the work).
local progress = require("game.core.progress")
local i18n = require("game.core.i18n")
local audio = require("platform.audio")

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
end

-- Touch-first device? (mobile apps and mobile browsers)
function M.is_touch()
	local info = sys.get_sys_info()
	if info.system_name == "Android" or info.system_name == "iPhone OS" then return true end
	if html5 then
		local ok, r = pcall(html5.run, "(window.matchMedia && window.matchMedia('(pointer: coarse)').matches) ? 1 : 0")
		return ok and r == "1"
	end
	return false
end

return M
