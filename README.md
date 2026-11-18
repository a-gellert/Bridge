# Bridge Mad

Воксельная физическая головоломка для Poki (Defold, HTML5): строим мост из точки A в точку B и отправляем по нему транспорт.

- **Мотоцикл** — ★, **машина** — ★★, **грузовик** — ★★★. Звёзды уровня = лучший доехавший транспорт: если сразу проехал грузовик, уровень получает все 3 звезды.
- После заезда — экран результата: звёзды, кто доехал, сколько бюджета потрачено (сумма, % и рекорд), сдача в фонд гаража.
- 160 уровней в 4 главах по 40 (Зелёная долина, Красный каньон, Квантовая лаборатория, Ледяные горы). Главы открываются звёздами, материалы появляются по ходу кампании.
- 8 материалов: дорога, дерево, верёвка, сталь, трос, стальная дорога, ускоритель, батут. Элементы уровней: порталы, шипы, рампы, висячие скалы, опорные столбы.
- **Гараж:** 7 красок кузова, 5 вариантов колёс и 5 аксессуаров на крышу. Скины покупаются за сэкономленный бюджет, открываются за 18 звёзд главы или за rewarded-видео. Косметика не влияет на физику.
- **15 достижений** с тост-уведомлениями и экраном наград; за них платят деньги в фонд гаража.
- Живой воксельный мир: градиентное небо, три слоя гор с воздушной перспективой, дрейфующие облака, анимированная вода, трава, цветы, камни и постройки по берегам.
- Hero-декор из Blender: цветущее дерево, высокая сосна, каменная арка, руины, кристаллы и мельница с вращающимися лопастями; деревья качаются от ветра, летают птицы и бабочки, в воздухе — лепестки/пыль/искры/снег, на воде — блики.
- Сочность: пыль при приземлении, искры ускорителей, вспышки порталов, разлёт обломков, конфетти, следы шин, выхлоп, визг резины, треск перегруженных балок, динамический FOV и микро-slow-mo у финиша.
- Управление одинаково удобно мышью, тачем и с клавиатуры, в горизонтальной и в **вертикальной** ориентации. На тач-экранах цель балки поднимается над пальцем (touch lens), радиус магнитного захвата больше, педали крупнее, работает виброотдача.
- Безопасные зоны (вырезы, жестовая панель) учитываются в HUD через CSS `safe-area-inset`; на высоких DPI разрешение рендера ограничено для стабильных 60 FPS.
- Кастомная HTML5-оболочка `template/poki_template.html`: брендированный сплэш, прогресс-загрузка, разблокировка WebAudio по первому касанию, без логотипа Defold и нижней панели.

## Управление

| | Мышь / клавиатура | Тач |
|---|---|---|
| Балка | тянуть от узла; с выбранным узлом призрак следует за курсором; узел под курсором подсвечивается | тап по узлу, затем тап в конечную точку (цепочкой) или протянуть пальцем |
| Привязка | конец балки щёлкает (звук + вибро) на каждом новом узле сетки | то же |
| Удалить | правая кнопка (держать и вести — удаляет всё под курсором) / ластик (`E`), балка под ластиком подсвечивается красным | ластик + тап или проведение по балкам (с пустого места — сдвиг вида) |
| Отменить выбор | `Esc`: снимает выделение, затем выключает ластик, затем выход в меню | тап по пустому месту |
| Камера | колесо — масштаб, тянуть пустое место — сдвиг, `+`/`-` | щипок, тянуть пустое место |
| Вписать вид | кнопка-рамка над левым краем нижней панели | та же кнопка |
| Материал | `1`…`8` | кнопки внизу |
| Отмена | `Z` / `Backspace` | кнопка «Отмена» |
| Пуск | `Space` / `Enter` | «ПУСК!» |
| Газ / тормоз | `D`/`→`/`W`, `A`/`←`/`S` (в воздухе — наклон) | педали ГАЗ / ТОРМОЗ |
| Чинить мост | `R` / `Esc` / `Space` (Space переключает стройку и заезд) | «ЧИНИТЬ» |
| Гараж / награды | «ГАРАЖ» / «НАГРАДЫ» в меню | те же кнопки |
| Виброотдача | — | переключатель в правом верхнем углу меню |

Транспорт едет сам (круиз), газ ускоряет, тормоз тормозит и сдаёт назад.

## Структура

```
game/                 чистый Lua без API Defold (тестируется в Node)
  config/             tuning (константы), materials, vehicles, skins (косметика),
                      visuals (реестр моделей), themes
  physics/            sim.lua (XPBD: узлы, балки, разрушение, контакты, шины), vehicle.lua, terrain.lua
  bridge/             blueprint.lua (чертёж, бюджет, правила, undo, сохранение), snap.lua (сетка)
  core/               run.lua (один заезд и судейство), session.lua (состояние уровня),
                      progress.lua (звёзды/открытия/кошелёк/скины/сохранения),
                      achievements.lua (15 наград), events.lua, i18n.lua (en/ru)
  levels/             levels.lua (индекс) + chapter1..4.lua (данные уровней с эталонными решениями)
world/                3D-мир: world.script (оркестратор), camera, build_input (жесты стройки,
                      touch lens), level_view, bridge_view, vehicle_view (скины), fx, spawn
gui/                  app.gui_script (экраны, ввод, ресайз, пауза), ui.lua (кит на Druid), druid_style,
                      layout.lua (виртуальный холст + safe areas), screens/* (menu, levels, garage,
                      achievements, build, drive, result)
platform/             poki.lua (Poki SDK), ads.lua (Poki / native / no-op), device.lua (touch,
                      safe area), haptics.lua, audio.lua, boot.lua
template/             poki_template.html — брендированная HTML5-оболочка Poki
render/               рендер: мир (перспектива) + полупрозрачные + GUI
entities/             по одному .go на модель (их и заменяем)
assets/               модели (.gltf/.glb), материалы/шейдеры, палитра, UI-атлас, шрифт, звуки,
                      иконки магазинов (assets/icons); assets/vox — исходники .vox для MagicaVoxel
tools/                gen_assets.js (процедурные ассеты), gen/icons.js (иконки),
                      vox/ (вокселизация .vox <-> .gltf, превью),
                      blender/gen_models.py (hero-декор), preview*.js (превью)
tests/                Node + fengari: физика, уровни, сессия, мета-слой, рантайм на моке Defold
```

Скрипты не вызывают друг друга напрямую: общий Lua-стейт (`shared_state = 1`), состояние — в `game/core/session.lua`, уведомления — очереди `events.lua` (каждый скрипт читает свою очередь в своём `update`).

Физика своя (XPBD), встроенная физика Defold не используется (исключена в `main/game.appmanifest` — меньше билд). Силы физичны (`F = λ/h²`), поэтому прочность материалов задаётся в ньютонах и не зависит от числа подшагов.

## Как заменить модель

Логика никогда не ссылается на меши напрямую: только на id визуала из `game/config/visuals.lua`.

1. Положите модель (`.glb`/`.gltf`/`.dae`) в `assets/` и укажите её в `entities/<id>.go` (поле `mesh`). Материал: `voxel.material` (непрозрачный), `voxel_alpha.material` (полупрозрачный: вода, сетка, тени) или `sky.material` (незатенённое небо).
2. Если размер, центр или поворот отличаются от стоковой модели, задайте `scale`, `offset`, `rot` в `game/config/visuals.lua`.
3. Соглашения стоковых моделей (`tools/gen/models.js`): балки — 1 м вдоль X с центром в 0 (игра растягивает по длине), полотно толщиной 0,3 м, фермы в плоскостях z = ±1.38, транспорт — центр физического корпуса, колёса отдельными моделями.
4. Цвета берутся из общей палитры `tools/gen/palette.js` (UV в одну точку нужного цвета). Меняйте палитру — перекрашивается весь мир; декор и рельеф дополнительно тонируются темой уровня (`game/config/themes.lua`).

`node tools/gen_assets.js` перегенерирует модели, палитру, UI-иконки, звуки и фабрики, но **не трогает** существующие `entities/*.go` (ключ `--force` перезапишет их). Новые модели получают `.go` автоматически.

## Воксельные модели (MagicaVoxel)

Процедурные модели дополнительно живут как настоящие воксельные объёмы: исходник — `assets/vox/<id>.vox` (открывается в MagicaVoxel), рядом `<id>.json` хранит размер вокселя и смещение сетки в мировых координатах. `tools/vox/build.js` вокселизует модели из `tools/gen/models.js`; `node tools/gen_assets.js` и обычная сборка читают `.vox`, если он есть, и собирают `.gltf` с палитровыми UV — материал остаётся тем же (`voxel.material`), новых материалов нет.

```powershell
node tools/vox/build.js                  # все модели -> assets/vox/*.vox + assets/models/*.gltf
node tools/vox/build.js --only=veh_car   # точечно, через запятую
node tools/vox/build.js --preview        # + build/vox_previews/<id>.png (софт-рендер без движка)
node tools/vox/build.js --magicavoxel    # + копия в D:\Programs\MagicaVoxel-0.99.7.1-win64\vox\bridgemad
node tools/vox/build.js --cell-scale=1.3 # грубее воксель = меньше треугольников
node tools/vox/contact_sheet.js          # общий лист build/vox_contact_sheet.png
node tools/gen_assets.js --no-vox        # игнорировать .vox, вернуть процедурные модели
```

Правила пайплайна:

- палитра `.vox` — это палитра игры по порядку (`tools/gen/palette.js`), поэтому правка цвета в палитре переносится на модели; при перестановке цветов перегенерируйте `.vox`;
- сетка до 256³ (лимит MagicaVoxel), скрытые грани удаляются, соседние грани одного цвета сливаются (greedy meshing) — модель остаётся в 0,1–6k треугольников;
- вокселизация идёт от `tools/gen/models.js`: правка формы в JS перезапишет `.vox`, правка `.vox` переживёт `gen_assets` и сборку;
- динамические и растягиваемые модели (`terrain_*`, `water*`, `sky_band`, `zone`, `grid_dots`, `select_ring`, `shadow`, `portal_glow`) остаются процедурными: их тайлит и скейлит `world/level_view.lua`, воксельная сетка там исказилась бы;
- Blender-декор (`tools/blender/gen_models.py`) не вокселизуется — он уже финальный `.glb`.

## Blender-модели и живое окружение

Крупный декор и «жизнь» сцен рендерятся из отдельных `.glb`, собранных в Blender 5.2:

```powershell
& "D:\Programs\Blender\blender.exe" -b -P tools\blender\gen_models.py     # пересобрать модели
& "D:\Programs\Blender\blender.exe" -b -P tools\blender\render_previews.py # превью в build\blender_previews
node tools/gen_assets.js
```

`tools/blender/gen_models.py` создаёт `tree_blossom`, `pine_tall`, `rock_arch`, `ruin_arch`,
`crystal_cluster`, `windmill`, `windmill_blades`, `bird`, `butterfly`, `portal_blue`,
`portal_orange`, `lab_generator`, `lab_terminal`, `energy_pylon`, `chamber_sign`,
`cactus_saguaro`, `lantern_post`. UV каждой грани указывают в клетку общей палитры
`assets/textures/palette.png`, поэтому Defold-материал `voxel.material` красит их так же, как
процедурные модели.

Стиль геометрии: все жёсткие блоки строятся через `Builder.chamfer_box` — фаска на 12 рёбрах
и 8 срезанных углов, причём фаска красится в `lighten(color)`, поэтому ребро ловит светлый
тексель («drive mad»-объём). Органика собирается из нескольких смещённых `blob`/`tube`,
арки — непрерывным `arch_ring` с чередованием цветов вместо отдельных блоков.

### Студия для превью

`tools/blender/studio.py` — детерминированная продуктовая сцена: материал палитры
(Image Texture + Closest, как `voxel.material`), трёхступенчатый градиентный мир,
бесшовный циклорамный задник, софтбоксы key/fill/rim/top, камера 65 мм по габаритам объекта,
AgX + raytraced-тени в EEVEE. `render_previews.py` рендерит каждый `.glb` со своим ракурсом
(`VIEWS`) в `build/blender_previews/<id>.png` — так модель проверяется без Defold.

Скрипты работают и через живой Blender: `tools/blender/mcp_client.py` говорит с аддоном
BlenderMCP по сокету `127.0.0.1:9876` тем же протоколом, что и MCP-мост:

```powershell
& "D:\Programs\Blender\5.2\python\bin\python.exe" tools\blender\mcp_client.py --code "import runpy; runpy.run_path(r'D:/DProjects/Bridge/tools/blender/gen_models.py', run_name='__main__')"
& "D:\Programs\Blender\5.2\python\bin\python.exe" tools\blender\mcp_client.py --file some_script.py
```

`world/level_view.lua` добавляет:
- лендмарк главы на видимом берегу (мельница, руины, кристаллы или каменная арка);
- качание деревьев/кустов/цветов от ветра, вращение лопастей мельницы (ступица мельницы —
  `h + 4.72·s`, плоскость лопастей — `z + 1.45·s`, держите эти числа в синхроне с моделью);
- птиц, бабочек и ambient-частицы (лепестки, пыль, искры, снег);
- блики на воде.

`tools/preview.js` теперь читает и `.gltf`, и `.glb`, поэтому сцену можно проверить без движка:
`LEVEL=5 node run.js dump_scene.lua` затем `node ../tools/preview.js scene.json out.png`.

## Как добавить контент

- **Уровень** — запись в `game/levels/chapterN.lua` (формат с эталонным решением: `ground`/`ramps`/`blocks`/`anchors`/`portals`/`spikes` + `solution`). Удобнее всего через веб-редактор: `node tools/editor_server.js` → http://localhost:8088 (просмотр, правка, автотест уровня и сохранение). Массовая пересборка кампании: `node tools/gen/build_campaign.js --write` — набор архетипов в `tools/gen/level_kit.js`, каждый уровень проверяется headless-физикой. Обязательно поле `solution`: тест проверит, что эталон влезает в бюджет и правила, а грузовик по нему доезжает. Он же используется как подсказка (rewarded).
- **Глава** — новый файл `chapterN.lua` + строка `require("game.levels.chapterN")` в `CHAPTERS` (`game/levels/levels.lua`; только строковым литералом — Defold включает в билд лишь статически найденные модули) + тема в `game/config/themes.lua` (`sky`/`sky_top` — градиент неба, `ground`/`top`/`rock`/`water` — тонировка рельефа, `far` — горы, `decor` и `flowers` — список id декора).
- **Материал** — запись в `game/config/materials.lua` (стоимость, длина, масса, жёсткость, пределы растяжения/сжатия, `rope`, `drivable`, `surface`) + визуал в `visuals.lua` + иконка `mat_<id>` в `tools/gen/ui.js`.
- **Транспорт** — запись в `game/config/vehicles.lua` (корпус, колёса, мотор, подвеска, звёзды) + модели корпуса и колеса.

Подбор уровня: `cd tests && CHAPTER=2 node run.js check_chapter.lua` печатает результаты каждого транспорта; `playground_*.lua` — песочницы физики. Веб-редактор уровней: `node tools/editor_server.js` (порт 8088), там же кнопка проверки уровня грузовиком.

## Тесты

```
cd tests
npm install
node run.js          # core, levels (160 уровней, грузовик доезжает), session, meta, assets, runtime
node syntax.js       # компиляция всех Lua-исходников
```

`test_runtime.lua` запускает настоящие `world.script`, `app.gui_script` и рендер-скрипт на моке API Defold и проходит игру через UI (тапы в экранных координатах, кнопки по надписям, клавиатура, портрет/ландшафт).

Превью кадра без движка: `LEVEL=6 DRIVE=3 OUT=scene.json node run.js dump_scene.lua`, затем `node ../tools/preview.js scene.json out.png` и `node ../tools/preview_gui.js scene.json out.png out_ui.png`.

## Сборка

Откройте проект в Defold (1.9+), `Project → Fetch Libraries` (Poki SDK, Druid 1.3.0, defold-event), затем `Project → Bundle → HTML5` или `Project → Build Poki HTML5`. В `game.project` подключена брендированная оболочка `template/poki_template.html`, пакет `com.madgames.bridgemad`, `target_sdk_version=34`, динамическая ориентация и `max_pixel_ratio=1.5`.

Из командной строки (Defold в `D:/Programs/Defold` или `C:/Program Files (x86)/Defold`, либо `DEFOLD=...`):

```sh
sh tools/build_poki.sh            # release -> bundle/release/Bridge Mad + poki.zip (index.html в корне архива)
sh tools/build_poki.sh debug      # debug   -> bundle/debug/Bridge Mad
```

`poki.zip` пакуется `tar.exe` из Windows: пути внутри архива с прямыми слешами (у `Compress-Archive` из PowerShell 5.1 они обратные, и на сервере игра не находит `archive/`).

Смоук-тест в headless Edge/Chrome (мок Poki SDK, мышь, тач, клавиатура, скриншоты, счётчик ошибок Lua/JS; код выхода 1 при ошибках):

```sh
node tools/web_smoke.js "bundle/release/Bridge Mad" out --size=1280x720 \
  --steps="wait:9;click:640,150;drag:572,385,722,385;key:Space;hold:KeyD,2;shot:drive"
node tools/web_smoke.js "bundle/release/Bridge Mad" out --size=405x720 --touch=1 \
  --steps="wait:10;touchtap:165,357;touchtap:247,357;shot:built"
```

Poki: правила рекламы и паузы соблюдены в `platform/poki.lua` и `platform/ads.lua` — первые три уровня без межстраничной рекламы, интервал 180 с, реклама только по кнопке «Дальше», в гараже или в окне помощи, звук глушится, ввод блокируется, при сбое SDK есть таймаут 35 с, а без SDK награда выдаётся сразу (desktop/тесты). `poki-sdk.js` и `PokiSDK.init()` подключает только `extension-poki-sdk`: в `template/poki_template.html` намеренно нет второго тега (иначе SDK инициализируется дважды и все measure/загрузка дублируются). Первый `gameplayStart` отправляется по первому вводу игрока в уровне (`build`/`drive`), `gameplayStop` — в меню, на паузе и во время рекламы.

Для нативного Android/iOS `platform/ads.lua` — единая точка входа: при наличии глобального `admob`/`applovin` используются они, иначе игра продолжается без рекламы. Виброотдача работает через Web Vibration API; для нативного билда можно подключить расширение вибрации, не меняя вызовы `platform/haptics.lua`.

Подробности дизайна — `GDD.md`, правила для агентов — `AGENT_GUIDELINES.md`.
