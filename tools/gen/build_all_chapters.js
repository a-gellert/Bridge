// Automated builder & validator for all 160 campaign levels (40 per chapter).
const fs = require("fs");
const path = require("path");
const {
  checkLevelInLua,
  levelToLua,
  makeBoxTruss,
  buildPierBridge,
  buildPortalLevel
} = require("./gen_campaign_40");

const ROOT = path.resolve(__dirname, "../..");

function loadDump(name) {
  const file = path.join(ROOT, name);
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function validateAndTune(lvl) {
  const res = checkLevelInLua(lvl);
  if (!res.ok) {
    console.error(`FAILED ${lvl.id}: ${res.err || res.msg} (truck: ${res.truckRes}, empty: ${res.emptyRes})`);
    return null;
  }
  const marginCost = Math.ceil((res.cost * 1.18) / 50) * 50;
  lvl.budget = Math.max(marginCost, Math.ceil(res.cost * 1.1));
  console.log(`OK ${lvl.id}: cost ${res.cost} -> budget ${lvl.budget} (truck: ${res.truckRes})`);
  return lvl;
}

// -------------------------------------------------------------
// Chapter 1 Levels 7..40 (Green Valley)
// -------------------------------------------------------------
function makeChapter1() {
  const existing = loadDump("chapter1_dump.json");
  const levels = [...existing];

  const names = [
    ["Valley Span", "Пролёт долины"],
    ["Under-Arch", "Нижняя арка"],
    ["Terrace Step", "Ступень террасы"],
    ["River Island", "Речной остров"],
    ["King Post", "Шпренгель"],
    ["Deep Ravine", "Глубокий овраг"],
    ["Gentle Climb", "Пологий подъём"],
    ["Triple Bay", "Тройной пролёт"],
    ["Suspension Cradle", "Висячая люлька"],
    ["Steel Foothold", "Стальная опора"],
    ["Valley Incline", "Склон долины"],
    ["Island Causeway", "Островная дамба"],
    ["High Ridge", "Высокий гребень"],
    ["Valley Causeway", "Дамба долины"],
    ["Cascade Slopes", "Каскадные склоны"],
    ["River Pylon", "Речной пилон"],
    ["Great Warren", "Большой Уоррен"],
    ["Rope Suspension", "Веревочный мост"],
    ["Under-Slung", "Подвесной настил"],
    ["Heavy Haul", "Тяжёлый груз"],
    ["Split Terraces", "Раздельные уступы"],
    ["Timber Pylons", "Деревянные пилоны"],
    ["Valley Chasm", "Расселина долины"],
    ["Double Span", "Двойной пролёт"],
    ["Plateau Link", "Связь плато"],
    ["River Bend", "Излучина реки"],
    ["Howe Truss", "Ферма Гау"],
    ["Valley Gorge", "Ущелье долины"],
    ["Rock Anchorage", "Крепёж в скале"],
    ["Suspended Deck", "Висячий настил"],
    ["Inverted Arch", "Обратная арка"],
    ["Valley Pier Crossing", "Переправа на опорах"],
    ["Great Valley Bridge", "Большой мост долины"],
    ["Valley Masterpiece", "Триумф долины"]
  ];

  for (let num = 7; num <= 40; num++) {
    const nPair = names[num - 7];
    const span = 9 + Math.floor((num - 7) * 0.44);
    const segs = Math.max(3, Math.ceil(span / 2.6));
    const isPier = (span >= 18);

    let lvl;
    if (isPier) {
      lvl = buildPierBridge({
        id: `1-${num}`,
        name: { en: nPair[0], ru: nPair[1] },
        x0: 0, y0: 0, x1: span, y1: 0,
        pierX: Math.floor(span * 0.44), pierW: 2.4, pierY: -2.6,
        materials: ["road", "wood", "steel"],
        matRoad: "road", matTruss: "steel",
        water: -4
      });
    } else {
      lvl = makeBoxTruss({
        id: `1-${num}`,
        name: { en: nPair[0], ru: nPair[1] },
        x0: 0, y0: 0, x1: span, y1: 0,
        segments: segs, h: 2.4 + (span - 9) * 0.04,
        materials: num >= 16 ? ["road", "wood", "steel"] : ["road", "wood"],
        matRoad: "road", matTruss: num >= 16 ? "steel" : "wood",
        water: -4
      });
    }

    const tuned = validateAndTune(lvl);
    if (!tuned) throw new Error("Failed validation for " + lvl.id);
    levels.push(tuned);
  }

  return levels;
}

// -------------------------------------------------------------
// Chapter 2 Levels 7..40 (Desert Canyon)
// -------------------------------------------------------------
function makeChapter2() {
  const existing = loadDump("chapter2_dump.json");
  const levels = [...existing];

  const names = [
    ["Canyon Incline", "Подъём каньона"],
    ["Spire Crossing", "Переход шпиля"],
    ["Deep Chasm", "Глубокая расселина"],
    ["Mesa Overhang", "Козырёк месы"],
    ["Red Arch", "Красная арка"],
    ["Twin Spire Canyon", "Два шпиля"],
    ["Canyon Descent", "Спуск в каньон"],
    ["Heavy Canyon Hauler", "Тяжеловоз каньона"],
    ["Grand Suspension", "Большой висячий мост"],
    ["Red Spire Viaduct", "Виадук красного шпиля"],
    ["Canyon Windway", "Ущелье ветров"],
    ["Deep Gorge Bridge", "Мост глубокого ущелья"],
    ["Mesa Wave", "Волна месы"],
    ["Double Canyon Spire", "Двойной шпиль каньона"],
    ["High Wire", "На тросах"],
    ["Rock Bridge", "Каменный мост"],
    ["Heavy Roadway", "Тяжёлое полотно"],
    ["Desert Gorge", "Ущелье пустыни"],
    ["Canyon Skyway", "Небесный путь"],
    ["Massive Viaduct", "Огромный виадук"],
    ["Cantilever Ridge", "Консольный гребень"],
    ["Grand Canyon Crossing", "Переход Гранд-Каньона"],
    ["Extreme Incline", "Экстремальный подъём"],
    ["Titan Truss Viaduct", "Виадук титана"],
    ["Titan Truss", "Титан"],
    ["Canyon Master Span", "Главный пролёт каньона"],
    ["Red Chasm Skybridge", "Небесный мост расселины"],
    ["Gorge Overhang", "Козырёк ущелья"],
    ["Canyon Colossus", "Колосс каньона"],
    ["Double Mesa Link", "Мост двойной месы"],
    ["Desert Precipice", "Пустынный обрыв"],
    ["Iron Canyon", "Железный каньон"],
    ["Grand Canyon Viaduct", "Виадук Гранд-Каньона"],
    ["King of Canyons", "Царь каньонов"]
  ];

  for (let num = 7; num <= 40; num++) {
    const nPair = names[num - 7];
    const span = 14 + Math.floor((num - 7) * 0.45);
    const segs = Math.max(5, Math.ceil(span / 2.6));
    const isPier = (span >= 18);

    let lvl;
    if (isPier) {
      lvl = buildPierBridge({
        id: `2-${num}`,
        name: { en: nPair[0], ru: nPair[1] },
        x0: 0, y0: 0, x1: span, y1: 0,
        pierX: Math.floor(span * 0.44), pierW: 2.4, pierY: -2.6,
        materials: ["steel_road", "steel", "cable", "road", "wood"],
        matRoad: "steel_road", matTruss: "steel",
        water: -5
      });
    } else {
      lvl = makeBoxTruss({
        id: `2-${num}`,
        name: { en: nPair[0], ru: nPair[1] },
        x0: 0, y0: 0, x1: span, y1: 0,
        segments: segs, h: 2.5 + (span - 14) * 0.04,
        materials: ["steel_road", "steel", "cable", "road", "wood"],
        matRoad: "steel_road", matTruss: "steel",
        water: -6
      });
    }

    const tuned = validateAndTune(lvl);
    if (!tuned) throw new Error("Failed validation for " + lvl.id);
    levels.push(tuned);
  }

  return levels;
}

// -------------------------------------------------------------
// Chapter 3 Levels 7..40 (Quantum Lab)
// -------------------------------------------------------------
function makeChapter3() {
  const existing = loadDump("chapter3_dump.json");
  const levels = [...existing];

  const names = [
    ["Portal Vault", "Портальное хранилище"],
    ["Speed Conduit", "Скоростной шлюз"],
    ["Acid Abyss", "Кислотная бездна"],
    ["Test Chamber 10", "Тестовая камера 10"],
    ["Quantum Leap", "Квантовый скачок"],
    ["Vector Field", "Векторное поле"],
    ["Momentum Lab", "Лаборатория импульса"],
    ["Chamber Loop", "Петля камеры"],
    ["Singularity Gate", "Врата сингулярности"],
    ["Subatomic Bridge", "Субатомный мост"],
    ["Flux Highway", "Шоссе потока"],
    ["Resonance Chamber", "Резонансная камера"],
    ["Aperture Overpass", "Эстакада Апертуры"],
    ["Phase Inversion", "Инверсия фазы"],
    ["Hyperloop Test", "Гиперпетля"],
    ["Laser Corridor", "Лазерный коридор"],
    ["Thermal Pit", "Термическая яма"],
    ["Graviton Beam", "Гравитонный луч"],
    ["Tachyon Jump", "Тахионный прыжок"],
    ["Chamber 26", "Камера 26"],
    ["Chamber 27", "Камера 27"],
    ["Chamber 28", "Камера 28"],
    ["Chamber 29", "Камера 29"],
    ["Chamber 30", "Камера 30"],
    ["Chamber 31", "Камера 31"],
    ["Chamber 32", "Камера 32"],
    ["Chamber 33", "Камера 33"],
    ["Chamber 34", "Камера 34"],
    ["Chamber 35", "Камера 35"],
    ["Chamber 36", "Камера 36"],
    ["Chamber 37", "Камера 37"],
    ["Chamber 38", "Камера 38"],
    ["Final Test Chamber", "Финальная камера испытаний"],
    ["GLaDOS Chamber", "Камера ГЛэДОС"]
  ];

  for (let num = 7; num <= 40; num++) {
    const nPair = names[num - 7];
    const gap = 6 + (num % 4);
    const exitH = 4 + (num % 3);

    const lvl = buildPortalLevel({
      id: `3-${num}`,
      name: { en: nPair[0], ru: nPair[1] },
      entryX: gap + 4, entryY: 1.3, entryAngle: Math.PI,
      entryWallX0: gap + 5, entryWallX1: gap + 6, entryWallY0: 0, entryWallY1: 6,
      exitX: gap + 15, exitY: exitH + 1.4, exitAngle: 0,
      exitWallX0: gap + 13, exitWallX1: gap + 14, exitWallY0: exitH - 1, exitWallY1: exitH + 5,
      bridgeX0: 0, bridgeY0: 0, bridgeX1: gap, bridgeY1: 0, bridgeSegments: Math.ceil(gap / 2.6),
      materials: ["road", "wood", "steel", "cable", "boost", "steel_road"],
      boostApproach: false,
      water: -4
    });

    const tuned = validateAndTune(lvl);
    if (!tuned) throw new Error("Failed validation for " + lvl.id);
    levels.push(tuned);
  }

  return levels;
}

// -------------------------------------------------------------
// Chapter 4 Levels 7..40 (Frozen Mountains)
// -------------------------------------------------------------
function makeChapter4() {
  const existing = loadDump("chapter4_dump.json");
  const levels = [...existing];

  const names = [
    ["Glacier Span", "Ледниковый пролёт"],
    ["Summit Pass", "Перевал вершины"],
    ["Blizzard Ravine", "Метельный овраг"],
    ["Frozen Pylon", "Замёрзший пилон"],
    ["Ice Crevasse", "Ледяная расселина"],
    ["Avalanche Run", "Лавинный спуск"],
    ["Snow Peak Link", "Снежный пик"],
    ["Alpine Incline", "Альпийский подъём"],
    ["Frost Gorge", "Морозное ущелье"],
    ["Glacial Causeway", "Ледниковая дамба"],
    ["High Mountain Pass", "Высокогорный перевал"],
    ["Northern Ridge", "Северный гребень"],
    ["Ice Fall Bridge", "Мост ледопада"],
    ["Frozen Viaduct", "Ледяной виадук"],
    ["Summit Cableway", "Тросовый пик"],
    ["Snowy Chasm", "Снежная бездна"],
    ["Winter Arch", "Зимняя арка"],
    ["Mountain Pillar", "Опора горы"],
    ["Sub-Zero Span", "Пролёт при минус сорок"],
    ["Polar Crossing", "Полярный переход"],
    ["Frozen Spire", "Ледяной шпиль"],
    ["Glacial Abyss", "Ледниковая бездна"],
    ["Alpine Skyway", "Альпийский виадук"],
    ["Ice Highway", "Ледовая магистраль"],
    ["Snowdrift Crossing", "Сугробный переход"],
    ["Summit Master", "Хозяин вершины"],
    ["Blizzard Gorge", "Метельное ущелье"],
    ["Extreme Glacier", "Экстремальный ледник"],
    ["Titan of the Peaks", "Титан вершин"],
    ["Everest Challenge", "Вызов Эвереста"],
    ["Avalanche Master", "Повелитель лавин"],
    ["Glacier Colossus", "Ледниковый колосс"],
    ["King of the Mountain", "Царь горы"],
    ["The Ultimate Summit", "Абсолютная вершина"]
  ];

  for (let num = 7; num <= 40; num++) {
    const nPair = names[num - 7];
    const span = 15 + Math.floor((num - 7) * 0.44);
    const segs = Math.max(5, Math.ceil(span / 2.6));
    const isPier = (span >= 18);

    let lvl;
    if (isPier) {
      lvl = buildPierBridge({
        id: `4-${num}`,
        name: { en: nPair[0], ru: nPair[1] },
        x0: 0, y0: 0, x1: span, y1: 0,
        pierX: Math.floor(span * 0.44), pierW: 2.4, pierY: -2.6,
        materials: ["road", "steel", "cable", "steel_road", "wood", "boost"],
        matRoad: "steel_road", matTruss: "steel",
        water: -7
      });
    } else {
      lvl = makeBoxTruss({
        id: `4-${num}`,
        name: { en: nPair[0], ru: nPair[1] },
        x0: 0, y0: 0, x1: span, y1: 0,
        segments: segs, h: 2.6 + (span - 15) * 0.04,
        materials: ["road", "steel", "cable", "steel_road", "wood", "boost"],
        matRoad: "steel_road", matTruss: "steel",
        water: -6
      });
    }

    const tuned = validateAndTune(lvl);
    if (!tuned) throw new Error("Failed validation for " + lvl.id);
    levels.push(tuned);
  }

  return levels;
}

// -------------------------------------------------------------
// File Writers
// -------------------------------------------------------------
function writeChapterFile(chNum, id, theme, name, starsReq, levels) {
  const lines = [];
  lines.push(`-- Chapter ${chNum}: ${name.en}. 40 levels.`);
  lines.push(`return {`);
  lines.push(`\tid = "${id}",`);
  lines.push(`\ttheme = "${theme}",`);
  lines.push(`\tname = { en = "${name.en}", ru = "${name.ru}" },`);
  lines.push(`\tstars_required = ${starsReq},`);
  lines.push(`\tlevels = {`);

  for (const lvl of levels) {
    lines.push(levelToLua(lvl) + ",");
  }

  lines.push(`\t},`);
  lines.push(`}`);
  lines.push(``);

  const outPath = path.join(ROOT, `game/levels/chapter${chNum}.lua`);
  fs.writeFileSync(outPath, lines.join("\n"), "utf8");
  console.log(`Saved ${outPath} with ${levels.length} levels.`);
}

console.log("=== BUILDING CHAPTER 1 ===");
const ch1 = makeChapter1();
writeChapterFile(1, "valley", "valley", { en: "Green Valley", ru: "Зелёная долина" }, 0, ch1);

console.log("=== BUILDING CHAPTER 2 ===");
const ch2 = makeChapter2();
writeChapterFile(2, "canyon", "canyon", { en: "Red Canyon", ru: "Красный каньон" }, 10, ch2);

console.log("=== BUILDING CHAPTER 3 ===");
const ch3 = makeChapter3();
writeChapterFile(3, "lab", "lab", { en: "Quantum Lab", ru: "Квантовая лаборатория" }, 24, ch3);

console.log("=== BUILDING CHAPTER 4 ===");
const ch4 = makeChapter4();
writeChapterFile(4, "mountains", "mountains", { en: "Frozen Mountains", ru: "Ледяные горы" }, 45, ch4);

console.log("=== ALL 160 LEVELS SUCCESSFULLY GENERATED AND SAVED ===");
