// Store icons (Android / iOS / web) in the game's own style: the real truck and bridge models
// rendered by tools/gen/icon3d.js over the Green Valley backdrop (sky gradient, two-facet peaks,
// grassy banks). Drawn once at 1024 px and box-filtered down to every store size.
//   node tools/gen/icons.js
const path = require("path");
const fs = require("fs");
const { Canvas, SDF, hex } = require("./png");
const png = require("./png");
const ic = require("./icon3d");

const BIG = 1024;

function mix(a, b, t) {
  return a.map((v, k) => Math.round(v + (b[k] - v) * t));
}

function background() {
  const c = new Canvas(BIG, BIG);
  const top = hex("#3E93DE"), bottom = hex("#9AD8FF");
  // sky gradient: one row band at a time
  for (let y = 0; y < BIG; y += 4) {
    c.draw(SDF.rect(BIG / 2, y + 2, BIG / 2, 2.6), mix(top, bottom, Math.pow(y / BIG, 0.8)));
  }
  // sun
  c.draw(SDF.circle(770, 250, 120), [255, 246, 214], 0.35);
  c.draw(SDF.circle(770, 250, 78), [255, 250, 232]);
  // two-facet peaks, aerial perspective (same idea as the in-game backdrop)
  const peak = (x, base, w, h, col) => {
    const lit = mix(col, [255, 255, 255], 0.16), dark = mix(col, [20, 30, 60], 0.12);
    c.draw(SDF.poly([[x - w, base], [x, base - h], [x, base]]), lit);
    c.draw(SDF.poly([[x, base], [x, base - h], [x + w, base]]), dark);
    const sy = base - h * 0.62;
    c.draw(SDF.poly([[x - w * 0.38, sy], [x, base - h], [x + w * 0.38, sy]]), [244, 248, 255]);
  };
  const farC = mix(hex("#7DBF9A"), hex("#8ED2FF"), 0.55), midC = mix(hex("#7DBF9A"), hex("#8ED2FF"), 0.3);
  peak(180, 640, 300, 360, farC);
  peak(620, 640, 340, 420, farC);
  peak(980, 640, 260, 300, farC);
  peak(400, 660, 260, 270, midC);
  peak(860, 660, 240, 230, midC);
  // forest strip
  const forest = hex("#3F7A62");
  for (let x = -20; x < BIG + 40; x += 38) {
    const h = 70 + ((x * 37) % 50);
    c.draw(SDF.poly([[x - 26, 690], [x + 26, 690], [x, 690 - h]]), forest);
  }
  c.draw(SDF.rect(BIG / 2, 720, BIG / 2 + 10, 32), forest);
  // water in the gap
  c.draw(SDF.rect(BIG / 2, 900, BIG / 2, 160), hex("#2C7FD0"));
  c.draw(SDF.rect(BIG / 2, 770, BIG / 2, 24), hex("#5CB6F8"));
  // grassy banks (dirt body + grass slab with a lighter lip)
  for (const s of [-1, 1]) {
    const cx = s < 0 ? 110 : BIG - 110;
    c.draw(SDF.rect(cx, 900, 180, 240), hex("#8A5E3C"));
    c.draw(SDF.rect(cx, 690, 180, 30, 6), hex("#58C26A"));
    c.draw(SDF.rect(cx, 668, 180, 10, 6), hex("#86DB8E"));
  }
  return c;
}

function scene3d(w, h) {
  const road = ic.model("beam_road"), wood = ic.model("beam_wood"), joint = ic.model("node_joint");
  const parts = [];
  const span = 5;
  for (let i = 0; i < span; i++) parts.push({ mesh: road, t: [-span / 2 + 0.5 + i, 0, 0], layer: "bridge" });
  // wooden truss under the deck: a shallow W
  const nodes = [[-2.5, 0], [-1.25, -0.95], [0, 0], [1.25, -0.95], [2.5, 0]];
  for (let i = 0; i < nodes.length - 1; i++) {
    const [x0, y0] = nodes[i], [x1, y1] = nodes[i + 1];
    const len = Math.hypot(x1 - x0, y1 - y0);
    parts.push({ mesh: wood, t: [(x0 + x1) / 2, (y0 + y1) / 2, 0], s: [len, 1, 1], rz: Math.atan2(y1 - y0, x1 - x0), layer: "bridge" });
  }
  parts.push({ mesh: wood, t: [0, -0.95, 0], s: [2.5, 1, 1], layer: "bridge" });
  for (const [x, y] of nodes) parts.push({ mesh: joint, t: [x, y, 0], layer: "bridge" });
  
  // the truck rolling across
  const tx = 0.35, wheelY = 0.15 + 0.5;
  parts.push({ mesh: ic.model("veh_truck"), t: [tx, wheelY + 0.62, 0], layer: "truck" });
  // bodywork lives in its own neutral model (tools/vox/pipeline.js PAINT): give it the factory yellow
  const yellow = [1.0, 0.788, 0.235].map((c) => c / (218 / 255));
  parts.push({ mesh: ic.model("veh_truck_paint"), t: [tx, wheelY + 0.62, 0], layer: "truck", tint: yellow });
  for (const x of [-1.55, -0.5, 1.45]) parts.push({ mesh: ic.model("wheel_truck"), t: [tx + x, wheelY, 0], layer: "truck" });
  const r = ic.render(parts, { w, h, outline: 7, pad: 0, yaw: -0.38, pitch: 0.16, ss: 3 });
  return ic.compose([r.layers.bridge, r.layers.truck]);
}

function roundMask(im, radius) {
  const { w, h, data } = im;
  const sdf = SDF.rect(w / 2, h / 2, w / 2, h / 2, radius);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const cov = Math.max(0, Math.min(1, 0.5 - sdf(x + 0.5, y + 0.5)));
      const i = (y * w + x) * 4;
      data[i + 3] = Math.round(data[i + 3] * cov);
    }
  }
}

function downsample(im, size) {
  const k = im.w / size;
  const out = Buffer.alloc(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const x0 = Math.floor(x * k), x1 = Math.max(x0 + 1, Math.floor((x + 1) * k));
      const y0 = Math.floor(y * k), y1 = Math.max(y0 + 1, Math.floor((y + 1) * k));
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let yy = y0; yy < y1; yy++) {
        for (let xx = x0; xx < x1; xx++) {
          const i = (yy * im.w + xx) * 4;
          const al = im.data[i + 3];
          r += im.data[i] * al; g += im.data[i + 1] * al; b += im.data[i + 2] * al; a += al; n++;
        }
      }
      const o = (y * size + x) * 4;
      if (a > 0) { out[o] = Math.round(r / a); out[o + 1] = Math.round(g / a); out[o + 2] = Math.round(b / a); }
      out[o + 3] = Math.round(a / n);
    }
  }
  return { w: size, h: size, data: out };
}

function drawIcon() {
  const bg = background();
  const fg = scene3d(940, 600);
  const out = { w: BIG, h: BIG, data: Buffer.from(bg.data) };
  // place the bridge so the deck spans the gap between the banks
  const ox = Math.round((BIG - fg.w) / 2), oy = 318;
  for (let y = 0; y < fg.h; y++) {
    for (let x = 0; x < fg.w; x++) {
      const s = (y * fg.w + x) * 4, d = ((oy + y) * BIG + ox + x) * 4;
      if (oy + y >= BIG) continue;
      const a = fg.data[s + 3] / 255;
      if (a <= 0) continue;
      for (let k = 0; k < 3; k++) out.data[d + k] = Math.round(fg.data[s + k] * a + out.data[d + k] * (1 - a));
    }
  }
  roundMask(out, 190);
  return out;
}

const SIZES = [36, 48, 72, 76, 96, 120, 144, 152, 167, 180, 192, 512, 1024];

function generate(root) {
  const big = drawIcon();
  const out = [];
  for (const size of SIZES) {
    const file = path.join(root, "assets/icons", "icon_" + size + ".png");
    const im = size === BIG ? big : downsample(big, size);
    png.write(file, im.w, im.h, im.data);
    out.push(file);
  }
  return out;
}

module.exports = { generate, drawIcon };

if (require.main === module) {
  const root = path.resolve(__dirname, "..", "..");
  const files = generate(root);
  console.log("icons:", files.length);
}
