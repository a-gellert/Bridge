// Software renderer for coloured UI icons built from the game's own models.
// Same palette texture and the same lighting formula as assets/materials/voxel.fp, so a HUD icon
// always looks like the object the player sees in the world. Output is an RGBA image with a dark
// ink outline (the colour of the GUI text outline) and 4x4 supersampled edges.
//
//   const r = render(parts, { w: 128, h: 88, yaw: -0.42, pitch: 0.24, outline: 3 });
//   r.layers.body -> { w, h, data }   (one image per part layer, occlusion-correct)
//   compose([r.layers.body, r.layers.wheel]) -> one flattened image
const fs = require("fs");
const path = require("path");
const png = require("./png");
const { COLORS } = require("./palette");

const ROOT = path.resolve(__dirname, "../..");
const NAMES = Object.keys(COLORS);
const RGB = NAMES.map((n) => png.hex(COLORS[n]).map((v) => v / 255));
const INK = [0x1b, 0x20, 0x30];

// world-space key light of voxel.material
const L = (() => {
  const l = [0.45, 0.8, 0.55];
  const n = Math.hypot(...l);
  return l.map((v) => v / n);
})();

// ------------------------------------------------------------------ meshes
const cache = {};

// assets/models/<id>.gltf (embedded buffer) or .glb (Blender export) -> { pos, nrm, uv, idx }
function model(id) {
  if (cache[id]) return cache[id];
  const gltf = path.join(ROOT, "assets/models", id + ".gltf");
  // load the mesh the game loads: entities/<id>.go decides between .gltf and .glb
  const ent = path.join(ROOT, "entities", id + ".go");
  const wantsGlb = fs.existsSync(ent) && fs.readFileSync(ent, "utf8").includes(id + ".glb");
  let g, bin;
  if (!wantsGlb && fs.existsSync(gltf)) {
    g = JSON.parse(fs.readFileSync(gltf, "utf8"));
    bin = Buffer.from(g.buffers[0].uri.split(",")[1], "base64");
  } else {
    const glb = fs.readFileSync(path.join(ROOT, "assets/models", id + ".glb"));
    const jsonLen = glb.readUInt32LE(12);
    g = JSON.parse(glb.subarray(20, 20 + jsonLen).toString());
    bin = glb.subarray(20 + jsonLen + 8);
  }
  const acc = (i, Ctor, comps) => {
    const a = g.accessors[i];
    const v = g.bufferViews[a.bufferView];
    const start = bin.byteOffset + (v.byteOffset || 0) + (a.byteOffset || 0);
    return new Ctor(bin.buffer.slice(start, start + a.count * comps * Ctor.BYTES_PER_ELEMENT));
  };
  const pos = [], nrm = [], uv = [], idx = [];
  for (const mesh of g.meshes) {
    for (const prim of mesh.primitives) {
      const base = pos.length / 3;
      const p = acc(prim.attributes.POSITION, Float32Array, 3);
      const n = acc(prim.attributes.NORMAL, Float32Array, 3);
      const t = acc(prim.attributes.TEXCOORD_0, Float32Array, 2);
      const ia = g.accessors[prim.indices];
      const ix = acc(prim.indices, ia.componentType === 5125 ? Uint32Array : Uint16Array, 1);
      for (const v of p) pos.push(v);
      for (const v of n) nrm.push(v);
      for (const v of t) uv.push(v);
      for (const v of ix) idx.push(v + base);
    }
  }
  return (cache[id] = { pos, nrm, uv, idx });
}

// tools/gen/mesh.js Mesh -> same shape (used for icon-only props like the eraser)
function fromMesh(m) {
  return { pos: m.pos, nrm: m.nrm, uv: m.uvs, idx: m.idx };
}

function colorAt(u, v) {
  const c = Math.floor(u * 16), r = Math.floor(v * 16);
  return RGB[r * 16 + c] || [1, 0, 1];
}

// lighting of voxel.fp for a world-space normal
function shade(n) {
  const ndl = Math.max(0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2]);
  const hemi = 0.5 + 0.5 * n[1];
  const amb = 0.34 + 0.2 * hemi;
  const bou = 0.08 * Math.max(0, -n[1]);
  const rim = Math.pow(1 - Math.max(0, n[2]), 3) * 0.05;
  const sky = [0.72, 0.84, 1.0], sun = [1.0, 0.96, 0.88], bounce = [0.85, 0.78, 0.68];
  return [0, 1, 2].map((k) => sky[k] * (amb + rim) + sun[k] * ndl * 0.55 + bounce[k] * bou);
}

// ------------------------------------------------------------------ rendering
// part: { mesh, layer = "main", t = [x, y, z], s = number | [sx, sy, sz], rz = 0 (radians), tint = [r, g, b] }
// opts: w, h, yaw, pitch (radians), pad (px), outline (px), ss (supersampling), exposure,
//       fit (parts used only for framing, so several renders share one frame), layers (names to output),
//       bg (function(x, y) -> [r, g, b, a] in 0..1, drawn behind everything, no outline around it)
function render(parts, o) {
  const ss = o.ss || 4;
  const W = o.w * ss, H = o.h * ss;
  const yaw = o.yaw === undefined ? -0.42 : o.yaw;
  const pitch = o.pitch === undefined ? 0.24 : o.pitch;
  const cy = Math.cos(yaw), sy = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
  const exposure = o.exposure || 1.1;

  // model -> world (part transform), world -> view (yaw around y, then pitch around x)
  const toWorld = (part, x, y, z) => {
    const s = part.s === undefined ? [1, 1, 1] : typeof part.s === "number" ? [part.s, part.s, part.s] : part.s;
    const t = part.t || [0, 0, 0];
    const rz = part.rz || 0;
    const ax = x * s[0], ay = y * s[1], az = z * s[2];
    const c = Math.cos(rz), d = Math.sin(rz);
    return [ax * c - ay * d + t[0], ax * d + ay * c + t[1], az + t[2]];
  };
  const toView = (p) => {
    const x1 = p[0] * cy + p[2] * sy, z1 = -p[0] * sy + p[2] * cy;
    const y2 = p[1] * cp - z1 * sp, z2 = p[1] * sp + z1 * cp;
    return [x1, y2, z2];
  };

  // framing
  const fit = o.fit || parts;
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const part of fit) {
    const m = part.mesh;
    // only vertices used by triangles (a filtered mesh keeps its full vertex array)
    for (const vi of m.idx) {
      const i = vi * 3;
      const v = toView(toWorld(part, m.pos[i], m.pos[i + 1], m.pos[i + 2]));
      if (v[0] < x0) x0 = v[0];
      if (v[0] > x1) x1 = v[0];
      if (v[1] < y0) y0 = v[1];
      if (v[1] > y1) y1 = v[1];
    }
  }
  const pad = (o.pad === undefined ? 4 : o.pad) * ss + (o.outline || 0) * ss;
  const k = Math.min((W - 2 * pad) / (x1 - x0), (H - 2 * pad) / (y1 - y0));
  const ox = W / 2 - ((x0 + x1) / 2) * k;
  const oy = H / 2 + ((y0 + y1) / 2) * k + (o.shiftY || 0) * ss;

  const depth = new Float32Array(W * H).fill(-Infinity);
  const color = new Float32Array(W * H * 3);
  const layerOf = new Int16Array(W * H).fill(-1);
  const layerNames = [];

  for (const part of parts) {
    const name = part.layer || "main";
    let li = layerNames.indexOf(name);
    if (li < 0) li = layerNames.push(name) - 1;
    const m = part.mesh;
    const tint = part.tint || [1, 1, 1];
    const s = part.s === undefined ? [1, 1, 1] : typeof part.s === "number" ? [part.s, part.s, part.s] : part.s;
    const rz = part.rz || 0;
    const c = Math.cos(rz), d = Math.sin(rz);
    const n = m.pos.length / 3;
    const sp2 = new Array(n);
    for (let i = 0; i < n; i++) {
      const v = toView(toWorld(part, m.pos[i * 3], m.pos[i * 3 + 1], m.pos[i * 3 + 2]));
      sp2[i] = [ox + v[0] * k, oy - v[1] * k, v[2]];
    }
    for (let t = 0; t < m.idx.length; t += 3) {
      const ia = m.idx[t], ib = m.idx[t + 1], ic = m.idx[t + 2];
      const a = sp2[ia], b = sp2[ib], cc = sp2[ic];
      const area = (b[0] - a[0]) * (cc[1] - a[1]) - (b[1] - a[1]) * (cc[0] - a[0]);
      if (area >= 0) continue; // back face (screen y points down)
      // world normal: inverse scale, then the part's z rotation
      let nx = m.nrm[ia * 3] / s[0], ny = m.nrm[ia * 3 + 1] / s[1], nz = m.nrm[ia * 3 + 2] / s[2];
      const rx = nx * c - ny * d, ry = nx * d + ny * c;
      const nl = Math.hypot(rx, ry, nz) || 1;
      const lit = shade([rx / nl, ry / nl, nz / nl]);
      const base = colorAt(m.uv[ia * 2], m.uv[ia * 2 + 1]);
      const rgb = [0, 1, 2].map((q) => Math.min(1, base[q] * tint[q] * lit[q] * exposure));
      const minx = Math.max(0, Math.floor(Math.min(a[0], b[0], cc[0])));
      const maxx = Math.min(W - 1, Math.ceil(Math.max(a[0], b[0], cc[0])));
      const miny = Math.max(0, Math.floor(Math.min(a[1], b[1], cc[1])));
      const maxy = Math.min(H - 1, Math.ceil(Math.max(a[1], b[1], cc[1])));
      for (let y = miny; y <= maxy; y++) {
        for (let x = minx; x <= maxx; x++) {
          const px = x + 0.5, py = y + 0.5;
          const w0 = ((b[0] - px) * (cc[1] - py) - (b[1] - py) * (cc[0] - px)) / area;
          const w1 = ((cc[0] - px) * (a[1] - py) - (cc[1] - py) * (a[0] - px)) / area;
          const w2 = 1 - w0 - w1;
          if (w0 < 0 || w1 < 0 || w2 < 0) continue;
          const z = w0 * a[2] + w1 * b[2] + w2 * cc[2];
          const pi = y * W + x;
          if (z <= depth[pi]) continue;
          depth[pi] = z;
          layerOf[pi] = li;
          color[pi * 3] = rgb[0];
          color[pi * 3 + 1] = rgb[1];
          color[pi * 3 + 2] = rgb[2];
        }
      }
    }
  }

  // one output image per layer: visible pixels of that layer + an ink ring around them.
  // o.silhouettes = { name: [layer, ...] } adds ink-only images of the union of those layers
  // (drawn under them, so neighbouring layers share one outer outline and no seam outline).
  const R = Math.round((o.outline || 0) * ss);
  const disk = [];
  for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++) if (dx * dx + dy * dy <= R * R + R) disk.push([dx, dy]);
  const wanted = o.layers || layerNames;
  const sil = o.silhouettes || {};
  const noOutline = new Set(o.noOutline || []);
  const layers = {};
  for (const name of [...wanted, ...Object.keys(sil)]) {
    const isSil = !!sil[name];
    const ids = isSil ? sil[name].map((n) => layerNames.indexOf(n)) : [layerNames.indexOf(name)];
    const mask = new Uint8Array(W * H);
    for (let i = 0; i < W * H; i++) if (ids.includes(layerOf[i]) && layerOf[i] >= 0) mask[i] = 1;
    let ring = mask;
    if (R > 0 && !noOutline.has(name)) {
      ring = new Uint8Array(mask);
      for (let y = 0; y < H; y++) {
        for (let x = 0; x < W; x++) {
          const i = y * W + x;
          if (!mask[i]) continue;
          // only edge pixels stamp the disk
          if (x > 0 && x < W - 1 && y > 0 && y < H - 1 && mask[i - 1] && mask[i + 1] && mask[i - W] && mask[i + W]) continue;
          for (const [dx, dy] of disk) {
            const xx = x + dx, yy = y + dy;
            if (xx >= 0 && yy >= 0 && xx < W && yy < H) ring[yy * W + xx] = 1;
          }
        }
      }
    }
    const out = Buffer.alloc(o.w * o.h * 4);
    const n2 = ss * ss;
    for (let ty = 0; ty < o.h; ty++) {
      for (let tx = 0; tx < o.w; tx++) {
        let cov = 0, ink = 0, r = 0, g = 0, b = 0;
        for (let sy2 = 0; sy2 < ss; sy2++) {
          for (let sx2 = 0; sx2 < ss; sx2++) {
            const i = (ty * ss + sy2) * W + tx * ss + sx2;
            if (mask[i] && !isSil) {
              cov++;
              r += color[i * 3]; g += color[i * 3 + 1]; b += color[i * 3 + 2];
            }
            if (ring[i]) ink++;
          }
        }
        const al = cov / n2, ao = ink / n2;
        const A = al + ao * (1 - al);
        if (A <= 0) continue;
        const q = (ty * o.w + tx) * 4;
        const lr = cov ? r / cov : 0, lg = cov ? g / cov : 0, lb = cov ? b / cov : 0;
        out[q] = Math.round(((lr * 255) * al + INK[0] * ao * (1 - al)) / A);
        out[q + 1] = Math.round(((lg * 255) * al + INK[1] * ao * (1 - al)) / A);
        out[q + 2] = Math.round(((lb * 255) * al + INK[2] * ao * (1 - al)) / A);
        out[q + 3] = Math.round(A * 255);
      }
    }
    layers[name] = { w: o.w, h: o.h, data: out };
  }
  return { layers, names: layerNames };
}

// Alpha-composite images of the same size (first = bottom).
function compose(images, bg) {
  const { w, h } = images[0];
  const out = Buffer.alloc(w * h * 4);
  if (bg) bg.data.copy(out);
  for (const im of images) {
    const d = im.data;
    for (let i = 0; i < w * h; i++) {
      const sa = d[i * 4 + 3] / 255;
      if (sa <= 0) continue;
      const da = out[i * 4 + 3] / 255;
      const A = sa + da * (1 - sa);
      for (let k = 0; k < 3; k++) {
        out[i * 4 + k] = Math.round((d[i * 4 + k] * sa + out[i * 4 + k] * da * (1 - sa)) / A);
      }
      out[i * 4 + 3] = Math.round(A * 255);
    }
  }
  return { w, h, data: out };
}

function save(file, im) {
  png.write(file, im.w, im.h, im.data);
}

module.exports = { model, fromMesh, render, compose, save, INK };
