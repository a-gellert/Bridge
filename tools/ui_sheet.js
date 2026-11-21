// Contact sheet of every UI atlas image on the GUI panel colour, for style reviews.
//   node tools/ui_sheet.js [out.png]      (default build/ui_sheet.png)
// Glyphs (white, tinted in the GUI) are shown on a button colour; coloured item icons on a panel.
const fs = require("fs");
const path = require("path");
const png = require("./gen/png");

const ROOT = path.resolve(__dirname, "..");
const OUT = process.argv[2] || path.join(ROOT, "build/ui_sheet.png");
const atlas = fs.readFileSync(path.join(ROOT, "assets/images/ui.atlas"), "utf8");
const names = [...atlas.matchAll(/ui\/(\w+)\.png/g)].map((m) => m[1]);

const CELL = 140, COLS = 10;
const rows = Math.ceil(names.length / COLS);
const W = CELL * COLS, H = CELL * rows;
const buf = Buffer.alloc(W * H * 4);
const BG = [0x1b, 0x20, 0x30], PANEL = [0x26, 0x2d, 0x40], BTN = [0x39, 0x42, 0x5e];
for (let i = 0; i < W * H; i++) { buf[i * 4] = BG[0]; buf[i * 4 + 1] = BG[1]; buf[i * 4 + 2] = BG[2]; buf[i * 4 + 3] = 255; }

names.forEach((name, i) => {
  const im = png.decode(path.join(ROOT, "assets/images/ui", name + ".png"));
  // white-only images are glyphs
  let colored = false;
  for (let p = 0; p < im.w * im.h && !colored; p++) {
    if (im.data[p * 4 + 3] < 20) continue;
    const r = im.data[p * 4], g = im.data[p * 4 + 1], b = im.data[p * 4 + 2];
    if (Math.abs(r - g) > 12 || Math.abs(g - b) > 12) colored = true;
  }
  const bg = colored ? PANEL : BTN;
  const cx = (i % COLS) * CELL, cy = Math.floor(i / COLS) * CELL;
  for (let y = 4; y < CELL - 4; y++) for (let x = 4; x < CELL - 4; x++) {
    const k = ((cy + y) * W + cx + x) * 4;
    buf[k] = bg[0]; buf[k + 1] = bg[1]; buf[k + 2] = bg[2];
  }
  const s = Math.min(1, (CELL - 20) / Math.max(im.w, im.h));
  const dw = Math.round(im.w * s), dh = Math.round(im.h * s);
  const ox = cx + Math.round((CELL - dw) / 2), oy = cy + Math.round((CELL - dh) / 2);
  for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
    const sx = Math.min(im.w - 1, Math.floor(x / s)), sy = Math.min(im.h - 1, Math.floor(y / s));
    const q = (sy * im.w + sx) * 4, k = ((oy + y) * W + ox + x) * 4;
    const a = im.data[q + 3] / 255;
    for (let c = 0; c < 3; c++) buf[k + c] = Math.round(im.data[q + c] * a + buf[k + c] * (1 - a));
  }
});
png.write(OUT, W, H, buf);
console.log("ui sheet", OUT, names.length, "images");
