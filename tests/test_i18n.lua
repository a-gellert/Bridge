-- Localization contract: every supported language has the same keys and format specifiers,
-- every chapter / level / cosmetic has a name in each language, and the font resource lists
-- every glyph those strings use. Add a language or a string -> this test is the safety net.
local i18n = require("game.core.i18n")
local levels = require("game.levels.levels")
local skins = require("game.config.skins")
local poki = require("platform.poki")

local ROOT = package.path:match("^(.-)/%?%.lua")
local LANGS = i18n.languages

local function specs(s)
	local out = {}
	for spec in s:gmatch("%%[sd%%]") do out[#out + 1] = spec end
	table.sort(out)
	return table.concat(out, " ")
end

assert(#LANGS >= 10, "expected the top-10 language set")
for _, code in ipairs(LANGS) do
	assert(type(i18n.native[code]) == "string" and i18n.native[code] ~= "", "native name: " .. code)
	local t = i18n.strings[code]
	assert(t, "missing language table: " .. code)
	for key, source in pairs(i18n.strings.en) do
		local value = t[key]
		assert(type(value) == "string" and value ~= "", code .. " missing string: " .. key)
		assert(specs(source) == specs(value), code .. " placeholders differ: " .. key)
	end
	for key in pairs(t) do
		assert(i18n.strings.en[key], code .. " has an unknown key: " .. key)
	end
	assert(t.language and t.new_badge, code .. " needs language / new_badge")
	for key, value in pairs(t) do
		if value:find("%%[sd]") then
			-- i18n.f() uses string.format: a stray % must never make it return the raw string
			assert(pcall(string.format, value, 1, 1, "x"), code .. " bad format string: " .. key)
		end
	end
end

for _, ch in ipairs(levels.chapters) do
	for _, code in ipairs(LANGS) do
		assert(ch.name[code] and ch.name[code] ~= "", "chapter name " .. ch.id .. " / " .. code)
	end
end
for _, lvl in ipairs(levels.list) do
	for _, code in ipairs(LANGS) do
		assert(lvl.name[code] and lvl.name[code] ~= "", "level name " .. lvl.id .. " / " .. code)
	end
end
for _, kind in ipairs(skins.kinds) do
	for _, item in ipairs(skins.list_of(kind)) do
		for _, code in ipairs(LANGS) do
			assert(item.name[code] and item.name[code] ~= "", "skin name " .. kind .. ":" .. item.id .. " / " .. code)
		end
	end
end

-- Language codes from Poki (?iso_lang=pt-BR) and devices.
assert(i18n.detect("en") == "en", "en")
assert(i18n.detect("pt-BR") == "pt", "pt-BR")
assert(i18n.detect("de_DE") == "de", "de_DE")
assert(i18n.detect("fr-CA") == "fr", "fr-CA")
assert(i18n.detect("uk-UA") == "ru", "uk -> ru")
assert(i18n.detect("zh-CN") == "en", "unsupported -> en")
assert(i18n.detect(nil) == "en", "nil -> en")

-- Poki gives the language as the ?iso_lang= URL parameter.
poki_sdk = { get_url_param = function(key) return key == "iso_lang" and "pt-BR" or nil end }
assert(poki.language() == "pt-BR", "iso_lang is read through the Poki SDK")
assert(i18n.detect(poki.language()) == "pt", "pt-BR -> pt")
poki_sdk.get_url_param = function() return nil end
assert(poki.language() == nil, "missing iso_lang -> no override")
poki_sdk = nil

-- main.font characters: decode Defold's \" / \\ / \320 octal escapes.
local font_src = assert(readfile(ROOT .. "/assets/fonts/main.font"), "main.font is missing")
local start = assert(font_src:find('characters: "', 1, true), "main.font has no characters list")
local i = start + #'characters: "'
local raw = {}
while i <= #font_src do
	local c = font_src:sub(i, i)
	if c == "\\" then
		local nextc = font_src:sub(i + 1, i + 1)
		if nextc:match("[0-7]") then
			raw[#raw + 1] = font_src:sub(i, i + 3)
			i = i + 4
		else
			raw[#raw + 1] = font_src:sub(i, i + 1)
			i = i + 2
		end
	elseif c == '"' then
		break
	else
		raw[#raw + 1] = c
		i = i + 1
	end
end
local function decode(s)
	local out = {}
	local j = 1
	while j <= #s do
		if s:sub(j, j) == "\\" then
			local nextc = s:sub(j + 1, j + 1)
			if nextc:match("[0-7]") then
				out[#out + 1] = string.char(tonumber(s:sub(j + 1, j + 3), 8))
				j = j + 4
			else
				out[#out + 1] = nextc
				j = j + 2
			end
		else
			out[#out + 1] = s:sub(j, j)
			j = j + 1
		end
	end
	return table.concat(out)
end
local glyphs = decode(table.concat(raw))

local checked = 0
local function check_string(s)
	local j = 1
	while j <= #s do
		local b = s:byte(j)
		local len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
		local ch = s:sub(j, j + len - 1)
		assert(glyphs:find(ch, 1, true), "glyph missing from main.font: " .. ch .. " (U+" .. string.format("%04X", b) .. ")")
		checked = checked + 1
		j = j + len
	end
end

for _, code in ipairs(LANGS) do
	for _, value in pairs(i18n.strings[code]) do check_string(value) end
	check_string(i18n.native[code])
end
for _, ch in ipairs(levels.chapters) do
	for _, code in ipairs(LANGS) do check_string(ch.name[code]) end
end
for _, lvl in ipairs(levels.list) do
	for _, code in ipairs(LANGS) do check_string(lvl.name[code]) end
end
for _, kind in ipairs(skins.kinds) do
	for _, item in ipairs(skins.list_of(kind)) do
		for _, code in ipairs(LANGS) do check_string(item.name[code]) end
	end
end

-- Formatting still works after switching languages.
for _, code in ipairs(LANGS) do
	i18n.set_lang(code)
	assert(i18n.f("page_fmt", 2, 5):find("2", 1, true), "page_fmt " .. code)
	assert(i18n.f("need_stars", 7):find("7", 1, true), "need_stars " .. code)
end
i18n.set_lang("en")

print("   " .. #LANGS .. " languages, " .. levels.COUNT .. " levels, " .. checked .. " glyph checks passed")
