# Task 07: Починить Poki gameplayStart/Stop и добавить детальную воронку событий (Events)

- **Приоритет:** P1
- **Целевая метрика:** Корректные данные в столбце `Events` в Poki Player Fit Tests и точное измерение времени активного геймплея.

## Проблема в коде

1. **Преждевременный `poki.gameplay_stop()` при возврате в стройку (`world/world.script`, строка 122):**
   - В [`gui/app.gui_script`](../gui/app.gui_script) (строки 381–386) верно указано:
     `-- building is gameplay too` — `poki.gameplay_start()` вызывается при первом вводе в `build` или `drive`.
   - Но в [`world/world.script`](../world/world.script) (строка 122) внутри `elseif id == "drive_stopped" then` вызывается `poki.gameplay_stop()`!
   - И в `run_finished` (строка 195) при провале тоже вызывается `poki.gameplay_stop()`.
   - Как только игрок завершает тестовый проезд или нажимает `ЧИНИТЬ` / `R`, возвращаясь в **активную стройку**, SDK фиксирует остановку геймплея! В результате длительность непрерывных геймплей-сегментов дробится на 3–5-секундные огрызки, а время раздумий и проектирования моста может не засчитываться как геймплей до следующего клика.
2. **Искажение событий `level` (`world/world.script`, строки 108, 116, 197):**
   - `poki.level_start(id)` вызывается на `drive_started` (каждый тестовый запуск машины), а `poki.level_end(id, false)` — на каждом `drive_stopped` или падении.
   - Если игрок 5 раз тестирует прочность моста (что является нормой в bridge-builder!), в аналитику улетает `5 × level start` и `4 × level fail` для одного уровня.
3. **Не хватает воронки FTUE в `poki.measure`:**
   - Сейчас в Poki Player Fit Tests мы видим распределение времени выхода (`0–1m`, `1–2m`), но не видим точный шаг, на котором отваливаются 26% игроков в первую минуту: закрыли на сплэше, не поняли как тянуть балку на `1-1`, нажали `ПУСК!` без дороги, или сломались на `1-2` / `1-5`?

## Что нужно сделать

1. **Привести `gameplay_start` / `gameplay_stop` в соответствие с правилами Poki и `AGENT_GUIDELINES.md`:**
   - Убрать `poki.gameplay_stop()` из `drive_stopped` (возврат к стройке остаётся активным геймплеем!).
   - При провале (`run_finished` с `won == false`): не останавливать `gameplay`, если сразу возвращаемся в стройку (останавливать только если открыта модалка `result` с рекламой/паузой/выходом в меню, как в `app.set_paused(true)`, `exit_to_menu`, `commercial_break`, `rewarded_break`).
   - При `won == true` (`result` экран победы): останавливать `gameplay` на экране результата и возобновлять при начале действий на следующем уровне.
2. **Упорядочить `level_start` / `level_end` (`platform/poki.lua`, `world/world.script`):**
   - Отправлять `poki.level_start(id)` один раз при загрузке уровня (`level_loaded`), и `poki.level_end(id, true)` при победе (`won`), а `level_end(id, false)` — только если игрок вышел с нерешённого уровня в меню/другой уровень (сохраняя 1 `start` -> 1 `complete`/`fail` на попытку уровня).
   - Отдельные заезды/поломки можно логировать как `poki.measure("run", id, "start" / "win" / reason)` — это даст чистую статистику крашей без порчи воронки уровней.
3. **Добавить лёгкую воронку FTUE через `poki.measure("ftue", step, ...)`:**
   - Ключевые вехи первой сессии (отправлять 1 раз за профиль, с флагом в `progress`):
     - `level1_loaded`
     - `first_beam_built`
     - `first_drive_started`
     - `level1_won`
     - `level2_won`, `level3_won`, `level5_won`, `level8_won`
     - `garage_opened`

## Критерии приёмки

- [ ] В логе `tools/web_smoke.js` (`[poki] gameplayStart` / `gameplayStop`) переход `build -> drive -> fix -> build` не генерирует лишних `gameplayStop`.
- [ ] `gameplayStop` гарантированно срабатывает при паузе/сворачивании вкладки, рекламе, экране победы и выходе в меню.
- [ ] В `tests/test_runtime.lua` или отдельном тесте проверены вызовы `poki` lifecycle и идемпотентность `level_start`/`level_end`.
