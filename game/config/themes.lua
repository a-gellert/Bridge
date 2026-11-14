-- Chapter themes: sky color, terrain tints and background decor. Colors are {r, g, b} 0..1.
-- A theme is chosen by the chapter's `theme` field (game/levels/chapterN.lua).
local M = {}

local function rgb(hex)
	return {
		tonumber(hex:sub(2, 3), 16) / 255,
		tonumber(hex:sub(4, 5), 16) / 255,
		tonumber(hex:sub(6, 7), 16) / 255,
	}
end

M.valley = {
	sky = rgb("#8ED2FF"),
	ground = rgb("#A06F48"),   -- terrain body
	top = rgb("#63C75B"),      -- terrain top slab (grass)
	rock = rgb("#9AA3AE"),     -- floating blocks
	water = rgb("#3FA7F5"),
	far = rgb("#7DBF9A"),      -- background mountains
	decor = { "tree", "pine", "bush", "tree", "rock_small" },
	clouds = true,
}

M.canyon = {
	sky = rgb("#FFCB8E"),
	ground = rgb("#C4683A"),
	top = rgb("#E5965A"),
	rock = rgb("#B4572E"),
	water = rgb("#3D8FD6"),
	far = rgb("#D98552"),
	decor = { "rock_small", "bush", "rock_small" },
	clouds = true,
}

M.lab = {
	sky = rgb("#DCE6F1"),
	ground = rgb("#B5C1CE"),
	top = rgb("#EEF3F9"),
	rock = rgb("#8C97A6"),
	water = rgb("#55E0A8"),
	far = rgb("#C7D3E0"),
	decor = { "lab_panel" },
	panels = true,
	clouds = false,
}

M.mountains = {
	sky = rgb("#B7A8FF"),
	ground = rgb("#6D6A8F"),
	top = rgb("#F4F8FF"),
	rock = rgb("#7E799E"),
	water = rgb("#5AA0FF"),
	far = rgb("#9C95C9"),
	decor = { "pine", "pine", "rock_small" },
	clouds = true,
}

function M.get(id)
	return M[id] or M.valley
end

return M
