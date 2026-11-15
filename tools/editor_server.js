// Web-based Level Editor server for Bridge Mad.
// Serves tools/editor/index.html and provides REST APIs to read, test, and save levels
// directly to game/levels/chapterN.lua.
const http = require("http");
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(path.resolve(__dirname, "../tests/node_modules/fengari"));

const ROOT = path.resolve(__dirname, "..");
const PORT = process.env.PORT || 8088;

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

// Convert a Lua table into a JS object/array
function luaValueToJs(L, idx) {
  const t = lua.lua_type(L, idx);
  if (t === lua.LUA_TNIL) return null;
  if (t === lua.LUA_TBOOLEAN) return !!lua.lua_toboolean(L, idx);
  if (t === lua.LUA_TNUMBER) return lua.lua_tonumber(L, idx);
  if (t === lua.LUA_TSTRING) return to_jsstring(lua.lua_tostring(L, idx));
  if (t === lua.LUA_TTABLE) {
    // Check if table is sequential array
    const len = lua.lua_rawlen(L, idx);
    if (len > 0) {
      const arr = [];
      for (let i = 1; i <= len; i++) {
        lua.lua_rawgeti(L, idx, i);
        arr.push(luaValueToJs(L, -1));
        lua.lua_pop(L, 1);
      }
      return arr;
    }
    const obj = {};
    lua.lua_pushnil(L);
    const absIdx = idx < 0 ? lua.lua_gettop(L) + idx : idx;
    while (lua.lua_next(L, absIdx) !== 0) {
      const key = to_jsstring(lua.lua_tostring(L, -2));
      const val = luaValueToJs(L, -1);
      obj[key] = val;
      lua.lua_pop(L, 1);
    }
    return obj;
  }
  return null;
}

// Load all chapters into memory
function loadAllChapters() {
  const chapters = [];
  const L = createLuaEnv();
  for (let c = 1; c <= 4; c++) {
    const script = `
      package.loaded["game.levels.chapter${c}"] = nil
      return require("game.levels.chapter${c}")
    `;
    const status = lauxlib.luaL_dostring(L, to_luastring(script));
    if (status === lua.LUA_OK) {
      const ch = luaValueToJs(L, -1);
      ch.chapterIndex = c;
      chapters.push(ch);
      lua.lua_pop(L, 1);
    }
  }
  return chapters;
}

// Format a level back to pristine Lua table
function formatLevelLua(lvl) {
  const lines = [];
  lines.push(`\t\t{`);
  lines.push(`\t\t\tid = "${lvl.id}",`);
  const enName = (lvl.name && lvl.name.en) ? lvl.name.en.replace(/"/g, '\\"') : lvl.id;
  const ruName = (lvl.name && lvl.name.ru) ? lvl.name.ru.replace(/"/g, '\\"') : enName;
  lines.push(`\t\t\tname = { en = "${enName}", ru = "${ruName}" },`);
  lines.push(`\t\t\tbudget = ${Math.round(lvl.budget || 2000)},`);

  const mats = lvl.materials && lvl.materials.length ? lvl.materials : ["road", "wood"];
  lines.push(`\t\t\tmaterials = { ${mats.map(m => `"${m}"`).join(", ")} },`);
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
      const angA = (a.angle === 0) ? "0" : (Math.abs(a.angle - Math.PI) < 0.01 ? "math.pi" : a.angle);
      const angB = (b.angle === 0) ? "0" : (Math.abs(b.angle - Math.PI) < 0.01 ? "math.pi" : b.angle);
      return `{ { x = ${a.x}, y = ${a.y}, angle = ${angA} }, { x = ${b.x}, y = ${b.y}, angle = ${angB} } }`;
    }).join(", ");
    lines.push(`\t\t\tportals = { ${pStr} },`);
  }
  if (lvl.spikes && lvl.spikes.length) {
    const sStr = lvl.spikes.map(s => `{ ${s.join(", ")} }`).join(", ");
    lines.push(`\t\t\tspikes = { ${sStr} },`);
  }

  lines.push(`\t\t\tstart = ${lvl.start || -6}, finish = ${lvl.finish || 20},` + (lvl.water !== undefined ? ` water = ${lvl.water},` : ` kill_y = ${lvl.kill_y || -10},`));
  const area = lvl.area || [-1, -4, 21, 6];
  lines.push(`\t\t\tarea = { ${area.join(", ")} },`);
  if (lvl.tip) lines.push(`\t\t\ttip = "${lvl.tip}",`);

  lines.push(`\t\t\tsolution = {`);
  for (const s of (lvl.solution || [])) {
    lines.push(`\t\t\t\t{ "${s[0]}", ${s[1]}, ${s[2]}, ${s[3]}, ${s[4]} },`);
  }
  lines.push(`\t\t\t},`);
  lines.push(`\t\t}`);
  return lines.join("\n");
}

// Save a chapter file with updated levels
function saveChapterFile(chNum, chapterObj) {
  const filePath = path.join(ROOT, `game/levels/chapter${chNum}.lua`);
  // Create backup
  if (fs.existsSync(filePath)) {
    fs.copyFileSync(filePath, filePath + ".bak");
  }

  const lines = [];
  lines.push(`-- Chapter ${chNum}: ${chapterObj.name.en}. 40 levels.`);
  lines.push(`return {`);
  lines.push(`\tid = "${chapterObj.id}",`);
  lines.push(`\ttheme = "${chapterObj.theme}",`);
  lines.push(`\tname = { en = "${chapterObj.name.en}", ru = "${chapterObj.name.ru}" },`);
  lines.push(`\tstars_required = ${chapterObj.stars_required || 0},`);
  lines.push(`\tlevels = {`);

  for (const lvl of chapterObj.levels) {
    lines.push(formatLevelLua(lvl) + ",");
  }

  lines.push(`\t},`);
  lines.push(`}`);
  lines.push(``);

  fs.writeFileSync(filePath, lines.join("\n"), "utf8");
  return true;
}

// Run headless physics simulation on a level
function simulateLevel(lvl) {
  const L = createLuaEnv();
  const luaCode = formatLevelLua(lvl);
  const script = `
    local check = require("level_check")
    local lvl = ${luaCode}
    lvl.number = tonumber(lvl.id:match("%-(%d+)")) or 1
    local rep = check.check(lvl, { vehicles = { "truck" } })
    return rep.results.truck, rep.empty, rep.cost, rep.budget, (#rep.errors > 0 and rep.errors[1] or "ok")
  `;
  const status = lauxlib.luaL_dostring(L, to_luastring(script));
  if (status !== lua.LUA_OK) {
    const err = to_jsstring(lua.lua_tostring(L, -1));
    return { ok: false, error: err };
  }
  const truckRes = to_jsstring(lua.lua_tostring(L, -5));
  const emptyRes = to_jsstring(lua.lua_tostring(L, -4));
  const cost = lua.lua_tonumber(L, -3);
  const budget = lua.lua_tonumber(L, -2);
  const msg = to_jsstring(lua.lua_tostring(L, -1));
  return {
    ok: (truckRes === "won" && emptyRes !== "won" && msg === "ok"),
    truckResult: truckRes,
    emptyResult: emptyRes,
    cost,
    budget,
    error: msg === "ok" ? null : msg
  };
}

// HTTP Server
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;

  // Static files
  if (req.method === "GET") {
    if (pathname === "/" || pathname === "/index.html") {
      const htmlPath = path.join(ROOT, "tools/editor/index.html");
      if (fs.existsSync(htmlPath)) {
        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
        return res.end(fs.readFileSync(htmlPath));
      }
    }
    if (pathname === "/api/chapters") {
      try {
        const data = loadAllChapters();
        res.writeHead(200, { "Content-Type": "application/json" });
        return res.end(JSON.stringify(data));
      } catch (err) {
        res.writeHead(500, { "Content-Type": "application/json" });
        return res.end(JSON.stringify({ error: err.message }));
      }
    }
  }

  // POST APIs
  if (req.method === "POST") {
    let body = "";
    req.on("data", chunk => { body += chunk; });
    req.on("end", () => {
      let data = {};
      try { if (body) data = JSON.parse(body); } catch (e) {
        res.writeHead(400, { "Content-Type": "application/json" });
        return res.end(JSON.stringify({ error: "Invalid JSON" }));
      }

      if (pathname === "/api/save-level") {
        try {
          const chNum = Number(data.chapterIndex || 1);
          const chapters = loadAllChapters();
          const targetCh = chapters.find(c => c.chapterIndex === chNum);
          if (!targetCh) throw new Error("Chapter not found");

          const idx = targetCh.levels.findIndex(l => l.id === data.level.id);
          if (idx >= 0) {
            targetCh.levels[idx] = data.level;
          } else {
            targetCh.levels.push(data.level);
          }
          saveChapterFile(chNum, targetCh);
          res.writeHead(200, { "Content-Type": "application/json" });
          return res.end(JSON.stringify({ ok: true, message: `Saved level ${data.level.id} to chapter${chNum}.lua` }));
        } catch (err) {
          res.writeHead(500, { "Content-Type": "application/json" });
          return res.end(JSON.stringify({ error: err.message }));
        }
      }

      if (pathname === "/api/create-level") {
        try {
          const chNum = Number(data.chapterIndex || 1);
          const chapters = loadAllChapters();
          const targetCh = chapters.find(c => c.chapterIndex === chNum);
          if (!targetCh) throw new Error("Chapter not found");

          const nextNum = targetCh.levels.length + 1;
          const newLevel = data.level || {
            id: `${chNum}-${nextNum}`,
            name: { en: `New Level ${nextNum}`, ru: `Новый уровень ${nextNum}` },
            budget: 2500,
            materials: ["road", "wood"],
            ground: [[-40, 0, 0], [10, 50, 0]],
            anchors: [[0, 0], [10, 0]],
            start: -6,
            finish: 18,
            water: -4,
            area: [-1, -4, 11, 5],
            solution: [["road", 0, 0, 5, 0], ["road", 5, 0, 10, 0]]
          };
          targetCh.levels.push(newLevel);
          saveChapterFile(chNum, targetCh);
          res.writeHead(200, { "Content-Type": "application/json" });
          return res.end(JSON.stringify({ ok: true, level: newLevel }));
        } catch (err) {
          res.writeHead(500, { "Content-Type": "application/json" });
          return res.end(JSON.stringify({ error: err.message }));
        }
      }

      if (pathname === "/api/delete-level") {
        try {
          const chNum = Number(data.chapterIndex || 1);
          const chapters = loadAllChapters();
          const targetCh = chapters.find(c => c.chapterIndex === chNum);
          if (!targetCh) throw new Error("Chapter not found");

          targetCh.levels = targetCh.levels.filter(l => l.id !== data.levelId);
          saveChapterFile(chNum, targetCh);
          res.writeHead(200, { "Content-Type": "application/json" });
          return res.end(JSON.stringify({ ok: true }));
        } catch (err) {
          res.writeHead(500, { "Content-Type": "application/json" });
          return res.end(JSON.stringify({ error: err.message }));
        }
      }

      if (pathname === "/api/test-level") {
        try {
          const rep = simulateLevel(data.level);
          res.writeHead(200, { "Content-Type": "application/json" });
          return res.end(JSON.stringify(rep));
        } catch (err) {
          res.writeHead(500, { "Content-Type": "application/json" });
          return res.end(JSON.stringify({ error: err.message }));
        }
      }

      res.writeHead(404, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Not found" }));
    });
    return;
  }

  res.writeHead(404);
  res.end("Not Found");
});

function startServer(port = PORT) {
  server.listen(port, () => {
    console.log(`Bridge Mad Level Editor running at http://localhost:${port}`);
  });
}

if (require.main === module) {
  startServer();
}

module.exports = { server, startServer, loadAllChapters, formatLevelLua, saveChapterFile, simulateLevel };
