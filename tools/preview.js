// Software preview renderer for scenes dumped by tests/dump_scene.lua (no Defold needed).
// Mimics assets/materials/voxel.fp: lambert + sky fill, tint multiply, overlay mix, alpha pass.
//   node tools/preview.js scene.json out.png
const fs = require("fs");
const path = require("path");
const png = require("./gen/png");
const { COLORS } = require("./gen/palette");

const ROOT = path.resolve(__dirname, "..");
const scene = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const OUT = process.argv[3] || "preview.png";
const W = scene.w > 1400 ? Math.round(scene.w / 2) : scene.w;
const H = scene.w > 1400 ? Math.round(scene.h / 2) : scene.h;
const ALPHA = new Set(["water", "grid_dots", "zone", "portal_glow", "shadow"]);

const NAMES = Object.keys(COLORS);
const RGB = NAMES.map((n) => png.hex(COLORS[n]).map((v) => v / 255));
const meshCache = {};
function mesh(name) {
  if (meshCache[name]) return meshCache[name];
  const g = JSON.parse(fs.readFileSync(path.join(ROOT, "assets/models", name + ".gltf"), "utf8"));
  const bin = Buffer.from(g.buffers[0].uri.split(",")[1], "base64");
  const acc = (i, Ctor, comps) => {
    const a = g.accessors[i], v = g.bufferViews[a.bufferView];
    return new Ctor(bin.buffer.slice(bin.byteOffset + v.byteOffset, bin.byteOffset + v.byteOffset + a.count * comps * Ctor.BYTES_PER_ELEMENT));
  };
  const prim = g.meshes[0].primitives[0];
  const pos = acc(prim.attributes.POSITION, Float32Array, 3);
  const nrm = acc(prim.attributes.NORMAL, Float32Array, 3);
  const uv = acc(prim.attributes.TEXCOORD_0, Float32Array, 2);
  const ia = g.accessors[prim.indices];
  const idx = acc(prim.indices, ia.componentType === 5125 ? Uint32Array : Uint16Array, 1);
  const col = [];
  for (let i = 0; i < uv.length / 2; i++) {
    const c = Math.floor(uv[i * 2] * 16), r = Math.floor(uv[i * 2 + 1] * 16);
    col.push(RGB[r * 16 + c] || [1, 0, 1]);
  }
  return (meshCache[name] = { pos, nrm, idx, col });
}

const mul4 = (m, v) => [0, 1, 2, 3].map((r) => m[r * 4] * v[0] + m[r * 4 + 1] * v[1] + m[r * 4 + 2] * v[2] + m[r * 4 + 3] * v[3]);
function rotq(q, v) {
  const [x, y, z, w] = q;
  const ix = w * v[0] + y * v[2] - z * v[1], iy = w * v[1] + z * v[0] - x * v[2];
  const iz = w * v[2] + x * v[1] - y * v[0], iw = -x * v[0] - y * v[1] - z * v[2];
  return [ix * w + iw * -x + iy * -z - iz * -y, iy * w + iw * -y + iz * -x - ix * -z, iz * w + iw * -z + ix * -y - iy * -x];
}

const color = new Float32Array(W * H * 3);
const depth = new Float32Array(W * H).fill(Infinity);
for (let i = 0; i < W * H; i++) color.set(scene.sky, i * 3);
const L = (() => { const l = [0.45, 0.8, 0.55], n = Math.hypot(...l); return l.map((v) => v / n); })();

function drawObject(o, alpha) {
  const m = mesh(o.m);
  const vp = (p) => mul4(scene.proj, mul4(scene.view, [p[0], p[1], p[2], 1]));
  const n = m.pos.length / 3;
  const sp = new Array(n), wn = new Array(n);
  for (let i = 0; i < n; i++) {
    const lp = [m.pos[i * 3] * o.s[0], m.pos[i * 3 + 1] * o.s[1], m.pos[i * 3 + 2] * o.s[2]];
    const r = rotq(o.q, lp);
    const c = vp([r[0] + o.p[0], r[1] + o.p[1], r[2] + o.p[2]]);
    sp[i] = c[3] > 0.01 ? [((c[0] / c[3]) * 0.5 + 0.5) * W, (1 - ((c[1] / c[3]) * 0.5 + 0.5)) * H, c[2] / c[3]] : null;
    const nn = rotq(o.q, [m.nrm[i * 3] / o.s[0], m.nrm[i * 3 + 1] / o.s[1], m.nrm[i * 3 + 2] / o.s[2]]);
    const l = Math.hypot(...nn) || 1;
    wn[i] = nn.map((v) => v / l);
  }
  for (let t = 0; t < m.idx.length; t += 3) {
    const a = sp[m.idx[t]], b = sp[m.idx[t + 1]], c = sp[m.idx[t + 2]];
    if (!a || !b || !c) continue;
    const area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    if (!alpha && area >= 0) continue; // back face (screen y is flipped)
    const vi = m.idx[t];
    const nrm = wn[vi], base = m.col[vi];
    const ndl = Math.max(0, nrm[0] * L[0] + nrm[1] * L[1] + nrm[2] * L[2]);
    const lf = 0.42 + ndl * 0.62 + (0.5 + 0.5 * nrm[1]) * 0.08;
    let rgb = base.map((v, k) => v * o.t[k] * lf);
    if (o.o[3] > 0) rgb = rgb.map((v, k) => v * (1 - o.o[3]) + o.o[k] * (0.55 + ndl * 0.55) * o.o[3]);
    const al = alpha ? o.t[3] : 1;
    const minx = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0]))), maxx = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
    const miny = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1]))), maxy = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
    if (maxx - minx > W * 3 || maxy - miny > H * 3) continue;
    for (let y = miny; y <= maxy; y++) {
      for (let x = minx; x <= maxx; x++) {
        const px = x + 0.5, py = y + 0.5;
        const w0 = ((b[0] - px) * (c[1] - py) - (b[1] - py) * (c[0] - px)) / area;
        const w1 = ((c[0] - px) * (a[1] - py) - (c[1] - py) * (a[0] - px)) / area;
        const w2 = 1 - w0 - w1;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        const z = w0 * a[2] + w1 * b[2] + w2 * c[2];
        const k = y * W + x;
        if (z >= depth[k]) continue;
        if (!alpha) {
          depth[k] = z;
          color[k * 3] = rgb[0]; color[k * 3 + 1] = rgb[1]; color[k * 3 + 2] = rgb[2];
        } else {
          for (let q = 0; q < 3; q++) color[k * 3 + q] = color[k * 3 + q] * (1 - al) + rgb[q] * al;
        }
      }
    }
  }
}

const opaque = scene.objects.filter((o) => !ALPHA.has(o.m));
const trans = scene.objects.filter((o) => ALPHA.has(o.m)).sort((a, b) => a.p[2] - b.p[2]);
const scaleFix = W / scene.w;
for (const o of opaque) drawObject(o, false);
for (const o of trans) drawObject(o, true);
const buf = Buffer.alloc(W * H * 4);
for (let i = 0; i < W * H; i++) {
  for (let k = 0; k < 3; k++) buf[i * 4 + k] = Math.max(0, Math.min(255, Math.round(Math.pow(color[i * 3 + k], 1) * 255)));
  buf[i * 4 + 3] = 255;
}
png.write(OUT, W, H, buf);
console.log("preview", OUT, W + "x" + H, scene.objects.length, "objects");
