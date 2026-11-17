-- Localization (English / Russian). Add a language = add a table with the same keys.
local M = {}

local STRINGS = {
	en = {
		title = "BRIDGE MAD",
		subtitle = "build it - drive it - break it",
		play = "PLAY", levels = "LEVELS", back = "BACK", menu = "MENU", next = "NEXT", retry = "RETRY",
		fix = "FIX BRIDGE", go = "GO!", undo = "UNDO", clear = "CLEAR", hint = "HINT", erase = "ERASE",
		sound = "SOUND", on = "ON", off = "OFF", settings = "SETTINGS", close = "CLOSE",
		budget = "BUDGET", chapter = "CHAPTER %d", level = "LEVEL %s", locked = "LOCKED",
		page_fmt = "Page %d / %d",
		need_stars = "%d stars to unlock", finish_prev = "Finish the previous chapter",
		total_stars = "%d / %d", cost_label = "$%s",
		gas = "GAS", brake = "BRAKE", stop = "STOP",
		pick_vehicle = "Pick a vehicle:",
		veh_moto = "Motorbike", veh_car = "Car", veh_truck = "Truck",
		mat_road = "Road", mat_wood = "Wood", mat_rope = "Rope", mat_steel = "Steel", mat_cable = "Cable",
		mat_steel_road = "Steel road", mat_boost = "Boost", mat_bounce = "Bounce",
		new_material = "NEW: %s",
		win_title = "DELIVERED!", fail_title = "OOPS!",
		delivered_by = "%s made it across", budget_used = "Budget used", budget_pct = "%d%% of budget",
		spent_of = "$%s of $%s", new_record = "NEW RECORD!", best_cost = "Best: $%s",
		try_heavier = "Send a heavier vehicle for more stars!", all_stars = "All stars collected!",
		reason_fell = "The vehicle fell!", reason_spikes = "Spikes!", reason_flipped = "Flipped over!",
		reason_stuck = "Got stuck!",
		err_budget = "Not enough money", err_long = "Too long for this material", err_rock = "Can't build inside rock",
		err_area = "Outside the build zone", err_exists = "Already built", err_short = "Too short",
		err_material = "Material not available",
		hint_used = "Blueprint loaded",
		tip_first = "Drag from a red anchor to the other anchor to lay a road. Then press GO!",
		tip_triangles = "Long roads sag and snap. Brace them with wooden triangles.",
		tip_supports = "Lower anchors can hold struts that push the road up.",
		tip_rope = "Ropes only pull. Hang the road from the rock above.",
		tip_stars = "A cheap bridge may carry the bike only. Heavier vehicles give more stars.",
		tip_steel = "Steel is strong and long, but pricey.",
		tip_cable = "Cables reach far and hold huge loads in tension.",
		tip_steel_road = "Steel road spans 4 m and carries the heaviest trucks.",
		tip_portal = "Portals keep your speed. Get to the blue one!",
		tip_portal2 = "The portal drops you off right before the gap.",
		tip_boost = "Boost pads speed up anything that drives over them.",
		tip_spikes = "Don't touch the spikes!",
		tip_bounce = "Bounce pads throw vehicles high into the air.",
		tip_mix = "Speed up first, then bounce.",
		tip_combo = "Catch the falling car with a bounce pad.",
		tip_controls_pc = "Hold D / Right for gas, A / Left to brake. Tilt in the air with the same keys. Space - back to building.",
		tip_controls_touch = "Hold GAS or BRAKE. In the air they tilt the vehicle.",
		tip_build_touch = "Tap a joint, then tap where the beam should end. Drag empty space to move the view.",
		tip_build_pc = "Drag from a joint to build. Hold the right button and sweep to delete. Wheel zooms.",
		-- meta / garage
		garage = "GARAGE", achievements = "AWARDS", wallet = "GARAGE FUND",
		kind_body = "PAINT", kind_wheel = "WHEELS", kind_topper = "TOPPER",
		owned = "OWNED", selected = "EQUIPPED", equip = "EQUIP", buy = "BUY",
		unlock_stars = "%d STARS", unlock_chapter = "ALL 18 STARS", unlock_rewarded = "WATCH AD", unlock_price = "$%s",
		not_enough_money = "Not enough money", skin_bought = "Unlocked: %s", skin_equipped = "%s equipped",
		skin_rewarded = "Golden skin unlocked!", reward_failed = "No reward this time",
		ach_unlocked = "%d / %d awards", ach_locked = "Locked", ach_toast = "AWARD: %s",
		ach_reward = "+$%s",
		salary = "Garage fund", salary_gain = "+$%s", salary_line = "%s in the garage",
		paused = "PAUSED", tap_resume = "Tap to continue",
		exit_title = "Leave Bridge Mad?", exit_yes = "QUIT", exit_no = "STAY",
		haptics = "VIBRATION", vibration = "VIBRATION",
		assist_budget = "+25% BUDGET", assist_hint = "Show blueprint (ad)",
		assist_offer = "Stuck? Get help and keep playing", budget_bonus = "+25% budget added!",
		hint_pulse = "Hint is ready!",
		auto_next = "NEXT LEVEL...",
		biome_offer_title = "NEW SETTING!",
		biome_offer_desc = "Explore the new setting: %s?",
		biome_offer_go = "VISIT %s",
		biome_offer_stay = "CONTINUE (%s)",
		-- achievements
		ach_first_bridge = "First Engineer", ach_first_bridge_d = "Build your first beam.",
		ach_engineer = "Bridge Builder", ach_engineer_d = "Have 10 beams in one design.",
		ach_thrifty = "Thrifty Genius", ach_thrifty_d = "Win a level using at most half of the budget.",
		ach_acrobat = "Air Acrobat", ach_acrobat_d = "Land a full 360-degree flip on the wheels.",
		ach_heavy_artillery = "Heavy Artillery", ach_heavy_artillery_d = "Deliver the truck without breaking a beam.",
		ach_quantum = "Quantum Leap", ach_quantum_d = "Pass 3 portals in one run.",
		ach_on_a_wing = "On a Wing and a Prayer", ach_on_a_wing_d = "Reach the finish after losing 80% of the bridge.",
		ach_star_collector = "Star Collector", ach_star_collector_d = "Collect all 72 stars.",
		ach_chapter_two = "Canyon Explorer", ach_chapter_two_d = "Complete a level in the Red Canyon chapter.",
		ach_speedrun = "Speed Demon", ach_speedrun_d = "Finish a level in 8 seconds or less.",
		ach_no_brake = "No Brakes", ach_no_brake_d = "Win a level without touching the brake.",
		ach_crash_test = "Crash Test Dummy", ach_crash_test_d = "Crash 10 times. For science.",
		ach_collector = "Collector", ach_collector_d = "Own 5 cosmetic items.",
		ach_persistent = "Never Give Up", ach_persistent_d = "Make 50 attempts.",
		ach_golden = "Golden Touch", ach_golden_d = "Unlock the Golden paint.",
	},
	ru = {
		title = "BRIDGE MAD",
		subtitle = "построй - проедь - сломай",
		play = "ИГРАТЬ", levels = "УРОВНИ", back = "НАЗАД", menu = "МЕНЮ", next = "ДАЛЬШЕ", retry = "ЕЩЁ РАЗ",
		fix = "ЧИНИТЬ", go = "ПУСК!", undo = "ОТМЕНА", clear = "СБРОС", hint = "ПОДСКАЗКА", erase = "ЛАСТИК",
		sound = "ЗВУК", on = "ВКЛ", off = "ВЫКЛ", settings = "НАСТРОЙКИ", close = "ЗАКРЫТЬ",
		budget = "БЮДЖЕТ", chapter = "ГЛАВА %d", level = "УРОВЕНЬ %s", locked = "ЗАКРЫТО",
		page_fmt = "Страница %d / %d",
		need_stars = "Нужно звёзд: %d", finish_prev = "Пройдите прошлую главу",
		total_stars = "%d / %d", cost_label = "$%s",
		gas = "ГАЗ", brake = "ТОРМОЗ", stop = "СТОП",
		pick_vehicle = "Выберите транспорт:",
		veh_moto = "Мотоцикл", veh_car = "Машина", veh_truck = "Грузовик",
		mat_road = "Дорога", mat_wood = "Дерево", mat_rope = "Верёвка", mat_steel = "Сталь", mat_cable = "Трос",
		mat_steel_road = "Стальная дорога", mat_boost = "Ускоритель", mat_bounce = "Батут",
		new_material = "НОВОЕ: %s",
		win_title = "ДОСТАВЛЕНО!", fail_title = "УПС!",
		delivered_by = "%s добрался до цели", budget_used = "Бюджет", budget_pct = "%d%% бюджета",
		spent_of = "$%s из $%s", new_record = "НОВЫЙ РЕКОРД!", best_cost = "Рекорд: $%s",
		try_heavier = "Отправьте транспорт тяжелее, чтобы получить больше звёзд!", all_stars = "Все звёзды собраны!",
		reason_fell = "Транспорт упал!", reason_spikes = "Шипы!", reason_flipped = "Перевернулся!",
		reason_stuck = "Застрял!",
		err_budget = "Не хватает денег", err_long = "Слишком длинно для материала", err_rock = "Нельзя строить в скале",
		err_area = "Вне зоны строительства", err_exists = "Уже построено", err_short = "Слишком коротко",
		err_material = "Материал недоступен",
		hint_used = "Чертёж загружен",
		tip_first = "Протяните дорогу от красной опоры к другой опоре. Затем нажмите ПУСК!",
		tip_triangles = "Длинная дорога прогибается и рвётся. Укрепите её деревянными треугольниками.",
		tip_supports = "От нижних опор можно поставить подпорки под дорогу.",
		tip_rope = "Верёвка работает только на растяжение. Подвесьте дорогу к скале.",
		tip_stars = "Дешёвый мост выдержит только мотоцикл. Транспорт тяжелее даёт больше звёзд.",
		tip_steel = "Сталь прочная и длинная, но дорогая.",
		tip_cable = "Тросы длинные и держат огромную нагрузку на растяжение.",
		tip_steel_road = "Стальная дорога перекрывает 4 м и держит самые тяжёлые грузовики.",
		tip_portal = "Порталы сохраняют скорость. Доберитесь до синего!",
		tip_portal2 = "Портал высадит вас прямо перед пропастью.",
		tip_boost = "Ускоритель разгоняет всё, что по нему едет.",
		tip_spikes = "Не касайтесь шипов!",
		tip_bounce = "Батут подбрасывает транспорт высоко в воздух.",
		tip_mix = "Сначала разгон, потом прыжок.",
		tip_combo = "Поймайте падающую машину батутом.",
		tip_controls_pc = "D / Вправо — газ, A / Влево — тормоз. В воздухе те же клавиши наклоняют машину. Пробел — к стройке.",
		tip_controls_touch = "Держите ГАЗ или ТОРМОЗ. В воздухе они наклоняют машину.",
		tip_build_touch = "Коснитесь узла, затем места, где закончится балка. Тяните пустое место, чтобы двигать вид.",
		tip_build_pc = "Тяните от узла, чтобы строить. Правая кнопка удаляет (можно провести). Колесо — масштаб.",
		-- meta / garage
		garage = "ГАРАЖ", achievements = "НАГРАДЫ", wallet = "ФОНД ГАРАЖА",
		kind_body = "КРАСКА", kind_wheel = "КОЛЁСА", kind_topper = "АКСЕССУАР",
		owned = "КУПЛЕНО", selected = "НАДЕТО", equip = "НАДЕТЬ", buy = "КУПИТЬ",
		unlock_stars = "%d ЗВЁЗД", unlock_chapter = "ВСЕ 18 ЗВЁЗД", unlock_rewarded = "СМОТРЕТЬ РЕКЛАМУ", unlock_price = "$%s",
		not_enough_money = "Не хватает денег", skin_bought = "Открыто: %s", skin_equipped = "%s надето",
		skin_rewarded = "Золотая краска открыта!", reward_failed = "Награда не получена",
		ach_unlocked = "%d / %d наград", ach_locked = "Закрыто", ach_toast = "НАГРАДА: %s",
		ach_reward = "+$%s",
		salary = "Фонд гаража", salary_gain = "+$%s", salary_line = "%s в гараже",
		paused = "ПАУЗА", tap_resume = "Коснитесь, чтобы продолжить",
		exit_title = "Выйти из Bridge Mad?", exit_yes = "ВЫЙТИ", exit_no = "ОСТАТЬСЯ",
		haptics = "ВИБРАЦИЯ", vibration = "ВИБРАЦИЯ",
		assist_budget = "+25% БЮДЖЕТА", assist_hint = "Показать чертёж (реклама)",
		assist_offer = "Застряли? Возьмите помощь и играйте дальше", budget_bonus = "Бюджет увеличен на 25%!",
		hint_pulse = "Подсказка доступна!",
		auto_next = "СЛЕДУЮЩИЙ УРОВЕНЬ...",
		biome_offer_title = "НОВЫЙ СЕТТИНГ!",
		biome_offer_desc = "Хотите перейти в сеттинг «%s»?",
		biome_offer_go = "В «%s»",
		biome_offer_stay = "ПРОДОЛЖИТЬ (%s)",
		-- achievements
		ach_first_bridge = "Первый инженер", ach_first_bridge_d = "Постройте первую балку.",
		ach_engineer = "Мостостроитель", ach_engineer_d = "Соберите 10 балок в одном чертеже.",
		ach_thrifty = "Экономный гений", ach_thrifty_d = "Пройдите уровень, потратив не более половины бюджета.",
		ach_acrobat = "Воздушный акробат", ach_acrobat_d = "Приземлитесь на колёса после полного оборота на 360°.",
		ach_heavy_artillery = "Тяжёлая артиллерия", ach_heavy_artillery_d = "Доставьте грузовик без единой сломанной балки.",
		ach_quantum = "Квантовый скачок", ach_quantum_d = "Пройдите 3 портала за один заезд.",
		ach_on_a_wing = "На честном слове", ach_on_a_wing_d = "Доедьте до финиша, потеряв 80% моста.",
		ach_star_collector = "Коллекционер звёзд", ach_star_collector_d = "Соберите все 72 звезды.",
		ach_chapter_two = "Исследователь каньона", ach_chapter_two_d = "Пройдите уровень в главе «Красный каньон».",
		ach_speedrun = "Скоростной демон", ach_speedrun_d = "Пройдите уровень за 8 секунд или быстрее.",
		ach_no_brake = "Без тормозов", ach_no_brake_d = "Победите, ни разу не нажав тормоз.",
		ach_crash_test = "Краш-тест", ach_crash_test_d = "Разбейтесь 10 раз. Ради науки.",
		ach_collector = "Коллекционер", ach_collector_d = "Владейте 5 косметическими предметами.",
		ach_persistent = "Не сдаваться", ach_persistent_d = "Сделайте 50 попыток.",
		ach_golden = "Золотое прикосновение", ach_golden_d = "Откройте золотую краску.",
	},
}

M.lang = "en"

function M.set_lang(lang)
	M.lang = STRINGS[lang] and lang or "en"
end

-- Device language code (e.g. "ru") -> supported language.
function M.detect(code)
	code = (code or ""):sub(1, 2):lower()
	if code == "ru" or code == "uk" or code == "be" or code == "kk" then return "ru" end
	return "en"
end

function M.t(key)
	local s = STRINGS[M.lang][key] or STRINGS.en[key]
	return s or key
end

function M.f(key, ...)
	local ok, s = pcall(string.format, M.t(key), ...)
	return ok and s or M.t(key)
end

-- Pick the current language from a { en = ..., ru = ... } table.
function M.pick(t)
	if type(t) ~= "table" then return tostring(t or "") end
	return t[M.lang] or t.en or ""
end

-- 12345 -> "12 345"
function M.money(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local neg = s:sub(1, 1) == "-"
	if neg then s = s:sub(2) end
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (neg and "-" or "") .. out
end

return M
