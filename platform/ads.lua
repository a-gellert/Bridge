-- Single monetization facade: Poki on the web, optional native SDKs (AdMob/AppLovin) on mobile,
-- instant no-op elsewhere. Callers always receive exactly one callback, so the game can never
-- freeze while an ad is loading or if an ad blocker is active.
local poki = require("platform.poki")

local M = {}

local pending = false

local function native_ads()
	if html5 then return nil end
	if rawget(_G, "admob") then return rawget(_G, "admob") end
	if rawget(_G, "applovin") then return rawget(_G, "applovin") end
	return nil
end

function M.is_busy()
	return pending or poki.is_ad_active()
end

-- Interstitial between levels / from a result screen. `reason` is for analytics only.
function M.interstitial(reason, on_done)
	on_done = on_done or function() end
	if pending then
		on_done()
		return
	end
	if html5 then
		pending = true
		local level_index = tonumber(tostring(reason or ""):match("^next_(%d+)$"))
		poki.commercial_break(level_index, function()
			pending = false
			on_done()
		end)
		return
	end
	local sdk = native_ads()
	if sdk and sdk.show_interstitial then
		pending = true
		local ok = pcall(sdk.show_interstitial, function()
			pending = false
			on_done()
		end)
		if not ok then
			pending = false
			on_done()
		end
		return
	end
	on_done()
end

-- Rewarded video. on_done(rewarded) is called exactly once. Without an SDK it rewards,
-- so desktop builds and tests can exercise every reward path.
function M.rewarded(placement, on_done)
	on_done = on_done or function() end
	if pending then
		on_done(false)
		return
	end
	poki.measure("rewarded", placement or "reward", "interact")
	if html5 then
		pending = true
		poki.rewarded_break(function(ok)
			pending = false
			on_done(ok)
		end, placement == "hint" and "small" or "medium")
		return
	end
	local sdk = native_ads()
	if sdk and sdk.show_rewarded then
		pending = true
		local ok = pcall(sdk.show_rewarded, function(rewarded)
			pending = false
			on_done(rewarded == true)
		end)
		if not ok then
			pending = false
			on_done(false)
		end
		return
	end
	on_done(true)
end

function M.offer_visible(placement)
	poki.measure("rewarded", placement or "reward", "visible")
end

return M
