// Draws the GUI layer of a dumped scene over a 3D preview: atlas boxes for real, text as translucent
// bars sized like the label (layout check for portrait / landscape).
//   node tools/preview_gui.js scene.json base.png out.png
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const png = require("./gen/png");

const ROOT = path.resolve(__dirname, "..");
const scene = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));

function decode(file) {
  const b = fs.readFileSync(file);
  let p = 8, w, h;
  const idat = [];
  while (p < b.length) {
    const len = b.readUInt32BE(p), type = b.toString("ascii", p + 4, p + 8), d = b.slice(p + 8, p + 8 + len);
    if (type === "IHDR") { w = d.readUInt32BE(0); h = d.readUInt32BE(4); }
    if (type === "IDAT") idat.push(d);
    p += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (w * 4 + 1)];
    for (let x = 0; x < w * 4; x++) {
      const i = y * (w * 4 + 1) + 1 + x;
      let v = raw[i];
      const a = x >= 4 ? out[y * w * 4 + x - 4] : 0, up = y > 0 ? out[(y - 1) * w * 4 + x] : 0, ul = x >= 4 && y > 0 ? out[(y - 1) * w * 4 + x - 4] : 0;
      if (f === 1) v += a; else if (f === 2) v += up; else if (f === 3) v += (a + up) >> 1;
      else if (f === 4) { const pp = a + up - ul, pa = Math.abs(pp - a), pb = Math.abs(pp - up), pc = Math.abs(pp - ul); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : ul; }
      out[y * w * 4 + x] = v & 255;
    }
  }
  return { w, h, d: out };
}

const base = decode(process.argv[3]);
const W = base.w, H = base.h;
const k = W / scene.w;
const img = base.d;
const atlas = {};
function image(name) {
  if (!(name in atlas)) {
    const f = path.join(ROOT, "assets/images/ui", name + ".png");
    atlas[name] = fs.existsSync(f) ? decode(f) : null;
  }
  return atlas[name];
}
function blend(x, y, r, g, b, a) {
  if (x < 0 || y < 0 || x >= W || y >= H || a <= 0) return;
  const i = (y * W + x) * 4;
  img[i] = img[i] * (1 - a) + r * a;
  img[i + 1] = img[i + 1] * (1 - a) + g * a;
  img[i + 2] = img[i + 2] * (1 - a) + b * a;
}

for (const n of scene.gui) {
  const [x0, y0, x1, y1] = n.b.map((v) => v * k);
  const sx0 = Math.round(x0), sx1 = Math.round(x1), sy0 = Math.round(H - y1), sy1 = Math.round(H - y0);
  const [cr, cg, cb, ca] = n.c;
  if (n.k === "box") {
    const im = image(n.a || "white");
    if (!im) continue;
    const bw = Math.max(1, sx1 - sx0), bh = Math.max(1, sy1 - sy0);
    for (let y = sy0; y < sy1; y++) {
      for (let x = sx0; x < sx1; x++) {
        const u = Math.min(im.w - 1, Math.floor(((x - sx0) / bw) * im.w));
        const v = Math.min(im.h - 1, Math.floor(((y - sy0) / bh) * im.h));
        const i = (v * im.w + u) * 4;
        blend(x, y, im.d[i] * cr, im.d[i + 1] * cg, im.d[i + 2] * cb, (im.d[i + 3] / 255) * ca);
      }
    }
  } else if (n.k === "text" && n.t) {
    // approximate label extent: width ~ 0.55 em per char, centered on the node bounds
    const fs_ = n.fs * k;
    const tw = Math.min(n.t.length * fs_ * 0.52, (x1 - x0) || 1e9);
    const cx = (x0 + x1) / 2, cy = H - (y0 + y1) / 2;
    for (let y = Math.round(cy - fs_ * 0.32); y < cy + fs_ * 0.32; y++) {
      for (let x = Math.round(cx - tw / 2); x < cx + tw / 2; x++) blend(x, y, cr * 255, cg * 255, cb * 255, 0.85 * ca);
    }
  }
}
png.write(process.argv[4], W, H, img);
console.log("gui preview", process.argv[4], scene.gui.length, "nodes");
