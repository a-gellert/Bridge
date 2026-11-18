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
	sky = rgb("#8ED2FF"),       -- horizon
	sky_top = rgb("#3E93DE"),   -- zenith of the gradient
	ground = rgb("#A06F48"),    -- terrain body
	top = rgb("#63C75B"),       -- terrain top slab (grass)
	rock = rgb("#9AA3AE"),      -- floating blocks
	water = rgb("#3FA7F5"),
	far = rgb("#7DBF9A"),       -- background mountains
	decor = { "tree", "tree_blossom", "pine", "bush", "lantern_post", "tree", "pine_tall", "rock_small", "stump" },
	flowers = { "flower_red", "flower_yellow", "flower_blue" },
	clouds = true,
	parallax_bg = true,
	landmark = "windmill",
	ambient = "petals",
	birds = true,
	butterflies = true,
	crystal = { 1, 1, 1 },
}

M.canyon = {
	sky = rgb("#FFD3A2"),
	sky_top = rgb("#E87B4E"),
	ground = rgb("#C4683A"),
	top = rgb("#E5965A"),
	rock = rgb("#B4572E"),
	water = rgb("#3D8FD6"),
	far = rgb("#D98552"),
	decor = { "rock_small", "cactus_saguaro", "bush", "rock_big", "crate", "cactus_saguaro", "stump" },
	flowers = { "flower_red", "flower_yellow" },
	clouds = true,
	landmark = "ruin_arch",
	ambient = "dust",
	birds = true,
	butterflies = false,
	crystal = { 1, 0.9, 0.8 },
}

M.lab = {
	sky = rgb("#DCE6F1"),
	sky_top = rgb("#9FB7CF"),
	ground = rgb("#B5C1CE"),
	top = rgb("#EEF3F9"),
	rock = rgb("#A3ADBC"),
	water = rgb("#55E0A8"),
	far = rgb("#C7D3E0"),
	decor = { "lab_panel", "lab_terminal", "energy_pylon", "crystal_cluster", "lab_terminal", "energy_pylon" },
	flowers = {},
	panels = true,
	clouds = false,
	landmark = "lab_generator",
	ambient = "sparks",
	birds = false,
	butterflies = false,
	crystal = { 0.8, 1, 1 },
}

M.mountains = {
	sky = rgb("#C9C0FF"),
	sky_top = rgb("#6C5BD8"),
	ground = rgb("#8783A9"),
	top = rgb("#F4F8FF"),
	rock = rgb("#9691B8"),
	water = rgb("#5AA0FF"),
	far = rgb("#A7A0D4"),
	decor = { "pine", "pine_tall", "rock_small", "lantern_post", "rock_big", "stump", "tree_blossom" },
	flowers = { "flower_blue", "flower_white" },
	clouds = true,
	parallax_bg = true,
	landmark = "rock_arch",
	ambient = "snow",
	birds = true,
	butterflies = false,
	crystal = { 0.72, 0.9, 1 },
}

function M.get(id)
	return M[id] or M.valley
end

return M
