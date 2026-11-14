// Headless test runner for the pure-Lua game core (physics, blueprint, levels, progress).
// Usage:  cd tests && npm install && node run.js [file.lua ...]
// Runs every tests/test_*.lua by default. Lua 5.3 (fengari) is close enough to Defold's 5.1 for pure modules.
const path = require("path");
const fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const ROOT = path.resolve(__dirname, "..").replace(/\\/g, "/");
const files = process.argv.slice(2).length
  ? process.argv.slice(2)
  : fs.readdirSync(__dirname).filter((f) => /^test_.*\.lua$/.test(f)).sort();

let failed = 0;
for (const f of files) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const boot = `
    package.path = "${ROOT}/?.lua;${ROOT}/tests/?.lua;" .. package.path
    math.atan2 = math.atan2 or math.atan
  `;
  if (lauxlib.luaL_dostring(L, to_luastring(boot)) !== lua.LUA_OK) throw new Error("boot failed");
  // readfile(path) -> string|nil (fengari has no io.open under node)
  lua.lua_pushcfunction(L, (L) => {
    const p = to_jsstring(lauxlib.luaL_checkstring(L, 1));
    try { lua.lua_pushstring(L, to_luastring(fs.readFileSync(p, "utf8"))); } catch (e) { lua.lua_pushnil(L); }
    return 1;
  });
  lua.lua_setglobal(L, to_luastring("readfile"));
  // writefile(path, string) for tools that dump data (scene previews)
  lua.lua_pushcfunction(L, (L) => {
    fs.writeFileSync(to_jsstring(lauxlib.luaL_checkstring(L, 1)), to_jsstring(lauxlib.luaL_checkstring(L, 2)));
    return 0;
  });
  lua.lua_setglobal(L, to_luastring("writefile"));
  const file = path.isAbsolute(f) ? f : path.join(__dirname, f);
  const t0 = Date.now();
  const status = lauxlib.luaL_dofile(L, to_luastring(file.replace(/\\/g, "/")));
  if (status !== lua.LUA_OK) {
    failed++;
    console.log(`FAIL ${f}: ${to_jsstring(lua.lua_tostring(L, -1))}`);
  } else {
    console.log(`ok   ${f} (${Date.now() - t0} ms)`);
  }
}
process.exit(failed ? 1 : 0);
