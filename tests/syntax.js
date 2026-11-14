// Compile every Lua source of the project (no execution) to catch syntax errors.
const path = require("path"), fs = require("fs");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");
const ROOT = path.resolve(__dirname, "..");
const exts = [".lua", ".script", ".gui_script", ".render_script"];
const files = [];
(function walk(d) {
  for (const f of fs.readdirSync(d)) {
    if (["node_modules", ".git", ".internal", "build"].includes(f)) continue;
    const p = path.join(d, f);
    if (fs.statSync(p).isDirectory()) walk(p);
    else if (exts.includes(path.extname(f))) files.push(p);
  }
})(ROOT);
let bad = 0;
// Defold bundles only modules required with a string literal; require(variable) fails at runtime.
const DYNAMIC = /\brequire\s*\(\s*[^"'\s)]/;
for (const f of files) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const src = fs.readFileSync(f);
  const rel = path.relative(ROOT, f);
  if (!rel.startsWith("tests") && DYNAMIC.test(src.toString("utf8").replace(/--[^\n]*/g, ""))) {
    bad++;
    console.log("DYNAMIC REQUIRE (not bundled by Defold):", rel);
  }
  if (lauxlib.luaL_loadbuffer(L, src, null, to_luastring(path.relative(ROOT, f))) !== lua.LUA_OK) {
    bad++;
    console.log("SYNTAX", to_jsstring(lua.lua_tostring(L, -1)));
  }
}
console.log(`${files.length} files, ${bad} with syntax errors`);
process.exit(bad ? 1 : 0);
