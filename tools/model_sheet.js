// Contact sheet of every model in assets/models (same renderer and lighting as the UI icons),
// for style reviews without Defold.
//   node tools/model_sheet.js [out.png]   (default build/model_sheet.png; the order is printed)
const fs = require("fs");
const path = require("path");
const png = require("./gen/png");
const ic = require("./gen/icon3d");

const ROOT = path.resolve(__dirname, "..");
const OUT = process.argv[2] || path.join(ROOT, "build/model_sheet.png");
// only models the game can spawn (a factory in world/world.go), loaded the way their entity loads them
const world = fs.readFileSync(path.join(ROOT, "world/world.go"), "utf8");
const ids = [...world.matchAll(/id: "f_(\w+)"/g)].map((m) => m[1]).sort();

const CW = 200, CH = 150, COLS = 9;
const rows = Math.ceil(ids.length / COLS);
const W = CW * COLS, H = CH * rows;
const buf = Buffer.alloc(W * H * 4);
for (let i = 0; i < W * H; i++) { buf[i * 4] = 0x8e; buf[i * 4 + 1] = 0xc6; buf[i * 4 + 2] = 0xee; buf[i * 4 + 3] = 255; }
const lines = [];
ids.forEach((id, i) => {
  let im;
  try {
    im = ic.render([{ mesh: ic.model(id) }], { w: CW - 8, h: CH - 8, outline: 2, pad: 4, yaw: -0.4, pitch: 0.25, ss: 3 }).layers.main;
  } catch (e) {
    lines.push(`${i + 1}. ${id} (failed: ${e.message})`);
    return;
  }
  lines.push(`${i + 1}. ${id}`);
  const cx = (i % COLS) * CW + 4, cy = Math.floor(i / COLS) * CH + 4;
  for (let y = 0; y < im.h; y++) for (let x = 0; x < im.w; x++) {
    const s = (y * im.w + x) * 4, d = ((cy + y) * W + cx + x) * 4;
    const a = im.data[s + 3] / 255;
    for (let k = 0; k < 3; k++) buf[d + k] = Math.round(im.data[s + k] * a + buf[d + k] * (1 - a));
  }
});
png.write(OUT, W, H, buf);
console.log(`model sheet ${OUT} (${COLS} per row, left to right):\n` + lines.join("\n"));
