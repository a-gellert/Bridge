// Campaign v3: hand-flavoured levels for all four chapters, paced for the player path.
// Keeps the first hand-made levels of every chapter (1-1..1-10 in Green Valley,
// 2-1..2-6 / 3-1..3-6 / 4-1..4-6 elsewhere) and rebuilds the rest from archetypes.
// Every generated level is validated with the headless XPBD sim.
//
// Pacing. The player path rotates the biomes in blocks of 8 levels (game/levels/levels.lua:
// 1-1..1-8, 2-1..2-8, 3-1..3-8, 4-1..4-8, 1-9..1-16, ...), so "round" r = levels
// 8(r-1)+1..8r of every chapter is played together. Difficulty grows by round, not by chapter:
//   - budget slack: ROUND_MULT (reference cost * mult), from 1.30 in round 1 to 1.18 in round 5;
//   - span size: rounds 1-2 stay within ~6-12 m, the long 16-22 m bridges are round 5 only;
//   - every block mixes short levels (king posts, cradles, portals, jumps) with trusses.
// Every reference bridge sits on the 1 m build grid (level_kit `grid` mode), so the bridge the
// budget is fitted to is one a player can actually draw.
//
//   node tools/gen/build_campaign.js            (validate only)
//   node tools/gen/build_campaign.js --write    (write chapter files)
//   node tools/gen/build_campaign.js --chapter=2 --write (one chapter)
//
// --write keeps the hand-made part of each chapter file as text (comments and fields such as
// tutorial / brace_hint survive) and only rewrites the budgets of hand-made levels that are
// tighter than round 1 allows (chapters 2-4).
const fs = require("fs");
const path = require("path");
const {
  spanLevel, archLevel, humpLevel, caveLevel, kingpostLevel, suspensionLevel,
  islandsLevel, pillarLevel, jumpLevel, bounceLevel, portalHighLevel,
  portalVaultLevel, portalLaunchLevel, portalCatchLevel, portalChain2Level, portalChain3Level,
  fitBudget, test,
} = require("./level_kit");
const { buildPierBridge } = require("./gen_campaign_40");
const { levelToLua } = require("./gen_campaign_40");
const { loadAllChapters } = require("../editor_server");

const ROOT = path.resolve(__dirname, "../..");
// Levels that are authored and preserved verbatim by the generator.
const HANDMADE = { 1: 10, 2: 6, 3: 6, 4: 6 };
const BLOCK = 8;
// Budget = reference cost * mult, by round (level number within the chapter).
const ROUND_MULT = [1.3, 1.28, 1.25, 1.22, 1.18];
const roundOf = (num) => Math.min(ROUND_MULT.length, Math.ceil(num / BLOCK));
const multFor = (num) => ROUND_MULT[roundOf(num) - 1];
// Round 1 hand-made levels may not be tighter than this (cost / budget).
const ROUND1_MAX_RATIO = 0.78;

const M1R = ["road", "wood", "rope"];
const M1S = ["road", "wood", "rope", "steel"];
const M1SR = ["road", "wood", "rope", "steel", "steel_road"];
const M2 = ["road", "wood", "steel", "cable", "steel_road"];
const M3 = ["road", "wood", "steel", "cable", "steel_road", "boost"];
const M3B = ["road", "wood", "steel", "cable", "steel_road", "boost", "bounce"];
const M4 = ["road", "wood", "steel", "cable", "steel_road", "boost", "bounce"];

function L(type, en, ru, opts) {
  return { type, en, ru, opts };
}

function spikesUnder(x0, x1, top) {
  return [[x0, top - 0.8, x1, top]];
}

function buildSpec(spec, id) {
  const o = { grid: true, ...spec.opts, id, name: { en: spec.en, ru: spec.ru } };
  switch (spec.type) {
    case "flat":
    case "slope":
    case "under":
      return spanLevel(o);
    case "arch":
      return archLevel(o);
    case "hump":
      return humpLevel(o);
    case "cave":
      return caveLevel(o);
    case "king":
      return kingpostLevel(o);
    case "susp":
      return suspensionLevel(o);
    case "islands":
      return islandsLevel(o);
    case "pillar":
      return pillarLevel(o);
    case "jump":
      return jumpLevel(o);
    case "bounce":
      return bounceLevel(o);
    case "portal":
      return portalHighLevel(o);
    case "vault":
      return portalVaultLevel(o);
    case "launch":
      return portalLaunchLevel(o);
    case "catch":
      return portalCatchLevel(o);
    case "chain2":
      return portalChain2Level(o);
    case "chain3":
      return portalChain3Level(o);
    case "pier":
      return buildPierBridge({ ...o, budget: 99999 });
    default:
      throw new Error("unknown level type " + spec.type);
  }
}

// ----------------------------------------------------------------------------
// Chapter 1: Green Valley (road, wood, rope; steel from 1-16, steel road at 1-40)
// ----------------------------------------------------------------------------
const CH1 = [
  // round 2 (1-11..1-16)
  L("king", "King's Post", "Королевский столб", { x0: 0, x1: 8, rise: 2, stayMat: "wood", materials: M1R, water: -4, tip: "tip_rope" }),
  L("pillar", "Ridge Road", "Дорога на гребень", { x0: 0, rightX: 10, mid: 5, height: 2, materials: M1R, water: -6, tip: "tip_supports" }),
  L("launch", "Far Reach", "Дальний пролёт", { x1: 8, height: 2, trussMat: "wood", exitX: 18, exitY: 11, highY: 9, finish: 34, materials: M1R, tip: "tip_portal" }),
  L("under", "Under-Slung", "Подвесной настил", { x0: 0, x1: 9, height: 2, mode: "below", materials: M1R, water: -6, tip: "tip_supports" }),
  L("susp", "Rope Cradle", "Верёвочная люлька", { x0: 0, x1: 9, towerY: 6, towerInset: 2, cableMat: "rope", materials: M1R, water: -5, tip: "tip_rope" }),
  L("flat", "Iron Valley", "Железная долина", { x0: 0, x1: 12, height: 2, trussMat: "steel", materials: M1S, water: -5, tip: "tip_steel" }),
  // round 3 (1-17..1-24)
  L("islands", "River Bend", "Излучина реки", { gaps: [{ x0: 0, x1: 6 }, { x0: 9, x1: 15 }], mode: "above", height: 2, materials: M1S, water: -4, tip: "tip_triangles" }),
  L("catch", "Hanging Valley", "Висячая долина", { bridgeX0: -8, bridgeX1: 0, startY: 8, height: 2, trussMat: "wood", ledge: 4, portalX: 12, portalY: 1.3, exitX: 26, farX: 22, finish: 36, materials: M1S, tip: "tip_portal" }),
  L("king", "Steel Crown", "Стальная корона", { x0: 0, x1: 10, rise: 2, stayMat: "steel", materials: M1S, water: -5, tip: "tip_steel" }),
  L("cave", "Echo Cave", "Пещера эха", { x0: 0, x1: 10, height: 2, trussMat: "steel", materials: M1S, water: -5, tip: "tip_supports" }),
  L("pillar", "Rock Pillar", "Каменный столп", { x0: 0, rightX: 12, mid: 6, height: 2, materials: M1S, water: -6, tip: "tip_supports" }),
  L("chain2", "Twin Gorge", "Двойное ущелье", { b1x1: 6, highY: 5, b2x0: 22, b2x1: 28, b1mat: "wood", b2mat: "wood", height: 2, materials: M1S, tip: "tip_portal" }),
  L("arch", "Sunrise Arch", "Арка рассвета", { x0: 0, x1: 12, rise: 2, height: 2, trussMat: "steel", materials: M1S, water: -5, tip: "tip_triangles" }),
  L("hump", "Camel Back", "Верблюжий горб", { x0: 0, x1: 11, rise: 1, height: 2, trussMat: "steel", materials: M1S, water: -4, tip: "tip_triangles" }),
  // round 4 (1-25..1-32)
  L("slope", "Highland Rise", "Подъём на плато", { x0: 0, x1: 12, y0: 0, y1: 3, height: 2, trussMat: "steel", materials: M1S, water: -6, tip: "tip_triangles" }),
  L("vault", "Needle Pass", "Игольный перевал", { x1: 8, y1: 3, height: 2, trussMat: "steel", plateau: 6, exitDX: 12, finishDX: 22, materials: M1S, tip: "tip_portal" }),
  L("king", "Twin Crowns", "Двойная корона", { x0: 0, x1: 12, apexes: 2, rise: 2, stayMat: "steel", materials: M1S, water: -5, tip: "tip_steel" }),
  L("islands", "Three Brooks", "Три ручья", { gaps: [{ x0: 0, x1: 6 }, { x0: 9, x1: 15 }, { x0: 18, x1: 24 }], mode: "below", height: 2, trussMat: "steel", materials: M1S, water: -6, tip: "tip_supports" }),
  L("susp", "Cascade Crossing", "Каскадная переправа", { x0: 0, x1: 12, towerY: 6, towerInset: 2, cableMat: "rope", materials: M1S, water: -5, tip: "tip_rope" }),
  L("flat", "Green Viaduct", "Зелёный виадук", { x0: 0, x1: 14, height: 3, trussMat: "steel", materials: M1S, water: -6, tip: "tip_steel" }),
  L("launch", "Giant's Steps", "Шаги великана", { x1: 10, height: 2, trussMat: "steel", exitX: 20, exitY: 11, highY: 9, finish: 36, materials: M1S, tip: "tip_portal" }),
  L("cave", "Deep Grotto", "Глубокий грот", { x0: 0, x1: 12, height: 2, trussMat: "steel", materials: M1S, water: -6, tip: "tip_supports" }),
  // round 5 (1-33..1-40)
  L("pillar", "Great Pier", "Великая опора", { x0: 0, rightX: 16, mid: 8, height: 2, trussMat: "steel", materials: M1S, water: -7, tip: "tip_steel" }),
  L("arch", "Grand Arch", "Большая арка", { x0: 0, x1: 14, rise: 2, height: 2, trussMat: "steel", materials: M1S, water: -6, tip: "tip_triangles" }),
  L("under", "River Pier", "Речная опора", { x0: 0, x1: 14, height: 2, mode: "below", trussMat: "steel", materials: M1S, water: -8, tip: "tip_supports" }),
  L("hump", "Rolling Hills", "Волнистые холмы", { x0: 0, x1: 15, rise: 2, height: 2, trussMat: "steel", materials: M1S, water: -5, tip: "tip_triangles" }),
  L("cave", "Bedrock Tunnel", "Тоннель в скале", { x0: 0, x1: 16, height: 2, trussMat: "steel", materials: M1S, water: -6, tip: "tip_supports" }),
  L("flat", "Valley Masterpiece", "Шедевр долины", { x0: 0, x1: 16, height: 2, mode: "both", trussMat: "steel", materials: M1S, water: -7, tip: "tip_stars" }),
  L("arch", "Flying Arch", "Летящая арка", { x0: 0, x1: 16, rise: 3, height: 2, trussMat: "steel", materials: M1S, water: -7, tip: "tip_triangles" }),
  L("flat", "Valley Colossus", "Колосс долины", { x0: 0, x1: 18, height: 3, deckMat: "steel_road", trussMat: "steel", materials: M1SR, water: -8, tip: "tip_stars" }),
];

// ----------------------------------------------------------------------------
// Chapter 2: Red Canyon (steel, cable, steel road): the pure bridge-building biome
// ----------------------------------------------------------------------------
const CH2 = [
  // round 1 tail (2-7, 2-8)
  L("king", "Crown of Spires", "Корона шпилей", { x0: 0, x1: 10, rise: 3, stayMat: "cable", materials: M2, water: -6, tip: "tip_cable" }),
  L("flat", "Canyon Spine", "Хребет каньона", { x0: 0, x1: 10, height: 2, trussMat: "steel", materials: M2, water: -6, tip: "tip_steel" }),
  // round 2 (2-9..2-16)
  L("susp", "Cable Cradle", "Тросовая люлька", { x0: 0, x1: 12, towerY: 7, towerInset: 2, cableMat: "cable", materials: M2, water: -6, tip: "tip_cable" }),
  L("slope", "Mesa Climb", "Подъём на месу", { x0: 0, x1: 10, y0: 0, y1: 2, height: 2, trussMat: "steel", materials: M2, water: -7, tip: "tip_triangles" }),
  L("pillar", "Needle Pillar", "Игла", { x0: 0, rightX: 12, mid: 6, height: 2, trussMat: "steel", materials: M2, water: -8, tip: "tip_steel" }),
  L("cave", "Sand Grotto", "Песчаный грот", { x0: 0, x1: 10, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -7, tip: "tip_supports" }),
  L("king", "Twin Buttes", "Два холма", { x0: 0, x1: 12, apexes: 2, rise: 3, stayMat: "cable", materials: M2, water: -7, tip: "tip_cable" }),
  L("under", "Red Underpass", "Красный подлаз", { x0: 0, x1: 10, height: 2, mode: "below", trussMat: "steel", materials: M2, water: -8, tip: "tip_supports" }),
  L("islands", "Spire Islands", "Острова шпилей", { gaps: [{ x0: 0, x1: 6 }, { x0: 9, x1: 15 }], mode: "above", height: 2, trussMat: "steel", materials: M2, water: -7, tip: "tip_steel" }),
  L("hump", "Dune Wave", "Дюнная волна", { x0: 0, x1: 11, rise: 1, height: 2, trussMat: "steel", materials: M2, water: -6, tip: "tip_triangles" }),
  // round 3 (2-17..2-24)
  L("arch", "Red Arch", "Красная арка", { x0: 0, x1: 12, rise: 2, height: 2, trussMat: "steel", materials: M2, water: -7, tip: "tip_triangles" }),
  L("susp", "Wire Crossing", "Переправа на тросах", { x0: 0, x1: 14, towerY: 7, towerInset: 2, cableMat: "cable", materials: M2, water: -8, tip: "tip_cable" }),
  L("flat", "Iron Road", "Железная дорога", { x0: 0, x1: 12, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -7, tip: "tip_steel_road" }),
  L("king", "Canyon Pier", "Опора каньона", { x0: 0, x1: 12, rise: 3, stayMat: "cable", materials: M2, water: -7, tip: "tip_cable" }),
  L("islands", "Three Spires", "Три шпиля", { gaps: [{ x0: 0, x1: 6 }, { x0: 9, x1: 15 }, { x0: 18, x1: 24 }], mode: "above", height: 2, trussMat: "steel", materials: M2, water: -8, tip: "tip_steel" }),
  L("cave", "Cave of Echoes", "Пещера отзвуков", { x0: 0, x1: 12, height: 2, trussMat: "steel", materials: M2, water: -7, tip: "tip_supports" }),
  L("under", "Under the Rim", "Под обрывом", { x0: 0, x1: 12, height: 2, mode: "below", trussMat: "steel", materials: M2, water: -9, tip: "tip_supports" }),
  L("pillar", "Stone Needle", "Каменная игла", { x0: 0, rightX: 14, mid: 7, height: 2, trussMat: "steel", materials: M2, water: -9, tip: "tip_steel" }),
  // round 4 (2-25..2-32)
  L("hump", "Red Wave", "Красная волна", { x0: 0, x1: 14, rise: 2, height: 2, trussMat: "steel", materials: M2, water: -8, tip: "tip_triangles" }),
  L("susp", "Grand Cable", "Большой трос", { x0: 0, x1: 16, towerY: 8, towerInset: 2, cableMat: "cable", materials: M2, water: -8, tip: "tip_cable" }),
  L("slope", "Canyon Viaduct", "Виадук каньона", { x0: 0, x1: 12, y0: 0, y1: 3, height: 2, trussMat: "steel", materials: M2, water: -8, tip: "tip_triangles" }),
  L("king", "Twin Canyons", "Два каньона", { x0: 0, x1: 15, apexes: 2, rise: 3, stayMat: "cable", materials: M2, water: -7, tip: "tip_cable" }),
  L("arch", "Sunset Arch", "Арка заката", { x0: 0, x1: 15, rise: 2, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -8, tip: "tip_steel_road" }),
  L("islands", "Broken Mesa", "Расколотая меса", { gaps: [{ x0: 0, x1: 8 }, { x0: 11, x1: 19 }], mode: "below", height: 2, trussMat: "steel", materials: M2, water: -10, tip: "tip_supports" }),
  L("cave", "Deep Cave", "Глубокая пещера", { x0: 0, x1: 14, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -8, tip: "tip_supports" }),
  L("flat", "Steel Highway", "Стальное шоссе", { x0: 0, x1: 16, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -8, tip: "tip_steel_road" }),
  // round 5 (2-33..2-40)
  L("pillar", "Red Pier", "Красная опора", { x0: 0, rightX: 18, mid: 9, height: 2, trussMat: "steel", materials: M2, water: -9, tip: "tip_steel" }),
  L("susp", "Sky Cable", "Небесный трос", { x0: 0, x1: 18, towerY: 9, towerInset: 2, cableMat: "cable", materials: M2, water: -9, tip: "tip_cable" }),
  L("arch", "Mesa Arch", "Арка месы", { x0: 0, x1: 17, rise: 2, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -9, tip: "tip_triangles" }),
  L("islands", "Four Mesas", "Четыре месы", { gaps: [{ x0: 0, x1: 5 }, { x0: 8, x1: 13 }, { x0: 16, x1: 21 }, { x0: 24, x1: 29 }], mode: "above", height: 2, trussMat: "steel", materials: M2, water: -9, tip: "tip_steel" }),
  L("cave", "Canyon Tunnel", "Тоннель каньона", { x0: 0, x1: 16, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -9, tip: "tip_supports" }),
  L("pillar", "Titan Pier", "Титан-опора", { x0: 0, rightX: 20, mid: 10, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -11, tip: "tip_steel_road" }),
  L("king", "Steel Colossus", "Стальной колосс", { x0: 0, x1: 18, apexes: 2, rise: 3, stayMat: "cable", deckMat: "steel_road", materials: M2, water: -9, tip: "tip_cable" }),
  L("flat", "Red Canyon Master", "Мастер каньона", { x0: 0, x1: 20, height: 2, mode: "both", deckMat: "steel_road", trussMat: "steel", materials: M2, water: -11, tip: "tip_stars" }),
];

// ----------------------------------------------------------------------------
// Chapter 3: Quantum Lab (portals, spikes, boost; bounce from 3-19)
// ----------------------------------------------------------------------------
const CH3 = [
  // round 1 tail (3-7, 3-8)
  L("jump", "Boost Leap", "Прыжок на ускорителе", { edge: 2, landing: 16, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M3, water: -8, tip: "tip_boost" }),
  L("vault", "Warp Gate", "Врата варпа", { x1: 8, y1: 3, height: 2, trussMat: "steel", plateau: 6, exitDX: 12, finishDX: 22, materials: M3, tip: "tip_portal" }),
  // round 2 (3-9..3-16)
  L("flat", "Spike Run", "Шипованный пролёт", { x0: 0, x1: 8, height: 2, materials: M3, water: -6, spikes: spikesUnder(0, 8, -3), tip: "tip_spikes" }),
  L("launch", "Portal Vault", "Портальное хранилище", { x1: 10, height: 2, trussMat: "wood", exitX: 20, exitY: 11, highY: 9, finish: 36, materials: M3, tip: "tip_portal" }),
  L("king", "Rope Gauntlet", "Верёвочная тропа", { x0: 0, x1: 8, rise: 2, stayMat: "wood", materials: M3, water: -5, spikes: spikesUnder(0, 8, -3), tip: "tip_rope" }),
  L("jump", "Momentum Gate", "Врата импульса", { edge: 2, landing: 14, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M3, water: -8, tip: "tip_boost" }),
  L("catch", "Falling Gate", "Падающие врата", { bridgeX0: -8, bridgeX1: 0, startY: 8, height: 2, trussMat: "wood", ledge: 4, portalX: 12, portalY: 1.3, exitX: 26, farX: 22, finish: 36, materials: M3, tip: "tip_portal" }),
  L("cave", "Test Chamber", "Тестовая камера", { x0: 0, x1: 10, height: 2, trussMat: "steel", materials: M3, water: -6, tip: "tip_supports" }),
  L("chain2", "Portal Pillar", "Портальная игла", { b1x1: 6, highY: 5, b2x0: 22, b2x1: 28, b1mat: "wood", b2mat: "wood", height: 2, materials: M3, tip: "tip_portal" }),
  L("susp", "Spike Suspension", "Подвесной над шипами", { x0: 0, x1: 11, towerY: 7, towerInset: 2, cableMat: "cable", materials: M3, water: -7, spikes: spikesUnder(0, 11, -5), tip: "tip_cable" }),
  // round 3 (3-17..3-24)
  L("jump", "Boost Chasm", "Ускорительная пропасть", { edge: 2, landing: 16, deckY: 0, landingY: -3, rampLen: 4, rampRise: 1.3, materials: M3, water: -9, spikes: spikesUnder(8, 16, -4), tip: "tip_boost" }),
  L("islands", "Island Lab", "Лаборатория островов", { gaps: [{ x0: 0, x1: 6 }, { x0: 9, x1: 15 }], mode: "above", height: 2, trussMat: "steel", materials: M3, water: -7, spikes: spikesUnder(0, 15, -4), tip: "tip_steel" }),
  L("bounce", "Quantum Bounce", "Квантовый батут", { edge: 4, landing: 16, deckY: 0, landingY: -2, materials: M3B, water: -8, tip: "tip_bounce" }),
  L("vault", "High Portal", "Высокий портал", { x1: 10, y1: 4, height: 2, trussMat: "steel", plateau: 7, exitDX: 14, finishDX: 24, materials: M3B, tip: "tip_portal" }),
  L("arch", "Neon Arch", "Неоновый мост", { x0: 0, x1: 12, rise: 2, height: 2, trussMat: "steel", materials: M3B, water: -6, spikes: spikesUnder(0, 12, -4), tip: "tip_triangles" }),
  L("flat", "Flux Highway", "Шоссе потока", { x0: 0, x1: 12, height: 2, deckMat: "boost", trussMat: "steel", materials: M3B, water: -7, tip: "tip_boost" }),
  L("chain2", "Portal Loop", "Петля портала", { b1x1: 6, highY: 6, b2x0: 22, b2x1: 30, b1mat: "wood", b2mat: "steel", height: 2, materials: M3B, tip: "tip_portal" }),
  L("pillar", "Crystal Pillar", "Кристальный столп", { x0: 0, rightX: 14, mid: 7, height: 2, trussMat: "steel", materials: M3B, water: -8, spikes: spikesUnder(0, 14, -4), tip: "tip_steel" }),
  // round 4 (3-25..3-32)
  L("bounce", "Lab Trampoline", "Лабораторный батут", { edge: 4, landing: 20, deckY: 0, landingY: -3, materials: M3B, water: -9, tip: "tip_bounce" }),
  L("launch", "Mirror Gate", "Зеркальные врата", { x1: 12, height: 2, trussMat: "steel", exitX: 22, exitY: 11, highY: 9, finish: 38, materials: M3B, tip: "tip_portal" }),
  L("cave", "Needle Cave", "Пещера шипов", { x0: 0, x1: 12, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M3B, water: -7, spikes: spikesUnder(0, 12, -3.4), tip: "tip_spikes" }),
  L("jump", "Rocket Rail", "Ракетные рельсы", { edge: 2, landing: 13, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M3B, water: -9, tip: "tip_boost" }),
  L("chain3", "Quantum Leap", "Квантовый скачок", { b1x1: 8, highY: 6, b2x0: 24, b2x1: 32, b1mat: "wood", b2mat: "steel", height: 2, materials: M3B, tip: "tip_portal" }),
  L("king", "Spike Crown", "Корона шипов", { x0: 0, x1: 10, rise: 2, stayMat: "steel", materials: M3B, water: -7, spikes: spikesUnder(0, 10, -3.2), tip: "tip_spikes" }),
  L("catch", "Photon Gate", "Фотонные врата", { bridgeX0: -10, bridgeX1: 0, startY: 8, height: 2, trussMat: "steel", ledge: 4, portalX: 14, portalY: 1.3, exitX: 28, farX: 24, finish: 38, materials: M3B, tip: "tip_portal" }),
  L("susp", "Hanging Wires", "Висячие тросы", { x0: 0, x1: 16, towerY: 8, towerInset: 2, cableMat: "cable", materials: M3B, water: -8, spikes: spikesUnder(0, 16, -4), tip: "tip_cable" }),
  // round 5 (3-33..3-40)
  L("islands", "Reactors", "Реакторы", { gaps: [{ x0: 0, x1: 7 }, { x0: 10, x1: 17 }, { x0: 20, x1: 27 }], mode: "below", height: 2, deckMat: "steel_road", trussMat: "steel", materials: M3B, water: -9, spikes: spikesUnder(0, 27, -5), tip: "tip_steel_road" }),
  L("bounce", "Bounce Reactor", "Батут-реактор", { edge: 4, landing: 24, deckY: 0, landingY: -4, materials: M3B, water: -10, spikes: spikesUnder(12, 24, -5), tip: "tip_mix" }),
  L("chain2", "Twin Gates", "Двойные врата", { b1x1: 10, highY: 7, b2x0: 28, b2x1: 36, b1mat: "wood", b2mat: "steel", height: 2, materials: M3B, tip: "tip_portal" }),
  L("flat", "Spike Bridge", "Мост над шипами", { x0: 0, x1: 16, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M3B, water: -6, spikes: spikesUnder(0, 16, -3.2), tip: "tip_spikes" }),
  L("arch", "Singularity Arch", "Арка сингулярности", { x0: 0, x1: 16, rise: 2, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M3B, water: -8, spikes: spikesUnder(0, 16, -4), tip: "tip_triangles" }),
  L("pillar", "Graviton Needle", "Гравитонная игла", { x0: 0, rightX: 18, mid: 9, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M3B, water: -9, spikes: spikesUnder(0, 18, -5), tip: "tip_steel_road" }),
  L("cave", "Cave of Needles", "Пещера игл", { x0: 0, x1: 16, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M3B, water: -8, spikes: spikesUnder(0, 16, -4), tip: "tip_spikes" }),
  L("chain3", "Final Chamber", "Финальная камера", { b1x1: 12, highY: 7, b2x0: 30, b2x1: 40, b1mat: "steel", b2mat: "steel", height: 2, deckMat: "steel_road", materials: M3B, tip: "tip_portal" }),
];

// ----------------------------------------------------------------------------
// Chapter 4: Frozen Mountains (everything incl. bounce)
// ----------------------------------------------------------------------------
const CH4 = [
  // round 1 tail (4-7, 4-8)
  L("jump", "Snow Leap", "Снежный прыжок", { edge: 2, landing: 14, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M4, water: -8, spikes: spikesUnder(7, 14, -4), tip: "tip_boost" }),
  L("susp", "Frozen Wires", "Мёрзлые тросы", { x0: 0, x1: 12, towerY: 7, towerInset: 2, cableMat: "cable", materials: M4, water: -8, tip: "tip_cable" }),
  // round 2 (4-9..4-16)
  L("bounce", "Ice Trampoline", "Ледяной батут", { edge: 4, landing: 18, deckY: 0, landingY: -2, materials: M4, water: -8, tip: "tip_bounce" }),
  L("flat", "Glacier Span", "Ледниковый пролёт", { x0: 0, x1: 10, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, tip: "tip_steel_road" }),
  L("king", "Frozen Crown", "Мёрзлая корона", { x0: 0, x1: 10, rise: 3, stayMat: "cable", materials: M4, water: -8, tip: "tip_cable" }),
  L("launch", "Ice Portal", "Ледяной портал", { x1: 10, height: 2, trussMat: "steel", exitX: 20, exitY: 11, highY: 9, finish: 36, materials: M4, tip: "tip_portal" }),
  L("hump", "Snowdrift Wave", "Сугробная волна", { x0: 0, x1: 11, rise: 1, height: 2, trussMat: "steel", materials: M4, water: -8, tip: "tip_triangles" }),
  L("bounce", "Spike Bounce", "Батут над шипами", { edge: 4, landing: 20, deckY: 0, landingY: -3, materials: M4, water: -9, spikes: spikesUnder(10, 20, -4), tip: "tip_bounce" }),
  L("cave", "Ice Cave", "Ледяная пещера", { x0: 0, x1: 10, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, tip: "tip_supports" }),
  L("vault", "Frozen Gate", "Мёрзлые врата", { x1: 10, y1: 4, height: 2, trussMat: "steel", plateau: 7, exitDX: 14, finishDX: 24, materials: M4, tip: "tip_portal" }),
  // round 3 (4-17..4-24)
  L("islands", "Ice Floes", "Ледяные поля", { gaps: [{ x0: 0, x1: 6 }, { x0: 9, x1: 15 }], mode: "above", height: 2, trussMat: "steel", materials: M4, water: -9, tip: "tip_steel" }),
  L("jump", "Ice Launch", "Ледяной запуск", { edge: 2, landing: 17, deckY: 0, landingY: -3, rampLen: 4, rampRise: 1.3, materials: M4, water: -9, spikes: spikesUnder(9, 17, -4), tip: "tip_boost" }),
  L("susp", "Blizzard Cables", "Тросы метели", { x0: 0, x1: 14, towerY: 7, towerInset: 2, cableMat: "cable", materials: M4, water: -9, spikes: spikesUnder(0, 14, -5), tip: "tip_cable" }),
  L("slope", "Summit Climb", "Подъём на вершину", { x0: 0, x1: 12, y0: 0, y1: 3, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -9, tip: "tip_triangles" }),
  L("bounce", "Avalanche Launch", "Лавинный запуск", { edge: 4, landing: 22, deckY: 0, landingY: -3, materials: M4, water: -9, tip: "tip_mix" }),
  L("pillar", "Frozen Needle", "Ледяная игла", { x0: 0, rightX: 14, mid: 7, height: 2, trussMat: "steel", materials: M4, water: -10, spikes: spikesUnder(0, 14, -5), tip: "tip_steel" }),
  L("chain2", "Avalanche Gate", "Врата лавины", { b1x1: 8, highY: 6, b2x0: 24, b2x1: 32, b1mat: "steel", b2mat: "steel", height: 2, materials: M4, tip: "tip_portal" }),
  L("arch", "Snowbow Arch", "Снежная арка", { x0: 0, x1: 12, rise: 2, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, tip: "tip_triangles" }),
  // round 4 (4-25..4-32)
  L("under", "Under the Ice", "Подо льдом", { x0: 0, x1: 14, height: 2, mode: "below", deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_supports" }),
  L("bounce", "Summit Catapult", "Катапульта вершины", { edge: 4, landing: 28, deckY: 0, landingY: -5, materials: M4, water: -11, spikes: spikesUnder(12, 28, -6), tip: "tip_mix" }),
  L("king", "Crown of Peaks", "Корона вершин", { x0: 0, x1: 15, apexes: 2, rise: 3, stayMat: "cable", deckMat: "steel_road", materials: M4, water: -9, tip: "tip_cable" }),
  L("catch", "Glacier Gate", "Ледниковые врата", { bridgeX0: -10, bridgeX1: 0, startY: 8, height: 2, trussMat: "steel", ledge: 4, portalX: 14, portalY: 1.3, exitX: 28, farX: 24, finish: 38, materials: M4, tip: "tip_portal" }),
  L("flat", "Frozen Highway", "Ледяное шоссе", { x0: 0, x1: 16, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, spikes: spikesUnder(0, 16, -5), tip: "tip_spikes" }),
  L("bounce", "Snow Catapult", "Снежная катапульта", { edge: 4, landing: 26, deckY: 0, landingY: -4, materials: M4, water: -10, tip: "tip_mix" }),
  L("islands", "Frozen Islands", "Мёрзлые острова", { gaps: [{ x0: 0, x1: 7 }, { x0: 10, x1: 17 }, { x0: 20, x1: 27 }], mode: "below", height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, spikes: spikesUnder(0, 27, -6), tip: "tip_steel_road" }),
  L("susp", "Summit Cableway", "Тросовый пик", { x0: 0, x1: 16, towerY: 9, towerInset: 2, cableMat: "cable", materials: M4, water: -9, tip: "tip_cable" }),
  // round 5 (4-33..4-40)
  L("pillar", "Titan Pylon", "Титан-пилон", { x0: 0, rightX: 18, mid: 9, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_steel_road" }),
  L("cave", "Glacier Tunnel", "Ледниковый тоннель", { x0: 0, x1: 16, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -9, spikes: spikesUnder(0, 16, -5), tip: "tip_spikes" }),
  L("chain3", "Polar Crossing", "Полярный переход", { b1x1: 12, highY: 7, b2x0: 30, b2x1: 40, b1mat: "steel", b2mat: "steel", height: 2, deckMat: "steel_road", materials: M4, tip: "tip_portal" }),
  L("islands", "Four Floes", "Четыре льдины", { gaps: [{ x0: 0, x1: 5 }, { x0: 8, x1: 13 }, { x0: 16, x1: 21 }, { x0: 24, x1: 29 }], mode: "above", height: 2, trussMat: "steel", materials: M4, water: -10, tip: "tip_steel" }),
  L("pillar", "Frozen Pylon", "Замёрзший пилон", { x0: 0, rightX: 20, mid: 10, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_steel_road" }),
  L("king", "Colossus Pier", "Опора колосса", { x0: 0, x1: 18, apexes: 2, rise: 3, stayMat: "cable", deckMat: "steel_road", materials: M4, water: -10, tip: "tip_cable" }),
  L("arch", "Aurora Arch", "Арка сияния", { x0: 0, x1: 18, rise: 2, height: 2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -9, tip: "tip_triangles" }),
  L("flat", "Ultimate Summit", "Абсолютная вершина", { x0: 0, x1: 22, height: 2, mode: "both", deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_stars" }),
];

const CHAPTERS = { 1: CH1, 2: CH2, 3: CH3, 4: CH4 };

function signature(lvl) {
  return JSON.stringify({
    g: lvl.ground || [], r: lvl.ramps || [], b: lvl.blocks || [], a: lvl.anchors || [],
    p: lvl.portals || [], s: lvl.spikes || [], st: lvl.start, f: lvl.finish,
  });
}

// Hand-made part of a chapter file as text: everything before the first generated level.
// Budgets in `rebudget` ({ id: budget }) are patched in place.
function handmadeText(chNum, kept, rebudget) {
  const file = path.join(ROOT, `game/levels/chapter${chNum}.lua`);
  const src = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
  const firstGen = src.indexOf(`id = "${chNum}-${kept + 1}"`);
  if (firstGen < 0) throw new Error(`chapter ${chNum}: level ${chNum}-${kept + 1} not found`);
  const cut = src.lastIndexOf("\n\t\t{", firstGen);
  let head = src.slice(0, cut + 1);
  for (const [id, budget] of Object.entries(rebudget)) {
    const at = head.indexOf(`id = "${id}"`);
    const re = /budget = \d+/y;
    const b = head.indexOf("budget = ", at);
    re.lastIndex = b;
    if (at < 0 || b < 0 || !re.test(head)) throw new Error(`budget of ${id} not found`);
    head = head.slice(0, b) + `budget = ${budget}` + head.slice(re.lastIndex);
  }
  return head;
}

function main() {
  const args = process.argv.slice(2);
  const write = args.includes("--write");
  const chapterArg = args.find((a) => a.startsWith("--chapter="));
  const only = chapterArg ? Number(chapterArg.split("=")[1]) : null;
  const loaded = loadAllChapters();
  const preserved = {};
  for (const ch of loaded) preserved[ch.chapterIndex] = ch.levels.slice(0, HANDMADE[ch.chapterIndex]);

  let failed = false;
  const report = {};
  for (const chNum of [1, 2, 3, 4]) {
    if (only && chNum !== only) continue;
    const specs = CHAPTERS[chNum];
    const kept = HANDMADE[chNum];
    if (specs.length !== 40 - kept) throw new Error(`chapter ${chNum} has ${specs.length} specs for ${40 - kept} generated levels`);
    report[chNum] = [];

    // Round 1 hand-made levels outside the FTUE chapter: loosen budgets that are too tight.
    const rebudget = {};
    if (chNum !== 1) {
      for (const lvl of preserved[chNum]) {
        const res = test(lvl);
        if (!res.ok) {
          failed = true;
          console.log(`FAIL ${lvl.id} (hand-made): ${res.msg || res.err}`);
          continue;
        }
        if (res.cost / lvl.budget > ROUND1_MAX_RATIO) {
          rebudget[lvl.id] = Math.ceil((res.cost * ROUND_MULT[0]) / 50) * 50;
          console.log(`fix  ${lvl.id} (hand-made): budget ${lvl.budget} -> ${rebudget[lvl.id]} (cost ${res.cost})`);
        }
      }
    }

    const sigs = new Set(preserved[chNum].map(signature));
    const generated = [];
    for (let i = 0; i < specs.length; i++) {
      const num = i + kept + 1;
      const id = `${chNum}-${num}`;
      let lvl;
      try {
        lvl = buildSpec(specs[i], id);
      } catch (e) {
        failed = true;
        console.log(`FAIL ${id} ${specs[i].en}: ${e.message}`);
        continue;
      }
      lvl.tip = specs[i].opts.tip;
      if (sigs.has(signature(lvl))) console.log(`WARN ${id}: duplicate geometry`);
      sigs.add(signature(lvl));
      const mult = specs[i].opts.mult || multFor(num);
      const { res } = fitBudget(lvl, mult);
      if (!res.ok) {
        failed = true;
        console.log(`FAIL ${id} ${specs[i].en}: ${res.msg || res.err} (truck ${res.truckRes}, empty ${res.emptyRes}, reason ${res.reason}, cost ${res.cost})`);
        generated.push(lvl);
        continue;
      }
      console.log(`ok   ${id} ${specs[i].type.padEnd(7)} ${specs[i].en}: beams ${lvl.solution.length} cost ${res.cost} budget ${lvl.budget} (x${mult}) t=${res.time.toFixed(1)} stress=${(res.stress || 0).toFixed(2)}`);
      generated.push(lvl);
      report[chNum].push({ id, type: specs[i].type, beams: lvl.solution.length, cost: res.cost, budget: lvl.budget, time: res.time, stress: res.stress });
    }
    if (write) {
      if (generated.length !== specs.length) {
        console.log(`skip writing chapter ${chNum}: not every level was built`);
        continue;
      }
      const out = handmadeText(chNum, kept, rebudget)
        + generated.map((lvl) => levelToLua(lvl) + ",").join("\n") + "\n\t},\n}\n";
      fs.writeFileSync(path.join(ROOT, `game/levels/chapter${chNum}.lua`), out, "utf8");
      console.log(`saved game/levels/chapter${chNum}.lua (${kept} hand-made + ${generated.length} generated)`);
    }
  }
  if (!write) console.log("dry run: pass --write to update chapter files");
  fs.writeFileSync(path.join(ROOT, only ? `tools/gen/campaign_report_ch${only}.json` : "tools/gen/campaign_report.json"), JSON.stringify(report, null, 2), "utf8");
  if (failed) process.exitCode = 1;
}

main();
