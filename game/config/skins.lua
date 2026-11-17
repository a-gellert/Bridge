-- Cosmetic catalog: body colours, wheel styles and roof toppers.
-- Purely visual: physics never reads this module, so a skin can never change the outcome of a run.
--
--   body   tint multiplies the voxel palette of the chassis
--   wheel  tint / scale of the wheel model (monster wheels are only 18% bigger)
--   topper an extra prop placed on the roof (fractions of the body size)
--
-- Unlock rules:
--   price     bought with leftover budget dollars (the "wallet")
--   stars     free, but requires this many campaign stars
--   rewarded  unlocked by watching one rewarded video in the garage
local M = {}

M.kinds = { "body", "wheel", "topper" }

M.list = {
	body = {
		{ id = "classic", name = { en = "Classic", ru = "Классика" }, tint = { 1, 1, 1 }, price = 0 },
		{ id = "toxic", name = { en = "Toxic", ru = "Токсик" }, tint = { 0.55, 1.0, 0.28 }, price = 140 },
		{ id = "cyber", name = { en = "Cyber", ru = "Кибер" }, tint = { 0.72, 0.48, 1.0 }, price = 220 },
		{ id = "hotrod", name = { en = "Hot Rod", ru = "Хот-род" }, tint = { 1.0, 0.42, 0.20 }, price = 300 },
		{ id = "ice", name = { en = "Ice", ru = "Лёд" }, tint = { 0.62, 0.90, 1.0 }, price = 380 },
		{ id = "champion", name = { en = "Champion", ru = "Чемпион" }, tint = { 1.0, 0.86, 0.26 }, stars = 18, chapter = true },
		{ id = "gold", name = { en = "Golden", ru = "Золотой" }, tint = { 1.0, 0.76, 0.12 }, rewarded = true },
	},
	wheel = {
		{ id = "classic", name = { en = "Stock", ru = "Сток" }, tint = { 1, 1, 1 }, price = 0 },
		{ id = "chrome", name = { en = "Chrome", ru = "Хром" }, tint = { 0.86, 0.92, 1.0 }, price = 90 },
		{ id = "neon", name = { en = "Neon", ru = "Неон" }, tint = { 0.32, 1.0, 0.86 }, price = 150 },
		{ id = "magma", name = { en = "Magma", ru = "Магма" }, tint = { 1.0, 0.46, 0.16 }, price = 210 },
		{ id = "monster", name = { en = "Monster", ru = "Монстр" }, tint = { 0.26, 0.27, 0.32 }, scale = 1.18, price = 280 },
	},
	topper = {
		{ id = "none", name = { en = "None", ru = "Без" }, price = 0 },
		{
			id = "beacon", name = { en = "Beacon", ru = "Маячок" }, visual = "block",
			scale = { 0.22, 0.4, 0.22 }, pos = { 0.12, 0.72 }, tint = { 1.0, 0.22, 0.18 }, price = 120,
		},
		{
			id = "duck", name = { en = "Ducky", ru = "Уточка" }, visual = "crate",
			scale = { 0.3, 0.3, 0.3 }, pos = { 0.0, 0.78 }, tint = { 1.0, 0.84, 0.18 }, price = 160,
		},
		{
			id = "spoiler", name = { en = "Spoiler", ru = "Спойлер" }, visual = "spoiler",
			scale = { 0.62, 0.22, 0.3 }, pos = { 0.42, 0.58 }, tint = { 0.18, 0.2, 0.28 }, price = 220,
		},
		{
			id = "hat", name = { en = "Cowboy hat", ru = "Шляпа" }, visual = "stump",
			scale = { 0.42, 0.24, 0.42 }, pos = { -0.08, 0.82 }, tint = { 0.55, 0.36, 0.18 }, price = 260,
		},
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
		M.by_kind[kind][item.id] = item
	end
end

function M.get(kind, id)
	local list = M.by_kind[kind]
	return list and (list[id] or list[list[1].id])
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
