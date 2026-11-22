// Campaign v2: hand-flavoured levels for all four chapters.
// Keeps the six showcase levels of every chapter and replaces 7..40 with varied
// hand-designed archetypes. Every level is validated with the headless XPBD sim.
//
//   node tools/gen/build_campaign.js            (validate only)
//   node tools/gen/build_campaign.js --write    (write chapter files)
//   node tools/gen/build_campaign.js --chapter=2 --write (one chapter)
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

const M1 = ["road", "wood"];
const M1R = ["road", "wood", "rope"];
const M1S = ["road", "wood", "steel"];
const M1SR = ["road", "wood", "steel", "steel_road"];
const M2 = ["road", "wood", "steel", "cable", "steel_road"];
const M3 = ["road", "wood", "steel", "cable", "steel_road", "boost"];
const M3B = ["road", "wood", "steel", "cable", "steel_road", "boost", "bounce"];
const M4 = ["road", "wood", "steel", "cable", "steel_road", "boost", "bounce"];

function L(type, en, ru, opts) {
  return { type, en, ru, opts };
}

function buildSpec(spec, id) {
  const o = spec.opts;
  let lvl;
  switch (spec.type) {
    case "flat":
    case "slope":
    case "under":
      lvl = spanLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "arch":
      lvl = archLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "hump":
      lvl = humpLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "cave":
      lvl = caveLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "king":
      lvl = kingpostLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "susp":
      lvl = suspensionLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "islands":
      lvl = islandsLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "pillar":
      lvl = pillarLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "jump":
      lvl = jumpLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "bounce":
      lvl = bounceLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "portal":
      lvl = portalHighLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "vault":
      lvl = portalVaultLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "launch":
      lvl = portalLaunchLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "catch":
      lvl = portalCatchLevel({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "chain2":
      lvl = portalChain2Level({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "chain3":
      lvl = portalChain3Level({ ...o, id, name: { en: spec.en, ru: spec.ru } });
      break;
    case "pier":
      lvl = buildPierBridge({ ...o, id, name: { en: spec.en, ru: spec.ru }, budget: 99999 });
      break;
    default:
      throw new Error("unknown level type " + spec.type);
  }
  return lvl;
}

// ----------------------------------------------------------------------------
// Chapter 1: Green Valley (road, wood; steel later)
// ----------------------------------------------------------------------------
const CH1 = [
  L("flat", "Valley Span", "Пролёт долины", { x0: 0, x1: 9, height: 2.4, materials: M1, water: -4, tip: "tip_triangles", mult: 1.3 }),
  L("islands", "Island Hop", "По островкам", { gaps: [{ x0: 0, x1: 6 }, { x0: 10, x1: 16 }], mode: "above", height: 2.2, materials: M1, water: -4, tip: "tip_triangles", mult: 1.28 }),
  L("arch", "Rainbow Arch", "Радужная арка", { x0: 0, x1: 11, rise: 1.5, materials: M1, water: -4, tip: "tip_triangles", mult: 1.28 }),
  L("cave", "Fox Hole", "Лисья нора", { x0: 0, x1: 9, height: 2.2, materials: M1, water: -4, tip: "tip_supports", mult: 1.3 }),
  L("slope", "Ridge Road", "Дорога на гребень", { x0: 0, x1: 10, y0: 0, y1: 3, height: 2.4, materials: M1, water: -5, tip: "tip_triangles", mult: 1.28 }),
  L("king", "King's Post", "Королевский столб", { x0: 0, x1: 7, rise: 2.0, stayMat: "wood", materials: M1R, water: -4, tip: "tip_rope", mult: 1.3 }),
  L("under", "Under-Slung", "Подвесной настил", { x0: 0, x1: 10, height: 2.2, mode: "below", materials: M1, water: -6, tip: "tip_supports", mult: 1.28 }),
  L("hump", "Camel Back", "Верблюжий горб", { x0: 0, x1: 10, rise: 1.3, materials: M1, water: -4, tip: "tip_triangles", mult: 1.25 }),
  L("islands", "River Bend", "Излучина реки", { gaps: [{ x0: 0, x1: 7 }, { x0: 11, x1: 18 }], mode: "above", height: 2.3, materials: M1, water: -4, tip: "tip_triangles", mult: 1.25 }),
  L("flat", "Iron Valley", "Железная долина", { x0: 0, x1: 13, height: 2.6, trussMat: "steel", materials: M1S, water: -5, tip: "tip_steel", mult: 1.25 }),
  L("susp", "Rope Cradle", "Верёвочная люлька", { x0: 0, x1: 12, segments: 4, towerY: 6, towerInset: 2, cableMat: "rope", materials: M1R, water: -5, tip: "tip_rope", mult: 1.26 }),
  L("cave", "Echo Cave", "Пещера эха", { x0: 0, x1: 12, height: 2.3, trussMat: "steel", materials: M1S, water: -5, tip: "tip_supports", mult: 1.24 }),
  L("king", "Steel Crown", "Стальная корона", { x0: 0, x1: 10, rise: 2.4, stayMat: "steel", materials: M1S, water: -5, tip: "tip_steel", mult: 1.24 }),
  L("arch", "Sunrise Arch", "Арка рассвета", { x0: 0, x1: 14, rise: 2.0, trussMat: "steel", materials: M1S, water: -5, tip: "tip_triangles", mult: 1.22 }),
  L("islands", "Three Brooks", "Три ручья", { gaps: [{ x0: 0, x1: 7 }, { x0: 10, x1: 17 }, { x0: 20, x1: 27 }], mode: "below", height: 2.4, trussMat: "steel", materials: M1S, water: -6, tip: "tip_supports", mult: 1.22 }),
  L("slope", "Highland Rise", "Подъём на плато", { x0: 0, x1: 14, y0: 0, y1: 4, height: 2.5, trussMat: "steel", materials: M1S, water: -6, tip: "tip_triangles", mult: 1.22 }),
  L("hump", "Rolling Hills", "Волнистые холмы", { x0: 0, x1: 12, rise: 1.8, trussMat: "steel", materials: M1S, water: -5, tip: "tip_triangles", mult: 1.22 }),
  L("flat", "Green Viaduct", "Зелёный виадук", { x0: 0, x1: 16, height: 2.8, trussMat: "steel", materials: M1S, water: -6, tip: "tip_steel", mult: 1.2 }),
  L("pillar", "Rock Pillar", "Каменный столп", { x0: 0, rightX: 16, mid: 8, height: 2.4, trussMat: "steel", materials: M1S, water: -7, tip: "tip_supports", mult: 1.2 }),
  L("king", "Twin Crowns", "Двойная корона", { x0: 0, x1: 14, apexes: 2, rise: 2.6, stayMat: "steel", materials: M1S, water: -5, tip: "tip_steel", mult: 1.22 }),
  L("cave", "Deep Grotto", "Глубокий грот", { x0: 0, x1: 14, height: 2.4, trussMat: "steel", materials: M1S, water: -6, tip: "tip_supports", mult: 1.2 }),
  L("under", "Hanging Valley", "Висячая долина", { x0: 0, x1: 14, height: 2.4, mode: "below", trussMat: "steel", materials: M1S, water: -8, tip: "tip_supports", mult: 1.2 }),
  L("islands", "Twin Gorge", "Двойное ущелье", { gaps: [{ x0: 0, x1: 9 }, { x0: 12, x1: 21 }], mode: "above", height: 2.6, trussMat: "steel", materials: M1S, water: -6, tip: "tip_steel", mult: 1.2 }),
  L("arch", "Grand Arch", "Большая арка", { x0: 0, x1: 16, rise: 2.2, trussMat: "steel", materials: M1S, water: -6, tip: "tip_triangles", mult: 1.2 }),
  L("pier", "River Pier", "Речная опора", { x0: 0, x1: 18, pierX: 8, pierW: 2.4, pierY: -3, materials: M1S, matRoad: "road", matTruss: "steel", water: -6, tip: "tip_steel", mult: 1.2 }),
  L("flat", "Far Reach", "Дальний пролёт", { x0: 0, x1: 18, height: 3.0, trussMat: "steel", materials: M1S, water: -6, tip: "tip_steel", mult: 1.18 }),
  L("pillar", "Needle Pass", "Игольный перевал", { x0: 0, rightX: 20, mid: 11, height: 2.5, trussMat: "steel", materials: M1S, water: -8, tip: "tip_steel", mult: 1.18 }),
  L("flat", "Valley Masterpiece", "Шедевр долины", { x0: 0, x1: 22, height: 3.0, mode: "both", trussMat: "steel", materials: M1S, water: -7, tip: "tip_stars", mult: 1.18 }),
  L("islands", "Cascade Crossing", "Каскадная переправа", { gaps: [{ x0: 0, x1: 8 }, { x0: 11, x1: 19 }, { x0: 22, x1: 30 }], mode: "above", height: 2.6, trussMat: "steel", materials: M1S, water: -7, tip: "tip_steel", mult: 1.18 }),
  L("king", "Giant's Steps", "Шаги великана", { x0: 0, x1: 16, apexes: 2, rise: 2.8, stayMat: "steel", materials: M1S, water: -6, tip: "tip_stars", mult: 1.18 }),
  L("cave", "Bedrock Tunnel", "Тоннель в скале", { x0: 0, x1: 16, height: 2.6, trussMat: "steel", materials: M1S, water: -6, tip: "tip_supports", mult: 1.18 }),
  L("arch", "Flying Arch", "Летящая арка", { x0: 0, x1: 18, rise: 2.4, trussMat: "steel", materials: M1S, water: -7, tip: "tip_triangles", mult: 1.18 }),
  L("pier", "Great Pier", "Великая опора", { x0: 0, x1: 22, pierX: 10, pierW: 2.4, pierY: -3.5, materials: M1S, matRoad: "road", matTruss: "steel", water: -8, tip: "tip_steel", mult: 1.16 }),
  L("flat", "Valley Colossus", "Колосс долины", { x0: 0, x1: 24, height: 3.2, deckMat: "steel_road", trussMat: "steel", materials: M1SR, water: -8, tip: "tip_stars", mult: 1.16 }),
];

// ----------------------------------------------------------------------------
// Chapter 2: Red Canyon (steel, cable, steel road)
// ----------------------------------------------------------------------------
const CH2 = [
  L("flat", "Canyon Spine", "Хребет каньона", { x0: 0, x1: 16, height: 2.6, trussMat: "steel", materials: M2, water: -6, tip: "tip_steel", mult: 1.22 }),
  L("pier", "Red Pier", "Красная опора", { x0: 0, x1: 20, pierX: 9, pierW: 2.4, pierY: -3, materials: M2, matRoad: "road", matTruss: "steel", water: -7, tip: "tip_steel", mult: 1.2 }),
  L("slope", "Mesa Climb", "Подъём на месу", { x0: 0, x1: 14, y0: 0, y1: 4, height: 2.6, trussMat: "steel", materials: M2, water: -7, tip: "tip_triangles", mult: 1.2 }),
  L("under", "Red Underpass", "Красный подлаз", { x0: 0, x1: 16, height: 2.7, mode: "below", trussMat: "steel", materials: M2, water: -9, tip: "tip_supports", mult: 1.2 }),
  L("susp", "Cable Cradle", "Тросовая люлька", { x0: 0, x1: 18, segments: 6, towerY: 7, towerInset: 2, cableMat: "cable", materials: M2, water: -6, tip: "tip_cable", mult: 1.22 }),
  L("cave", "Sand Grotto", "Песчаный грот", { x0: 0, x1: 14, height: 2.6, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -7, tip: "tip_supports", mult: 1.2 }),
  L("islands", "Spire Islands", "Острова шпилей", { gaps: [{ x0: 0, x1: 8 }, { x0: 11, x1: 20 }, { x0: 23, x1: 31 }], mode: "above", height: 2.5, trussMat: "steel", materials: M2, water: -8, tip: "tip_steel", mult: 1.2 }),
  L("king", "Twin Canyons", "Два каньона", { x0: 0, x1: 18, apexes: 2, rise: 3.0, stayMat: "cable", deckMat: "steel_road", materials: M2, water: -7, tip: "tip_cable", mult: 1.2 }),
  L("hump", "Dune Wave", "Дюнная волна", { x0: 0, x1: 14, rise: 2.0, trussMat: "steel", materials: M2, water: -6, tip: "tip_triangles", mult: 1.2 }),
  L("under", "Under the Rim", "Под обрывом", { x0: 0, x1: 18, height: 2.6, mode: "below", trussMat: "steel", materials: M2, water: -9, tip: "tip_supports", mult: 1.2 }),
  L("arch", "Red Arch", "Красная арка", { x0: 0, x1: 16, rise: 2.4, trussMat: "steel", materials: M2, water: -7, tip: "tip_triangles", mult: 1.2 }),
  L("pillar", "Needle Pillar", "Игла", { x0: 0, rightX: 20, mid: 10, height: 2.8, trussMat: "steel", materials: M2, water: -9, tip: "tip_steel", mult: 1.2 }),
  L("flat", "Iron Road", "Железная дорога", { x0: 0, x1: 20, height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -7, tip: "tip_steel_road", mult: 1.18 }),
  L("susp", "Grand Cable", "Большой трос", { x0: 0, x1: 22, segments: 7, towerY: 8, towerInset: 2, cableMat: "cable", materials: M2, water: -8, tip: "tip_cable", mult: 1.18 }),
  L("islands", "Three Spires", "Три шпиля", { gaps: [{ x0: 0, x1: 9 }, { x0: 12, x1: 21 }, { x0: 24, x1: 33 }], mode: "above", height: 2.6, trussMat: "steel", materials: M2, water: -8, tip: "tip_steel", mult: 1.18 }),
  L("cave", "Cave of Echoes", "Пещера отзвуков", { x0: 0, x1: 18, height: 2.7, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -7, tip: "tip_supports", mult: 1.18 }),
  L("arch", "Sunset Arch", "Арка заката", { x0: 0, x1: 20, rise: 2.6, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -8, tip: "tip_triangles", mult: 1.18 }),
  L("pier", "Canyon Pier", "Опора каньона", { x0: 0, x1: 24, pierX: 11, pierW: 2.6, pierY: -4, materials: M2, matRoad: "steel_road", matTruss: "steel", water: -8, tip: "tip_steel_road", mult: 1.18 }),
  L("flat", "Steel Highway", "Стальное шоссе", { x0: 0, x1: 24, height: 3.0, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -8, tip: "tip_steel_road", mult: 1.16 }),
  L("king", "Twin Buttes", "Два холма", { x0: 0, x1: 20, apexes: 2, rise: 3.2, stayMat: "cable", deckMat: "steel_road", materials: M2, water: -8, tip: "tip_cable", mult: 1.16 }),
  L("susp", "Wire Crossing", "Переправа на тросах", { x0: 0, x1: 22, segments: 7, towerY: 7, towerInset: 2, cableMat: "cable", materials: M2, water: -9, tip: "tip_cable", mult: 1.16 }),
  L("islands", "Broken Mesa", "Расколотая меса", { gaps: [{ x0: 0, x1: 10 }, { x0: 13, x1: 23 }, { x0: 26, x1: 36 }], mode: "below", height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -10, tip: "tip_steel_road", mult: 1.16 }),
  L("hump", "Red Wave", "Красная волна", { x0: 0, x1: 18, rise: 2.4, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -8, tip: "tip_triangles", mult: 1.16 }),
  L("cave", "Deep Cave", "Глубокая пещера", { x0: 0, x1: 20, height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -8, tip: "tip_supports", mult: 1.16 }),
  L("pillar", "Stone Needle", "Каменная игла", { x0: 0, rightX: 24, mid: 12, height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -10, tip: "tip_steel_road", mult: 1.16 }),
  L("arch", "Mesa Arch", "Арка месы", { x0: 0, x1: 24, rise: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -9, tip: "tip_triangles", mult: 1.15 }),
  L("pier", "Canyon Viaduct", "Виадук каньона", { x0: 0, x1: 26, pierX: 12, pierW: 2.6, pierY: -4.5, materials: M2, matRoad: "steel_road", matTruss: "steel", water: -9, tip: "tip_steel_road", mult: 1.15 }),
  L("islands", "Four Mesas", "Четыре месы", { gaps: [{ x0: 0, x1: 9 }, { x0: 12, x1: 21 }, { x0: 24, x1: 33 }, { x0: 36, x1: 45 }], mode: "above", height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -9, tip: "tip_steel_road", mult: 1.15 }),
  L("susp", "Sky Cable", "Небесный трос", { x0: 0, x1: 22, segments: 7, towerY: 8, towerInset: 3, cableMat: "cable", materials: M2, water: -9, tip: "tip_cable", mult: 1.15 }),
  L("flat", "Steel Colossus", "Стальной колосс", { x0: 0, x1: 28, height: 3.2, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -10, tip: "tip_steel_road", mult: 1.14 }),
  L("king", "Crown of Spires", "Корона шпилей", { x0: 0, x1: 24, apexes: 2, rise: 3.4, stayMat: "cable", deckMat: "steel_road", materials: M2, water: -9, tip: "tip_cable", mult: 1.14 }),
  L("cave", "Canyon Tunnel", "Тоннель каньона", { x0: 0, x1: 24, height: 3.0, deckMat: "steel_road", trussMat: "steel", materials: M2, water: -9, tip: "tip_supports", mult: 1.14 }),
  L("pier", "Titan Pier", "Титан-опора", { x0: 0, x1: 30, pierX: 14, pierW: 2.8, pierY: -4, materials: M2, matRoad: "steel_road", matTruss: "steel", water: -11, tip: "tip_steel_road", mult: 1.14 }),
  L("flat", "Red Canyon Master", "Мастер каньона", { x0: 0, x1: 32, height: 3.4, mode: "both", deckMat: "steel_road", trussMat: "steel", materials: M2, water: -11, tip: "tip_stars", mult: 1.13 }),
];

// ----------------------------------------------------------------------------
// Chapter 3: Quantum Lab (portals, spikes, boost)
// ----------------------------------------------------------------------------
function spikesUnder(x0, x1, top) {
  return [[x0, top - 0.8, x1, top]];
}

const CH3 = [
  L("vault", "Warp Gate", "Врата варпа", { x1: 8, y1: 3, plateau: 6, exitDX: 12, finishDX: 22, materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("flat", "Spike Run", "Шипованный пролёт", { x0: 0, x1: 10, height: 2.4, materials: ["road", "wood", "rope", "steel"], water: -6, spikes: spikesUnder(0, 10, -3), tip: "tip_spikes", mult: 1.25 }),
  L("jump", "Boost Leap", "Прыжок на ускорителе", { edge: 2, landing: 16, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M3, water: -8, tip: "tip_boost", mult: 1.25 }),
  L("cave", "Cave of Needles", "Пещера игл", { x0: 0, x1: 12, height: 2.3, materials: M1S, water: -6, spikes: spikesUnder(0, 12, -3), tip: "tip_spikes", mult: 1.24 }),
  L("launch", "Portal Vault", "Портальное хранилище", { x1: 12, exitX: 22, exitY: 11, highY: 9, finish: 38, materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("king", "Rope Gauntlet", "Верёвочная тропа", { x0: 0, x1: 8, rise: 2.0, stayMat: "wood", materials: M1R, water: -5, spikes: spikesUnder(0, 8, -3), tip: "tip_rope", mult: 1.24 }),
  L("jump", "Momentum Gate", "Врата импульса", { edge: 2, landing: 14, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M3, water: -8, tip: "tip_boost", mult: 1.24 }),
  L("susp", "Spike Suspension", "Подвесной над шипами", { x0: 0, x1: 12, segments: 4, towerY: 6, towerInset: 2, cableMat: "rope", materials: M1R, water: -6, spikes: spikesUnder(0, 12, -3.2), tip: "tip_rope", mult: 1.24 }),
  L("vault", "High Portal", "Высокий портал", { x1: 12, y1: 5, plateau: 7, exitDX: 14, finishDX: 24, materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("arch", "Neon Arch", "Неоновый мост", { x0: 0, x1: 14, rise: 2.2, trussMat: "steel", materials: M1S, water: -6, tip: "tip_triangles", mult: 1.22 }),
  L("islands", "Island Lab", "Лаборатория островов", { gaps: [{ x0: 0, x1: 8 }, { x0: 11, x1: 19 }, { x0: 22, x1: 30 }], mode: "above", height: 2.6, trussMat: "steel", materials: M3, water: -7, spikes: spikesUnder(0, 30, -4), tip: "tip_steel", mult: 1.22 }),
  L("chain2", "Portal Pillar", "Портальная игла", { b1x1: 8, highY: 5, b2x0: 24, b2x1: 32, b1mat: "wood", b2mat: "wood", materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("bounce", "Quantum Bounce", "Квантовый батут", { edge: 4, landing: 16, deckY: 0, landingY: -2, materials: M3B, water: -8, tip: "tip_bounce", mult: 1.22 }),
  L("cave", "Test Chamber", "Тестовая камера", { x0: 0, x1: 14, height: 2.5, trussMat: "steel", materials: M3, water: -6, tip: "tip_supports", mult: 1.22 }),
  L("jump", "Boost Chasm", "Ускорительная пропасть", { edge: 2, landing: 16, deckY: 0, landingY: -3, rampLen: 4, rampRise: 1.3, materials: M3, water: -9, spikes: spikesUnder(8, 16, -4), tip: "tip_boost", mult: 1.2 }),
  L("flat", "Spike Bridge", "Мост над шипами", { x0: 0, x1: 14, height: 2.6, trussMat: "steel", materials: M3, water: -6, spikes: spikesUnder(0, 14, -3.2), tip: "tip_spikes", mult: 1.2 }),
  L("flat", "Flux Highway", "Шоссе потока", { x0: 0, x1: 16, height: 2.6, deckMat: "boost", trussMat: "steel", materials: M3, water: -7, tip: "tip_boost", mult: 1.2 }),
  L("catch", "Falling Gate", "Падающие врата", { bridgeX0: -16, bridgeX1: 0, startY: 10, ledge: 4, portalX: 14, portalY: 1.3, exitX: 28, farX: 24, finish: 38, materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("pillar", "Crystal Pillar", "Кристальный столп", { x0: 0, rightX: 16, mid: 8, height: 2.5, trussMat: "steel", materials: M3, water: -8, spikes: spikesUnder(0, 16, -4), tip: "tip_steel", mult: 1.2 }),
  L("bounce", "Lab Trampoline", "Лабораторный батут", { edge: 4, landing: 20, deckY: 0, landingY: -3, materials: M3B, water: -9, tip: "tip_bounce", mult: 1.2 }),
  L("cave", "Needle Cave", "Пещера шипов", { x0: 0, x1: 16, height: 2.6, deckMat: "steel_road", trussMat: "steel", materials: M3, water: -7, spikes: spikesUnder(0, 16, -3.4), tip: "tip_spikes", mult: 1.2 }),
  L("chain2", "Portal Loop", "Петля портала", { b1x1: 6, highY: 6, b2x0: 22, b2x1: 30, b1mat: "wood", b2mat: "steel", materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("susp", "Hanging Wires", "Висячие тросы", { x0: 0, x1: 18, segments: 6, towerY: 8, towerInset: 2, cableMat: "cable", materials: M3, water: -8, spikes: spikesUnder(0, 18, -4), tip: "tip_cable", mult: 1.18 }),
  L("jump", "Rocket Rail", "Ракетные рельсы", { edge: 2, landing: 13, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M3, water: -9, tip: "tip_boost", mult: 1.18 }),
  L("chain3", "Quantum Leap", "Квантовый скачок", { b1x1: 8, highY: 6, b2x0: 24, b2x1: 32, b1mat: "wood", b2mat: "steel", materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("king", "Spike Crown", "Корона шипов", { x0: 0, x1: 10, rise: 2.4, stayMat: "steel", materials: M3, water: -7, spikes: spikesUnder(0, 10, -3.2), tip: "tip_spikes", mult: 1.18 }),
  L("islands", "Reactors", "Реакторы", { gaps: [{ x0: 0, x1: 9 }, { x0: 12, x1: 21 }, { x0: 24, x1: 33 }], mode: "below", height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M3, water: -9, spikes: spikesUnder(0, 33, -5), tip: "tip_steel_road", mult: 1.18 }),
  L("chain2", "Twin Gates", "Двойные врата", { b1x1: 10, highY: 7, b2x0: 28, b2x1: 36, b1mat: "wood", b2mat: "steel", materials: M3, tip: "tip_portal", mult: 1.2 }),
  L("bounce", "Bounce Reactor", "Батут-реактор", { edge: 4, landing: 24, deckY: 0, landingY: -4, materials: M3B, water: -10, spikes: spikesUnder(12, 24, -5), tip: "tip_mix", mult: 1.16 }),
  L("arch", "Singularity Arch", "Арка сингулярности", { x0: 0, x1: 18, rise: 2.6, deckMat: "steel_road", trussMat: "steel", materials: M3, water: -8, spikes: spikesUnder(0, 18, -4), tip: "tip_triangles", mult: 1.16 }),
  L("vault", "Aperture Overpass", "Эстакада Апертуры", { x1: 14, y1: 6, plateau: 7, exitDX: 16, finishDX: 26, materials: M3, spikes: spikesUnder(0, 14, -0.4), tip: "tip_portal", mult: 1.2 }),
  L("pillar", "Graviton Needle", "Гравитонная игла", { x0: 0, rightX: 20, mid: 10, height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M3, water: -9, spikes: spikesUnder(0, 20, -5), tip: "tip_steel_road", mult: 1.16 }),
  L("cave", "Final Chamber", "Финальная камера", { x0: 0, x1: 20, height: 2.9, deckMat: "steel_road", trussMat: "steel", materials: M3, water: -8, spikes: spikesUnder(0, 20, -4), tip: "tip_spikes", mult: 1.15 }),
  L("chain3", "GLaDOS Gate", "Врата ГЛэДОС", { b1x1: 12, highY: 7, b2x0: 30, b2x1: 40, b1mat: "steel", b2mat: "steel", deckMat: "steel_road", materials: M3, tip: "tip_portal", mult: 1.2 }),
];

// ----------------------------------------------------------------------------
// Chapter 4: Frozen Mountains (everything incl. bounce)
// ----------------------------------------------------------------------------
const CH4 = [
  L("bounce", "Ice Trampoline", "Ледяной батут", { edge: 4, landing: 18, deckY: 0, landingY: -2, materials: M4, water: -8, tip: "tip_bounce", mult: 1.24 }),
  L("jump", "Snow Leap", "Снежный прыжок", { edge: 2, landing: 14, deckY: 0, landingY: -2, rampLen: 4, rampRise: 1.3, materials: M4, water: -8, spikes: spikesUnder(7, 14, -4), tip: "tip_boost", mult: 1.24 }),
  L("bounce", "Avalanche Launch", "Лавинный запуск", { edge: 4, landing: 22, deckY: 0, landingY: -3, materials: M4, water: -9, tip: "tip_mix", mult: 1.22 }),
  L("flat", "Glacier Span", "Ледниковый пролёт", { x0: 0, x1: 22, height: 3.0, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, tip: "tip_steel_road", mult: 1.2 }),
  L("susp", "Frozen Wires", "Мёрзлые тросы", { x0: 0, x1: 20, segments: 7, towerY: 8, towerInset: 2, cableMat: "cable", materials: M4, water: -9, tip: "tip_cable", mult: 1.2 }),
  L("slope", "Summit Climb", "Подъём на вершину", { x0: 0, x1: 18, y0: 0, y1: 5, height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -9, tip: "tip_triangles", mult: 1.2 }),
  L("cave", "Ice Cave", "Ледяная пещера", { x0: 0, x1: 18, height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, tip: "tip_supports", mult: 1.2 }),
  L("arch", "Snowbow Arch", "Снежная арка", { x0: 0, x1: 20, rise: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, tip: "tip_triangles", mult: 1.2 }),
  L("islands", "Ice Floes", "Ледяные поля", { gaps: [{ x0: 0, x1: 10 }, { x0: 13, x1: 23 }, { x0: 26, x1: 36 }], mode: "above", height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_steel_road", mult: 1.2 }),
  L("king", "Frozen Crown", "Мёрзлая корона", { x0: 0, x1: 20, apexes: 2, rise: 3.0, stayMat: "cable", deckMat: "steel_road", materials: M4, water: -8, tip: "tip_cable", mult: 1.18 }),
  L("pier", "Frozen Pylon", "Замёрзший пилон", { x0: 0, x1: 26, pierX: 11, pierW: 2.4, pierY: -4, materials: M4, matRoad: "steel_road", matTruss: "steel", water: -9, tip: "tip_steel_road", mult: 1.18 }),
  L("bounce", "Spike Bounce", "Батут над шипами", { edge: 4, landing: 20, deckY: 0, landingY: -3, materials: M4, water: -9, spikes: spikesUnder(10, 20, -4), tip: "tip_bounce", mult: 1.18 }),
  L("jump", "Ice Launch", "Ледяной запуск", { edge: 2, landing: 17, deckY: 0, landingY: -3, rampLen: 4, rampRise: 1.3, materials: M4, water: -9, spikes: spikesUnder(9, 17, -4), tip: "tip_boost", mult: 1.18 }),
  L("susp", "Blizzard Cables", "Тросы метели", { x0: 0, x1: 22, segments: 7, towerY: 7, towerInset: 2, cableMat: "cable", materials: M4, water: -9, spikes: spikesUnder(0, 22, -5), tip: "tip_cable", mult: 1.18 }),
  L("hump", "Snowdrift Wave", "Сугробная волна", { x0: 0, x1: 18, rise: 2.6, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, tip: "tip_triangles", mult: 1.18 }),
  L("under", "Under the Ice", "Подо льдом", { x0: 0, x1: 18, height: 2.8, mode: "below", deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_supports", mult: 1.18 }),
  L("flat", "Frozen Highway", "Ледяное шоссе", { x0: 0, x1: 20, height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -8, spikes: spikesUnder(0, 20, -5), tip: "tip_spikes", mult: 1.18 }),
  L("vault", "Frozen Gate", "Мёрзлые врата", { x1: 12, y1: 5, plateau: 7, exitDX: 14, finishDX: 24, deckMat: "steel_road", trussMat: "steel", materials: M4, tip: "tip_portal", mult: 1.2 }),
  L("bounce", "Snow Catapult", "Снежная катапульта", { edge: 4, landing: 26, deckY: 0, landingY: -4, materials: M4, water: -10, tip: "tip_mix", mult: 1.16 }),
  L("launch", "Ice Portal", "Ледяной портал", { x1: 12, exitX: 22, exitY: 11, highY: 9, finish: 38, deckMat: "steel_road", trussMat: "steel", materials: M4, tip: "tip_portal", mult: 1.2 }),
  L("susp", "Summit Cableway", "Тросовый пик", { x0: 0, x1: 18, segments: 6, towerY: 9, towerInset: 2, cableMat: "cable", materials: M4, water: -9, tip: "tip_cable", mult: 1.16 }),
  L("pier", "Titan Pylon", "Титан-пилон", { x0: 0, x1: 28, pierX: 13, pierW: 2.8, pierY: -4, materials: M4, matRoad: "steel_road", matTruss: "steel", water: -10, tip: "tip_steel_road", mult: 1.16 }),
  L("islands", "Four Floes", "Четыре льдины", { gaps: [{ x0: 0, x1: 9 }, { x0: 12, x1: 21 }, { x0: 24, x1: 33 }, { x0: 36, x1: 45 }], mode: "below", height: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_steel_road", mult: 1.16 }),
  L("arch", "Aurora Arch", "Арка сияния", { x0: 0, x1: 22, rise: 2.8, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -9, tip: "tip_triangles", mult: 1.16 }),
  L("cave", "Glacier Tunnel", "Ледниковый тоннель", { x0: 0, x1: 22, height: 3.0, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -9, spikes: spikesUnder(0, 22, -5), tip: "tip_spikes", mult: 1.16 }),
  L("pillar", "Frozen Needle", "Ледяная игла", { x0: 0, rightX: 24, mid: 12, height: 2.9, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, spikes: spikesUnder(0, 24, -5), tip: "tip_steel_road", mult: 1.16 }),
  L("bounce", "Summit Catapult", "Катапульта вершины", { edge: 4, landing: 28, deckY: 0, landingY: -5, materials: M4, water: -11, spikes: spikesUnder(12, 28, -6), tip: "tip_mix", mult: 1.15 }),
  L("flat", "Polar Crossing", "Полярный переход", { x0: 0, x1: 26, height: 3.2, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, spikes: spikesUnder(0, 26, -5), tip: "tip_stars", mult: 1.15 }),
  L("chain2", "Avalanche Gate", "Врата лавины", { b1x1: 10, highY: 7, b2x0: 28, b2x1: 36, b1mat: "steel", b2mat: "steel", deckMat: "steel_road", materials: M4, tip: "tip_portal", mult: 1.2 }),
  L("king", "Crown of Peaks", "Корона вершин", { x0: 0, x1: 24, apexes: 2, rise: 3.4, stayMat: "cable", deckMat: "steel_road", materials: M4, water: -9, spikes: spikesUnder(0, 24, -5), tip: "tip_cable", mult: 1.15 }),
  L("pier", "Colossus Pier", "Опора колосса", { x0: 0, x1: 28, pierX: 13, pierW: 2.4, pierY: -4, materials: M4, matRoad: "steel_road", matTruss: "steel", water: -11, spikes: spikesUnder(0, 28, -6), tip: "tip_steel_road", mult: 1.14 }),
  L("islands", "Frozen Islands", "Мёрзлые острова", { gaps: [{ x0: 0, x1: 9 }, { x0: 12, x1: 21 }, { x0: 24, x1: 33 }], mode: "below", height: 2.9, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, spikes: spikesUnder(0, 33, -6), tip: "tip_steel_road", mult: 1.14 }),
  L("chain3", "Glacier Gate", "Ледниковые врата", { b1x1: 12, highY: 7, b2x0: 30, b2x1: 40, b1mat: "steel", b2mat: "steel", deckMat: "steel_road", materials: M4, tip: "tip_portal", mult: 1.2 }),
  L("arch", "Ultimate Summit", "Абсолютная вершина", { x0: 0, x1: 26, rise: 3.0, deckMat: "steel_road", trussMat: "steel", materials: M4, water: -10, tip: "tip_stars", mult: 1.14 }),
];

const CHAPTERS = { 1: CH1, 2: CH2, 3: CH3, 4: CH4 };
const META = {
  1: { id: "valley", theme: "valley", name: { en: "Green Valley", ru: "Зелёная долина" }, stars_required: 0 },
  2: { id: "canyon", theme: "canyon", name: { en: "Red Canyon", ru: "Красный каньон" }, stars_required: 10 },
  3: { id: "lab", theme: "lab", name: { en: "Quantum Lab", ru: "Квантовая лаборатория" }, stars_required: 24 },
  4: { id: "mountains", theme: "mountains", name: { en: "Frozen Mountains", ru: "Ледяные горы" }, stars_required: 45 },
};

function chapterFile(chNum, levels) {
  const meta = META[chNum];
  const lines = [];
  lines.push(`-- Chapter ${chNum}: ${meta.name.en}. 40 levels.`);
  lines.push(`return {`);
  lines.push(`\tid = "${meta.id}",`);
  lines.push(`\ttheme = "${meta.theme}",`);
  lines.push(`\tname = { en = "${meta.name.en}", ru = "${meta.name.ru}" },`);
  lines.push(`\tstars_required = ${meta.stars_required},`);
  lines.push(`\tlevels = {`);
  for (const lvl of levels) lines.push(levelToLua(lvl) + ",");
  lines.push(`\t},`);
  lines.push(`}`);
  lines.push(``);
  return lines.join("\n");
}

function signature(lvl) {
  return JSON.stringify({
    g: lvl.ground || [], r: lvl.ramps || [], b: lvl.blocks || [], a: lvl.anchors || [],
    p: lvl.portals || [], s: lvl.spikes || [], st: lvl.start, f: lvl.finish,
  });
}

function main() {
  const args = process.argv.slice(2);
  const write = args.includes("--write");
  const chapterArg = args.find((a) => a.startsWith("--chapter="));
  const only = chapterArg ? Number(chapterArg.split("=")[1]) : null;
  const loaded = loadAllChapters();
  const firstSix = {};
  for (const ch of loaded) firstSix[ch.chapterIndex] = ch.levels.slice(0, 6);

  let failed = false;
  const report = {};
  for (const chNum of [1, 2, 3, 4]) {
    if (only && chNum !== only) continue;
    const specs = CHAPTERS[chNum];
    if (specs.length !== 34) throw new Error(`chapter ${chNum} has ${specs.length} specs`);
    const levels = firstSix[chNum].slice();
    const sigs = new Set(levels.map(signature));
    report[chNum] = [];
    for (let i = 0; i < specs.length; i++) {
      const num = i + 7;
      const id = `${chNum}-${num}`;
      const lvl = buildSpec(specs[i], id);
      lvl.tip = specs[i].opts.tip;
      if (sigs.has(signature(lvl))) console.log(`WARN ${id}: duplicate geometry`);
      sigs.add(signature(lvl));
      const { res } = fitBudget(lvl, specs[i].opts.mult);
      if (!res.ok) {
        failed = true;
        console.log(`FAIL ${id} ${specs[i].en}: ${res.msg || res.err} (truck ${res.truckRes}, empty ${res.emptyRes}, reason ${res.reason}, cost ${res.cost})`);
        levels.push(lvl);
        continue;
      }
      console.log(`ok   ${id} ${specs[i].en}: cost ${res.cost} budget ${lvl.budget} t=${res.time.toFixed(1)} stress=${(res.stress || 0).toFixed(2)}`);
      levels.push(lvl);
      report[chNum].push({ id, cost: res.cost, budget: lvl.budget, time: res.time, stress: res.stress });
    }
    if (write) {
      fs.writeFileSync(path.join(ROOT, `game/levels/chapter${chNum}.lua`), chapterFile(chNum, levels), "utf8");
      console.log(`saved game/levels/chapter${chNum}.lua (${levels.length} levels)`);
    }
  }
  if (!write) console.log("dry run: pass --write to update chapter files");
  fs.writeFileSync(path.join(ROOT, only ? `tools/gen/campaign_report_ch${only}.json` : "tools/gen/campaign_report.json"), JSON.stringify(report, null, 2), "utf8");
  if (failed) process.exitCode = 1;
}

main();
