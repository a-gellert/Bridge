-- Asset wiring: every visual id used by the game must have a factory and an entity file,
-- and every decor/flower id named by a theme must exist in the visual registry.
local visuals = require("game.config.visuals")
local themes = require("game.config.themes")
local achievements = require("game.core.achievements")
local skins = require("game.config.skins")

local ROOT = package.path:match("^(.-)/%?%.lua")
local src = assert(readfile(ROOT .. "/world/world.go"), "world/world.go is missing")

local factories = {}
for id in src:gmatch('id: "(f_[%w_]+)"') do factories[id] = true end

local count = 0
for id, def in pairs(visuals.defs) do
	assert(def.factory, "visual '" .. id .. "' has no factory")
	assert(factories[def.factory], "visual '" .. id .. "' points to missing factory " .. tostring(def.factory))
	assert(readfile(ROOT .. "/entities/" .. id .. ".go"), "entities/" .. id .. ".go is missing")
	assert(readfile(ROOT .. "/assets/models/" .. id .. ".gltf") or readfile(ROOT .. "/assets/models/" .. id .. ".glb"),
		"assets/models/" .. id .. ".gltf/.glb is missing")
	count = count + 1
end
assert(count > 40, "expected the full visual registry, got " .. count)

for name, theme in pairs(themes) do
	if type(theme) == "table" then
		for _, id in ipairs(theme.decor or {}) do
			assert(visuals.defs[id], "theme " .. name .. " uses unknown decor '" .. id .. "'")
		end
		for _, id in ipairs(theme.flowers or {}) do
			assert(visuals.defs[id], "theme " .. name .. " uses unknown flower '" .. id .. "'")
		end
	end
end

-- HTML5 shell: branded, safe-area aware, no Defold splash / buttons bar.
local tpl = assert(readfile(ROOT .. "/template/poki_template.html"), "template/poki_template.html is missing")
assert(not tpl:find("buttons-background", 1, true), "Defold buttons bar must be removed")
assert(not tpl:find("defold-logo-html5-splash", 1, true), "Defold splash must be removed")
assert(tpl:find("viewport-fit=cover", 1, true), "viewport must cover notches")
assert(tpl:find("--sat", 1, true) and tpl:find("--sab", 1, true), "safe-area CSS variables")
assert(tpl:find("{{exe-name}}", 1, true), "engine loader token")
assert(tpl:find("EngineLoader.load", 1, true), "engine loader call")
assert(tpl:find("contextmenu", 1, true), "context menu must be blocked")
assert(tpl:find("bmUnlockAudio", 1, true) and tpl:find("ctx.resume", 1, true), "WebAudio unlock")
-- Regression: the shell must extend dmloader's CUSTOM_PARAMETERS instead of
-- replacing it. A fresh object drops archive_location_filter and
-- EngineLoader.load() throws "TypeError: Invalid filter" before the game starts.
assert(not tpl:find("var CUSTOM_PARAMETERS =", 1, true), "shell must not replace engine CUSTOM_PARAMETERS")
assert(tpl:find("CUSTOM_PARAMETERS[key] = overrides[key]", 1, true), "shell must merge CUSTOM_PARAMETERS overrides")
-- The Poki integration only lives in the extension + the shell: a rebuild must keep it, and the
-- engine may only start once, after PokiSDK.init() (or a blocked SDK) resolves.
assert(tpl:find("poki-sdk.js", 1, true), "the shell must document where the Poki SDK comes from")
assert(not tpl:find('<script defer src="https://game-cdn.poki.com', 1, true),
	"the shell must not load poki-sdk.js itself: extension-poki-sdk injects it and a second tag doubles SDK init / loading measures")
assert(tpl:find("poki-sdk-fallback", 1, true),
	"the shell must start the engine when the Poki SDK is blocked (adblock / offline)")
assert(tpl:find("window.runFunc = function () {}", 1, true),
	"the blocked-SDK fallback must take the one-shot start away from the extension")
local built_shell = readfile(ROOT .. "/release/wasm-web/BridgeMad/index.html")
if built_shell then
	assert(not built_shell:find("var CUSTOM_PARAMETERS =", 1, true), "built shell must not replace engine CUSTOM_PARAMETERS")
	local tags, i = 0, 1
	while true do
		local a, b = built_shell:find('<script defer src="https://game-cdn.poki.com', i, true)
		if not a then break end
		tags = tags + 1
		i = b + 1
	end
	if tags ~= 1 then
		print("   note: the HTML5 build in release/ is stale (" .. tags .. " poki-sdk.js tags) — rebuild it to pick up the single-SDK fix")
	end
end
local gp = assert(readfile(ROOT .. "/game.project"), "game.project is missing")
assert(gp:find("extension-poki-sdk", 1, true), "the Poki SDK extension dependency is required")
assert(gp:find("htmlfile = /template/poki_template.html", 1, true), "custom HTML shell wired")
assert(gp:find("com.madgames.bridgemad", 1, true), "mobile package id")
assert(gp:find("dynamic_orientation = 1", 1, true), "orientation switching")
assert(gp:find("max_pixel_ratio = 1.5", 1, true), "mobile pixel ratio cap")

-- new UI icons / sounds used by the meta layer
for _, name in ipairs({ "garage", "trophy", "video", "hand", "vibrate_on", "vibrate_off" }) do
	assert(readfile(ROOT .. "/assets/images/ui/" .. name .. ".png"), "missing UI icon " .. name)
end
for _, name in ipairs({ "creak", "horn", "skid", "purchase", "achievement" }) do
	assert(readfile(ROOT .. "/assets/sounds/" .. name .. ".wav"), "missing sound " .. name)
end
for _, size in ipairs({ 36, 48, 72, 76, 96, 120, 144, 152, 167, 180, 192, 512 }) do
	assert(readfile(ROOT .. "/assets/icons/icon_" .. size .. ".png"), "missing store icon " .. size)
end
assert(gp:find("app_icon_192x192 = /assets/icons/icon_192.png", 1, true), "Android icons wired")
assert(gp:find("app_icon_180x180 = /assets/icons/icon_180.png", 1, true), "iOS icons wired")

-- every achievement icon and topper model is wired
for _, a in ipairs(achievements.list) do
	assert(readfile(ROOT .. "/assets/images/ui/" .. a.icon .. ".png"), "achievement icon missing: " .. a.icon)
end
for _, item in ipairs(skins.list_of("topper")) do
	if item.visual then assert(visuals.defs[item.visual], "topper visual missing: " .. item.visual) end
end

print("   visuals: " .. count .. " registry entries, factories and entities linked; HTML shell and meta assets verified")
