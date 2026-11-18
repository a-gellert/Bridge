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
const ALPHA = new Set(["water", "water_top", "water_wave", "grid_dots", "zone", "portal_glow", "shadow", "bg_mountains"]);
const UNLIT = new Set(["sky_band", "bg_sky"]);

const TEXTURES = {
  bg_sky: path.join(ROOT, "assets/images/backgrounds/bg_parallax_1_sky.png"),
  bg_mountains: path.join(ROOT, "assets/images/backgrounds/bg_parallax_2_mountains.png"),
};
const texCache = {};
function getTexture(m) {
  if (texCache[m] !== undefined) return texCache[m];
  if (!TEXTURES[m] || !fs.existsSync(TEXTURES[m])) return (texCache[m] = null);
  try {
    return (texCache[m] = png.decode(TEXTURES[m]));
  } catch (e) {
    console.error("Failed to decode texture", TEXTURES[m], e);
    return (texCache[m] = null);
  }
}

const NAMES = Object.keys(COLORS);
const RGB = NAMES.map((n) => png.hex(COLORS[n]).map((v) => v / 255));
const meshCache = {};
function readModel(name) {
  const gltf = path.join(ROOT, "assets/models", name + ".gltf");
  if (fs.existsSync(gltf)) {
    const g = JSON.parse(fs.readFileSync(gltf, "utf8"));
    return { g, bin: Buffer.from(g.buffers[0].uri.split(",")[1], "base64") };
  }
  // Blender-authored self-contained GLB (JSON chunk + BIN chunk)
  const glb = fs.readFileSync(path.join(ROOT, "assets/models", name + ".glb"));
  const jsonLen = glb.readUInt32LE(12);
  const g = JSON.parse(glb.subarray(20, 20 + jsonLen).toString());
  const binStart = 20 + jsonLen + 8; // skip BIN chunk header
  return { g, bin: glb.subarray(binStart) };
}
function mesh(name) {
  if (meshCache[name]) return meshCache[name];
  const { g, bin } = readModel(name);
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
  return (meshCache[name] = { pos, nrm, uv, idx, col });
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
  const tex = getTexture(o.m);
  const vp = (p) => mul4(scene.proj, mul4(scene.view, [p[0], p[1], p[2], 1]));
  const n = m.pos.length / 3;
  const sp = new Array(n), wn = new Array(n);
  for (let i = 0; i < n; i++) {
    const lp = [m.pos[i * 3] * o.s[0], m.pos[i * 3 + 1] * o.s[1], m.pos[i * 3 + 2] * o.s[2]];
    const r = rotq(o.q, lp);
    const c = vp([r[0] + o.p[0], r[1] + o.p[1], r[2] + o.p[2]]);
    sp[i] = c[3] > 0.01 ? [((c[0] / c[3]) * 0.5 + 0.5) * W, (1 - ((c[1] / c[3]) * 0.5 + 0.5)) * H, c[2] / c[3], 1.0 / c[3]] : null;
    const nn = rotq(o.q, [m.nrm[i * 3] / o.s[0], m.nrm[i * 3 + 1] / o.s[1], m.nrm[i * 3 + 2] / o.s[2]]);
    const l = Math.hypot(...nn) || 1;
    wn[i] = nn.map((v) => v / l);
  }
  for (let t = 0; t < m.idx.length; t += 3) {
    const ia = m.idx[t], ib = m.idx[t + 1], ic = m.idx[t + 2];
    const a = sp[ia], b = sp[ib], c = sp[ic];
    if (!a || !b || !c) continue;
    const area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    if (!alpha && area >= 0) continue; // back face (screen y is flipped)
    const vi = ia;
    const nrm = wn[vi], base = m.col[vi];
    const ndl = Math.max(0, nrm[0] * L[0] + nrm[1] * L[1] + nrm[2] * L[2]);
    let rgb;
    if (UNLIT.has(o.m)) {
      rgb = base.map((v, k) => v * o.t[k]);
    } else {
      // must match assets/materials/voxel.fp
      const sky = [0.72, 0.84, 1.0], sun = [1.0, 0.96, 0.88], bounce = [0.85, 0.78, 0.68];
      const hemi = 0.5 + 0.5 * nrm[1];
      const amb = 0.34 + 0.2 * hemi;
      const dif = 0.55 * ndl;
      const bou = 0.08 * Math.max(0, -nrm[1]);
      const rim = Math.pow(1 - Math.max(0, nrm[2]), 3) * 0.05;
      rgb = base.map((v, k) => v * o.t[k] * (sky[k] * (amb + rim) + sun[k] * dif + bounce[k] * bou));
      if (o.o[3] > 0) rgb = rgb.map((v, k) => v * (1 - o.o[3]) + o.o[k] * (0.55 + ndl * 0.55) * o.o[3]);
    }
    const al = alpha ? o.t[3] : 1;
    const minx = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0]))), maxx = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0], c[0])));
    const miny = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1]))), maxy = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1], c[1])));
    if (!tex && (maxx - minx > W * 3 || maxy - miny > H * 3)) continue;
    const uva = [m.uv[ia * 2], m.uv[ia * 2 + 1]];
    const uvb = [m.uv[ib * 2], m.uv[ib * 2 + 1]];
    const uvc = [m.uv[ic * 2], m.uv[ic * 2 + 1]];
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
        if (tex) {
          const invWa = a[3], invWb = b[3], invWc = c[3];
          const invW = w0 * invWa + w1 * invWb + w2 * invWc;
          const u = Math.max(0, Math.min(0.9999, (w0 * uva[0] * invWa + w1 * uvb[0] * invWb + w2 * uvc[0] * invWc) / invW));
          const v = Math.max(0, Math.min(0.9999, (w0 * uva[1] * invWa + w1 * uvb[1] * invWb + w2 * uvc[1] * invWc) / invW));
          const tx = Math.floor(u * tex.w), ty = Math.floor(v * tex.h);
          const tIdx = (ty * tex.w + tx) * 4;
          const texAlpha = (tex.data[tIdx + 3] / 255) * al;
          if (texAlpha <= 0.02) continue;
          const tr = (tex.data[tIdx] / 255) * o.t[0];
          const tg = (tex.data[tIdx + 1] / 255) * o.t[1];
          const tb = (tex.data[tIdx + 2] / 255) * o.t[2];
          if (!alpha) {
            depth[k] = z;
            color[k * 3] = tr; color[k * 3 + 1] = tg; color[k * 3 + 2] = tb;
          } else {
            color[k * 3] = color[k * 3] * (1 - texAlpha) + tr * texAlpha;
            color[k * 3 + 1] = color[k * 3 + 1] * (1 - texAlpha) + tg * texAlpha;
            color[k * 3 + 2] = color[k * 3 + 2] * (1 - texAlpha) + tb * texAlpha;
          }
          continue;
        }
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

const sky = scene.objects.filter((o) => UNLIT.has(o.m));
const opaque = scene.objects.filter((o) => !ALPHA.has(o.m) && !UNLIT.has(o.m));
const trans = scene.objects.filter((o) => ALPHA.has(o.m)).sort((a, b) => a.p[2] - b.p[2]);
for (const o of sky) drawObject(o, false);
for (const o of opaque) drawObject(o, false);
for (const o of trans) drawObject(o, true);
const buf = Buffer.alloc(W * H * 4);
for (let i = 0; i < W * H; i++) {
  for (let k = 0; k < 3; k++) buf[i * 4 + k] = Math.max(0, Math.min(255, Math.round(Math.pow(color[i * 3 + k], 1) * 255)));
  buf[i * 4 + 3] = 255;
}
png.write(OUT, W, H, buf);
console.log("preview", OUT, W + "x" + H, scene.objects.length, "objects");
