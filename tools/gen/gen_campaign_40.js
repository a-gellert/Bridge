// Generator for 40 levels per biome (160 levels total across 4 chapters).
// Uses Fengari to test every reference solution in the headless XPBD engine,
// auto-balancing budgets and ensuring every level passes the truck test.
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.resolve(__dirname, "../../tests/node_modules/fengari"));

const ROOT = path.resolve(__dirname, "../..");

function createLuaEnv() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const rootUnix = ROOT.replace(/\\/g, "/");
  const boot = `
    package.path = "${rootUnix}/?.lua;${rootUnix}/tests/?.lua;" .. package.path
    math.atan2 = math.atan2 or math.atan
  `;
  lauxlib.luaL_dostring(L, to_luastring(boot));
  lua.lua_pushcfunction(L, (L) => {
    const p = to_jsstring(lauxlib.luaL_checkstring(L, 1));
    try { lua.lua_pushstring(L, to_luastring(fs.readFileSync(p, "utf8"))); } catch (e) { lua.lua_pushnil(L); }
    return 1;
  });
  lua.lua_setglobal(L, to_luastring("readfile"));
  return L;
}

const L = createLuaEnv();

function checkLevelInLua(lvl) {
  const luaTable = levelToLua(lvl);
  const script = `
    local check = require("level_check")
    local lvl = ${luaTable}
    lvl.number = tonumber(lvl.id:match("%-(%d+)"))
    local rep = check.check(lvl, { vehicles = { "truck" }, quiet = true })
    local res = {
      errors = rep.errors,
      won = (rep.results.truck == "won"),
      empty_failed = (rep.empty ~= "won"),
      cost = rep.cost,
      budget = lvl.budget
    }
    local d = (rep.detail and rep.detail.truck) or {}
    return res.won and res.empty_failed and (#res.errors == 0), rep.results.truck, rep.empty, (#res.errors > 0 and rep.errors[1] or "ok"), rep.cost,
      tostring(d.reason), d.time or 0, d.broken or 0, d.stress or 0
  `;
  const status = lauxlib.luaL_dostring(L, to_luastring(script));
  if (status !== lua.LUA_OK) {
    const err = to_jsstring(lua.lua_tostring(L, -1));
    lua.lua_pop(L, 1);
    return { ok: false, err: "Lua error: " + err };
  }
  const ok = lua.lua_toboolean(L, -9);
  const truckRes = to_jsstring(lua.lua_tostring(L, -8));
  const emptyRes = to_jsstring(lua.lua_tostring(L, -7));
  const msg = to_jsstring(lua.lua_tostring(L, -6));
  const cost = lua.lua_tonumber(L, -5);
  const reason = to_jsstring(lua.lua_tostring(L, -4));
  const time = lua.lua_tonumber(L, -3);
  const broken = lua.lua_tonumber(L, -2);
  const stress = lua.lua_tonumber(L, -1);
  lua.lua_pop(L, 9);
  return { ok, truckRes, emptyRes, msg, cost, reason, time, broken, stress };
}

function levelToLua(lvl) {
  const lines = [];
  lines.push(`\t\t{`);
  lines.push(`\t\t\tid = "${lvl.id}",`);
  lines.push(`\t\t\tname = { en = "${lvl.name.en.replace(/"/g, '\\"')}", ru = "${lvl.name.ru.replace(/"/g, '\\"')}" },`);
  lines.push(`\t\t\tbudget = ${lvl.budget},`);
  lines.push(`\t\t\tmaterials = { ${lvl.materials.map(m => `"${m}"`).join(", ")} },`);
  if (lvl.assist) lines.push(`\t\t\tassist = true,`);

  if (lvl.ground && lvl.ground.length) {
    const gStr = lvl.ground.map(g => `{ ${g.join(", ")} }`).join(", ");
    lines.push(`\t\t\tground = { ${gStr} },`);
  }
  if (lvl.ramps && lvl.ramps.length) {
    const rStr = lvl.ramps.map(r => `{ ${r.join(", ")} }`).join(", ");
    lines.push(`\t\t\tramps = { ${rStr} },`);
  }
  if (lvl.blocks && lvl.blocks.length) {
    const bStr = lvl.blocks.map(b => `{ ${b.join(", ")} }`).join(", ");
    lines.push(`\t\t\tblocks = { ${bStr} },`);
  }
  if (lvl.anchors && lvl.anchors.length) {
    const aStr = lvl.anchors.map(a => `{ ${a.join(", ")} }`).join(", ");
    lines.push(`\t\t\tanchors = { ${aStr} },`);
  }
  if (lvl.portals && lvl.portals.length) {
    const pStr = lvl.portals.map(p => {
      const a = p[0], b = p[1];
      const angA = a.angle === 0 ? "0" : (Math.abs(a.angle - Math.PI) < 0.01 ? "math.pi" : (Math.abs(a.angle - Math.PI/2) < 0.01 ? "math.pi / 2" : a.angle.toFixed(4)));
      const angB = b.angle === 0 ? "0" : (Math.abs(b.angle - Math.PI) < 0.01 ? "math.pi" : (Math.abs(b.angle - Math.PI/2) < 0.01 ? "math.pi / 2" : b.angle.toFixed(4)));
      return `{ { x = ${a.x}, y = ${a.y}, angle = ${angA} }, { x = ${b.x}, y = ${b.y}, angle = ${angB} } }`;
    }).join(", ");
    lines.push(`\t\t\tportals = { ${pStr} },`);
  }
  if (lvl.spikes && lvl.spikes.length) {
    const sStr = lvl.spikes.map(s => `{ ${s.join(", ")} }`).join(", ");
    lines.push(`\t\t\tspikes = { ${sStr} },`);
  }

  lines.push(`\t\t\tstart = ${lvl.start}, finish = ${lvl.finish},` + (lvl.water !== undefined ? ` water = ${lvl.water},` : ` kill_y = ${lvl.kill_y},`));
  lines.push(`\t\t\tarea = { ${lvl.area.join(", ")} },`);
  if (lvl.tip) lines.push(`\t\t\ttip = "${lvl.tip}",`);

  lines.push(`\t\t\tsolution = {`);
  for (const s of lvl.solution) {
    lines.push(`\t\t\t\t{ "${s[0]}", ${s[1]}, ${s[2]}, ${s[3]}, ${s[4]} },`);
  }
  lines.push(`\t\t\t},`);
  lines.push(`\t\t}`);
  return lines.join("\n");
}

// -------------------------------------------------------------
// Procedural Bridge Builders
// -------------------------------------------------------------

// Box Truss (Pratt / Howe): Exceptionally rigid in XPBD
function makeBoxTruss(opts) {
  const {
    id, name, x0 = 0, y0 = 0, x1, y1 = 0, segments, h = 2.4,
    matRoad = "road", matTruss = "wood", materials = ["road", "wood", "steel"],
    water = -4, startPad = 6, finishPad = 8,
    extraGround = []
  } = opts;

  const dx = (x1 - x0) / segments;
  const dy = (y1 - y0) / segments;
  const sol = [];
  const added = new Set();
  function add(m, px0, py0, px1, py1) {
    px0 = Number(px0.toFixed(2));
    py0 = Number(py0.toFixed(2));
    px1 = Number(px1.toFixed(2));
    py1 = Number(py1.toFixed(2));
    const k1 = px0 + ',' + py0 + '-' + px1 + ',' + py1;
    const k2 = px1 + ',' + py1 + '-' + px0 + ',' + py0;
    if (added.has(k1) || added.has(k2)) return;
    added.add(k1);
    sol.push([m, px0, py0, px1, py1]);
  }

  for (let k = 0; k < segments; k++) {
    const rx0 = x0 + k * dx, ry0 = y0 + k * dy;
    const rx1 = x0 + (k + 1) * dx, ry1 = y0 + (k + 1) * dy;
    add(matRoad, rx0, ry0, rx1, ry1);
    add(matTruss, rx0, ry0 + h, rx1, ry1 + h);
    add(matTruss, rx0, ry0, rx0, ry0 + h);
    add(matTruss, rx1, ry1, rx1, ry1 + h);
    add(matTruss, rx0, ry0, rx1, ry1 + h);
    add(matTruss, rx0, ry0 + h, rx1, ry1);
  }

  const anchors = [
    [x0, y0],
    [x1, y1],
    [x0, y0 + h],
    [x1, y1 + h]
  ];
  const blocks = [
    [x0 - 4, y0 + h, x0, y0 + h + 2],
    [x1, y1 + h, x1 + 4, y1 + h + 2]
  ];
  const yMin = Math.min(y0, y1) - 3;
  const yMax = Math.max(y0, y1) + h + 3;
  const area = [Math.floor(x0 - 1), Math.floor(yMin), Math.ceil(x1 + 1), Math.ceil(yMax)];

  const ground = [
    [-40, x0, y0],
    [x1, x1 + 40, y1],
    ...extraGround
  ];

  return {
    id,
    name,
    budget: 99999,
    materials,
    ground,
    blocks,
    anchors,
    start: Number((x0 - startPad).toFixed(1)),
    finish: Number((x1 + finishPad).toFixed(1)),
    water,
    area,
    solution: sol
  };
}

// Builds a multi-gap bridge with a central pier island
function buildPierBridge(opts) {
  const {
    id, name, x0 = 0, y0 = 0, x1, y1 = 0, pierX, pierW = 2.4, pierY = -2.6,
    matRoad = "road", matTruss = "steel",
    materials = ["road", "steel", "wood"],
    water = -6, startPad = 6, finishPad = 8
  } = opts;

  const seg1 = Math.max(2, Math.round((pierX - x0) / 2.6));
  const seg2 = Math.max(2, Math.round((x1 - (pierX + pierW)) / 2.6));
  const anchors = [
    [x0, y0],
    [pierX, y0],
    [pierX + pierW, y0],
    [x1, y1],
    [pierX, pierY],
    [pierX + pierW, pierY]
  ];

  const sol = [];
  const added = new Set();
  function add(m, px0, py0, px1, py1) {
    px0 = Number(px0.toFixed(2));
    py0 = Number(py0.toFixed(2));
    px1 = Number(px1.toFixed(2));
    py1 = Number(py1.toFixed(2));
    const k1 = px0 + ',' + py0 + '-' + px1 + ',' + py1;
    const k2 = px1 + ',' + py1 + '-' + px0 + ',' + py0;
    if (added.has(k1) || added.has(k2)) return;
    added.add(k1);
    sol.push([m, px0, py0, px1, py1]);
  }

  // Left span
  const dx1 = (pierX - x0) / seg1;
  const leftNodes = [];
  for (let k = 0; k <= seg1; k++) leftNodes.push({ x: Number((x0 + k * dx1).toFixed(2)), y: y0 });
  for (let k = 0; k < seg1; k++) add(matRoad, leftNodes[k].x, leftNodes[k].y, leftNodes[k+1].x, leftNodes[k+1].y);
  // Pier deck
  add(matRoad, pierX, y0, pierX + pierW, y0);
  // Right span
  const dx2 = (x1 - (pierX + pierW)) / seg2;
  const rightNodes = [];
  for (let k = 0; k <= seg2; k++) rightNodes.push({ x: Number((pierX + pierW + k * dx2).toFixed(2)), y: y1 });
  for (let k = 0; k < seg2; k++) add(matRoad, rightNodes[k].x, rightNodes[k].y, rightNodes[k+1].x, rightNodes[k+1].y);

  // Pier supports from lower anchors
  add(matTruss, pierX, pierY, pierX, y0);
  add(matTruss, pierX + pierW, pierY, pierX + pierW, y0);
  add(matTruss, pierX, pierY, pierX + pierW, y0);
  add(matTruss, pierX + pierW, pierY, pierX, y0);

  // Under trusses for left span
  for (let k = 0; k < seg1; k++) {
    const mx = Number(((leftNodes[k].x + leftNodes[k+1].x)*0.5).toFixed(2));
    add(matTruss, leftNodes[k].x, leftNodes[k].y, mx, y0 - 1.6);
    add(matTruss, mx, y0 - 1.6, leftNodes[k+1].x, leftNodes[k+1].y);
    if (k > 0) add(matTruss, Number(((leftNodes[k-1].x + leftNodes[k].x)*0.5).toFixed(2)), y0 - 1.6, mx, y0 - 1.6);
  }
  // Under trusses for right span
  for (let k = 0; k < seg2; k++) {
    const mx = Number(((rightNodes[k].x + rightNodes[k+1].x)*0.5).toFixed(2));
    add(matTruss, rightNodes[k].x, rightNodes[k].y, mx, y1 - 1.6);
    add(matTruss, mx, y1 - 1.6, rightNodes[k+1].x, rightNodes[k+1].y);
    if (k > 0) add(matTruss, Number(((rightNodes[k-1].x + rightNodes[k].x)*0.5).toFixed(2)), y1 - 1.6, mx, y1 - 1.6);
  }

  const area = [Math.floor(x0 - 1), Math.floor(pierY - 2), Math.ceil(x1 + 1), Math.ceil(Math.max(y0, y1) + 4)];
  const ground = [
    [-40, x0, y0],
    [pierX, pierX + pierW, pierY],
    [x1, x1 + 40, y1]
  ];

  return {
    id,
    name,
    budget: 99999,
    materials,
    ground,
    anchors,
    start: Number((x0 - startPad).toFixed(1)),
    finish: Number((x1 + finishPad).toFixed(1)),
    water,
    area,
    solution: sol
  };
}

// Builds an Aperture Science style portal level
function buildPortalLevel(opts) {
  const {
    id, name,
    entryX, entryY, entryAngle = Math.PI, entryWallX0, entryWallX1, entryWallY0, entryWallY1,
    exitX, exitY, exitAngle = 0, exitWallX0, exitWallX1, exitWallY0, exitWallY1,
    bridgeX0, bridgeY0, bridgeX1, bridgeY1, bridgeSegments = 2,
    matRoad = "road", matTruss = "wood",
    materials = ["road", "wood", "steel", "boost"],
    boostApproach = false, approachX0 = 0, approachX1 = 6,
    water = -4, startPad = 6, finishPad = 8,
    extraBlocks = [], extraSpikes = []
  } = opts;

  const anchors = [[bridgeX0, bridgeY0], [bridgeX1, bridgeY1]];
  if (boostApproach) {
    anchors.push([approachX0, bridgeY0]);
  }

  const solution = [];
  if (boostApproach) {
    const bdx = (approachX1 - approachX0) / 2;
    solution.push(["boost", approachX0, bridgeY0, approachX0 + bdx, bridgeY0]);
    solution.push(["boost", approachX0 + bdx, bridgeY0, approachX1, bridgeY0]);
  }

  // Bridge deck
  const bdx = (bridgeX1 - bridgeX0) / bridgeSegments;
  const bdy = (bridgeY1 - bridgeY0) / bridgeSegments;
  const nodes = [];
  for (let k = 0; k <= bridgeSegments; k++) {
    nodes.push({ x: Number((bridgeX0 + k * bdx).toFixed(2)), y: Number((bridgeY0 + k * bdy).toFixed(2)) });
  }
  for (let k = 0; k < bridgeSegments; k++) {
    solution.push([matRoad, nodes[k].x, nodes[k].y, nodes[k+1].x, nodes[k+1].y]);
  }
  for (let k = 0; k < bridgeSegments; k++) {
    const mx = Number(((nodes[k].x + nodes[k+1].x)*0.5).toFixed(2));
    const my = Number(((nodes[k].y + nodes[k+1].y)*0.5 + 1.8).toFixed(2));
    solution.push([matTruss, nodes[k].x, nodes[k].y, mx, my]);
    solution.push([matTruss, mx, my, nodes[k+1].x, nodes[k+1].y]);
    if (k > 0) {
      const prevMx = Number(((nodes[k-1].x + nodes[k].x)*0.5).toFixed(2));
      solution.push([matTruss, prevMx, my, mx, my]);
    }
  }

  const portals = [
    [
      { x: entryX, y: entryY, angle: entryAngle },
      { x: exitX, y: exitY, angle: exitAngle }
    ]
  ];

  const blocks = [
    [entryWallX0, entryWallY0, entryWallX1, entryWallY1],
    [exitWallX0, exitWallY0, exitWallX1, exitWallY1],
    ...extraBlocks
  ];

  const area = [
    Math.min(bridgeX0, approachX0) - 1,
    Math.min(bridgeY0, bridgeY1) - 4,
    Math.max(bridgeX1, exitX) + 2,
    Math.max(bridgeY0, bridgeY1, exitY) + 5
  ];

  const ground = [
    [-40, boostApproach ? approachX0 : bridgeX0, bridgeY0],
    [bridgeX1, bridgeX1 + 40, bridgeY1]
  ];

  return {
    id,
    name,
    budget: 99999,
    materials,
    ground,
    blocks,
    portals,
    spikes: extraSpikes,
    anchors,
    start: Number(((boostApproach ? approachX0 : bridgeX0) - startPad).toFixed(1)),
    finish: Number((bridgeX1 + finishPad).toFixed(1)),
    water,
    area,
    solution
  };
}

module.exports = {
  createLuaEnv,
  checkLevelInLua,
  levelToLua,
  makeBoxTruss,
  buildPierBridge,
  buildPortalLevel
};
