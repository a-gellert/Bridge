-- Chapter 1: Green Valley. Roads, wood, then rope. Teaches anchors, triangles and supports.
-- Level format (meters, grid = 1 m):
--   name       { en = ..., ru = ... }
--   budget     $ available for building
--   materials  material ids the player may use
--   ground     { {x0, x1, top, bottom?} }   solid columns, anchors usually sit on their top corners
--   ramps      { {x0, x1, y0, y1, bottom?} } sloped columns
--   blocks     { {x0, y0, x1, y1} }         floating rocks / pillars / ceilings
--   anchors    { {x, y} }                   fixed joints the bridge can start from
--   start      x of the vehicle spawn (point A), finish = x of point B
--   water      y of the water surface (falling below = fail); kill_y for levels without water
--   area       {x0, y0, x1, y1}             where joints may be placed
--   portals    { { {x, y, angle}, {x, y, angle} } }  enter the first, exit the second (angle = facing)
--   spikes     { {x0, y0, x1, y1} }         touching them breaks the vehicle
--   solution   { {material, x1, y1, x2, y2} } reference design (validated by tests, used as hint)
--   tip        i18n key of the tutorial tip shown on the level
return {
	id = "valley",
	theme = "valley",
	name = { en = "Green Valley", ru = "Зелёная долина" },
	stars_required = 0,
	levels = {
		{
			id = "1-1",
			name = { en = "First Bridge", ru = "Первый мост" },
			budget = 450,
			materials = { "road", "wood" },
			ground = { { -40, 0, 0 }, { 3, 40, 0 } },
			anchors = { { 0, 0 }, { 3, 0 } },
			start = -6, finish = 10, water = -3,
			area = { -1, -3, 4, 4 },
			solution = { { "road", 0, 0, 3, 0 } },
			tip = "tip_first",
		},
		{
			id = "1-2",
			name = { en = "Triangles", ru = "Треугольники" },
			budget = 1300,
			materials = { "road", "wood" },
			ground = { { -40, 0, 0 }, { 6, 40, 0 } },
			anchors = { { 0, 0 }, { 6, 0 } },
			start = -6, finish = 13, water = -3,
			area = { -1, -4, 7, 5 },
			solution = {
				{ "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 },
				{ "wood", 0, 0, 3, 2 }, { "wood", 3, 2, 6, 0 }, { "wood", 3, 0, 3, 2 },
			},
			tip = "tip_triangles",
		},
		{
			id = "1-3",
			name = { en = "Struts", ru = "Подпорки" },
			budget = 1450,
			materials = { "road", "wood" },
			ground = { { -40, 0, 0 }, { 8, 40, 0 } },
			anchors = { { 0, 0 }, { 8, 0 }, { 0, -2 }, { 8, -2 } },
			start = -6, finish = 15, water = -4,
			area = { -1, -4, 9, 5 },
			solution = {
				{ "road", 0, 0, 3, 0 }, { "road", 3, 0, 5, 0 }, { "road", 5, 0, 8, 0 },
				{ "wood", 0, -2, 3, 0 }, { "wood", 8, -2, 5, 0 },
			},
			tip = "tip_supports",
		},
		{
			id = "1-4",
			name = { en = "Hanging Rock", ru = "Висячая скала" },
			budget = 1500,
			materials = { "road", "wood", "rope" },
			ground = { { -40, 0, 0 }, { 9, 40, 0 } },
			blocks = { { 1, 6, 8, 8 } },
			anchors = { { 0, 0 }, { 9, 0 }, { 3, 6 }, { 6, 6 } },
			start = -6, finish = 16, water = -4,
			area = { -1, -4, 10, 6 },
			solution = {
				{ "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 }, { "road", 6, 0, 9, 0 },
				{ "rope", 3, 0, 3, 6 }, { "rope", 6, 0, 6, 6 },
			},
			tip = "tip_rope",
		},
		{
			id = "1-5",
			name = { en = "Long Haul", ru = "Длинный пролёт" },
			budget = 3300,
			materials = { "road", "wood", "rope" },
			ground = { { -40, 0, 0 }, { 12, 40, 0 } },
			anchors = { { 0, 0 }, { 12, 0 }, { 0, -2 }, { 12, -2 } },
			start = -6, finish = 19, water = -4,
			area = { -1, -4, 13, 5 },
			solution = {
				{ "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 }, { "road", 6, 0, 9, 0 }, { "road", 9, 0, 12, 0 },
				{ "wood", 0, 0, 2, 2 }, { "wood", 2, 2, 3, 0 }, { "wood", 3, 0, 5, 2 }, { "wood", 5, 2, 6, 0 },
				{ "wood", 6, 0, 7, 2 }, { "wood", 7, 2, 9, 0 }, { "wood", 9, 0, 10, 2 }, { "wood", 10, 2, 12, 0 },
				{ "wood", 2, 2, 5, 2 }, { "wood", 5, 2, 7, 2 }, { "wood", 7, 2, 10, 2 },
				{ "wood", 0, -2, 3, 0 }, { "wood", 12, -2, 9, 0 },
			},
			tip = "tip_stars",
		},
		{
			id = "1-6",
			name = { en = "Twin Spans", ru = "Двойной пролёт" },
			budget = 2600,
			materials = { "road", "wood", "rope" },
			ground = { { -40, 0, 0 }, { 6, 10, 0 }, { 16, 40, 0 } },
			anchors = { { 0, 0 }, { 6, 0 }, { 10, 0 }, { 16, 0 } },
			start = -6, finish = 23, water = -4,
			area = { -1, -4, 17, 5 },
			solution = {
				{ "road", 0, 0, 3, 0 }, { "road", 3, 0, 6, 0 },
				{ "wood", 0, 0, 3, 2 }, { "wood", 3, 2, 6, 0 }, { "wood", 3, 0, 3, 2 },
				{ "road", 10, 0, 13, 0 }, { "road", 13, 0, 16, 0 },
				{ "wood", 10, 0, 13, 2 }, { "wood", 13, 2, 16, 0 }, { "wood", 13, 0, 13, 2 },
			},
		},
	},
}
