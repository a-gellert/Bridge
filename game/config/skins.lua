-- Cosmetic catalog: body colours, wheel styles and roof toppers.
-- Purely visual: physics never reads this module, so a skin can never change the outcome of a run.
--
--   body   `color` is the new bodywork colour (0..1 RGB). Only the vehicle's paint model
--          (game/config/vehicles.lua paint_visual) is recoloured: tyres, glass, chrome and cargo
--          keep their own colours. No colour = the vehicle's factory paint.
--   wheel  tint / scale of the wheel model (monster wheels are only 18% bigger)
--   topper an extra prop on the vehicle: `visual` model, `mount` point from game/config/vehicles.lua
--          ("roof" or "rear"), optional `scale` and `tint` on top of the vehicle's topper_scale
--
-- Unlock rules:
--   price     bought with leftover budget dollars (the "wallet")
--   stars     free, but requires this many campaign stars
--   rewarded  unlocked by watching one rewarded video in the garage
-- Localized names for the other eight languages; en/ru stay inline below.
local NAMES = require("game.core.names")

local M = {}

M.kinds = { "body", "wheel", "topper" }

M.list = {
	body = {
		{ id = "classic", name = { en = "Classic", ru = "Классика" }, price = 0 },
		{ id = "toxic", name = { en = "Toxic", ru = "Токсик" }, color = { 0.55, 0.95, 0.22 }, price = 140 },
		{ id = "cyber", name = { en = "Cyber", ru = "Кибер" }, color = { 0.66, 0.42, 1.0 }, price = 220 },
		{ id = "hotrod", name = { en = "Hot Rod", ru = "Хот-род" }, color = { 1.0, 0.4, 0.16 }, price = 300 },
		{ id = "ice", name = { en = "Ice", ru = "Лёд" }, color = { 0.58, 0.88, 1.0 }, price = 380 },
		{ id = "champion", name = { en = "Champion", ru = "Чемпион" }, color = { 0.95, 0.96, 1.0 }, stars = 18, chapter = true },
		{ id = "gold", name = { en = "Golden", ru = "Золотой" }, color = { 0.93, 0.62, 0.08 }, rewarded = true },
	},
	wheel = {
		{ id = "classic", name = { en = "Stock", ru = "Сток" }, tint = { 1, 1, 1 }, price = 0 },
		{ id = "chrome", name = { en = "Chrome", ru = "Хром" }, tint = { 0.72, 0.88, 1.0 }, price = 90 },
		{ id = "neon", name = { en = "Neon", ru = "Неон" }, tint = { 0.32, 1.0, 0.86 }, price = 150 },
		{ id = "magma", name = { en = "Magma", ru = "Магма" }, tint = { 1.0, 0.46, 0.16 }, price = 210 },
		{ id = "monster", name = { en = "Monster", ru = "Монстр" }, tint = { 0.26, 0.27, 0.32 }, scale = 1.18, price = 280 },
	},
	topper = {
		{ id = "none", name = { en = "None", ru = "Без" }, price = 0 },
		{ id = "beacon", name = { en = "Beacon", ru = "Маячок" }, visual = "topper_beacon", mount = "roof", price = 120 },
		{ id = "duck", name = { en = "Ducky", ru = "Уточка" }, visual = "topper_duck", mount = "roof", price = 160 },
		{ id = "spoiler", name = { en = "Spoiler", ru = "Спойлер" }, visual = "spoiler", mount = "rear", price = 220 },
		{ id = "hat", name = { en = "Cowboy hat", ru = "Шляпа" }, visual = "topper_hat", mount = "roof", price = 260 },
	},
}

M.by_kind = {}

local function key(kind, id)
	return kind .. ":" .. id
end
M.key = key

for kind, list in pairs(M.list) do
	M.by_kind[kind] = {}
	for _, item in ipairs(list) do
		item.kind = kind
		item.key = key(kind, item.id)
		item.default = item.price == 0 and not item.stars and not item.rewarded
		local extra = NAMES.skins[kind] and NAMES.skins[kind][item.id]
		if extra then
			for lang, text in pairs(extra) do item.name[lang] = text end
		end
		M.by_kind[kind][item.id] = item
	end
end

function M.get(kind, id)
	local list = M.by_kind[kind]
	return list and (list[id] or list[list[1].id])
end

-- Bodywork colour for a vehicle def + body skin (the skin colour, else the factory paint).
function M.paint_color(def, body)
	return (body and body.color) or (def and def.paint) or { 1, 1, 1 }
end

-- Model tint that turns the neutral paint model (main voxels = palette "base", 0.855 grey)
-- into that colour. Components may exceed 1: light voxels clamp to the colour's highlight.
local NEUTRAL = 218 / 255
function M.paint_tint(def, body)
	local c = M.paint_color(def, body)
	return { c[1] / NEUTRAL, c[2] / NEUTRAL, c[3] / NEUTRAL }
end

function M.list_of(kind)
	return M.list[kind] or {}
end

function M.default_id(kind)
	for _, item in ipairs(M.list[kind] or {}) do
		if item.default then return item.id end
	end
	return "classic"
end

-- How the unlock is described in the garage.
--   { kind = "owned" } / { kind = "price", value = 140 } / { kind = "stars", value = 18 } / { kind = "rewarded" }
function M.unlock(item)
	if item.rewarded then return { kind = "rewarded", value = 0 } end
	if item.stars then return { kind = "stars", value = item.stars } end
	if (item.price or 0) > 0 then return { kind = "price", value = item.price } end
	return { kind = "owned", value = 0 }
end

return M
