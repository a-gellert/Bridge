// .vox <-> game asset pipeline.
//   assets/vox/<id>.vox   MagicaVoxel source of truth (editable in MagicaVoxel)
//   assets/vox/<id>.json  grid transform: voxel size + origin in game space
//   assets/models/<id>.gltf  generated mesh with palette UVs (same material as before)
const fs = require("fs");
const path = require("path");
const vox = require("./vox");
const { voxelize, EMPTY } = require("./voxelize");
const { voxelsToMesh } = require("./gltf");
const { COLORS } = require("../gen/palette");
const png = require("../gen/png");

const NAMES = Object.keys(COLORS);
const RGB = NAMES.map((n) => png.hex(COLORS[n]));

function palette256() {
  const out = [];
  for (let i = 0; i < 256; i++) {
    const c = RGB[i];
    out.push(c ? [c[0], c[1], c[2], 255] : [255, 0, 255, 255]);
  }
  return out;
}

function voxPath(root, id) {
  return path.join(root, "assets/vox", id + ".vox");
}
function metaPath(root, id) {
  return path.join(root, "assets/vox", id + ".json");
}
function gltfPath(root, id) {
  return path.join(root, "assets/models", id + ".gltf");
}

function nearestPaletteIndex(rgb) {
  let best = 0, bestD = Infinity;
  for (let i = 0; i < RGB.length; i++) {
    const d = (RGB[i][0] - rgb[0]) ** 2 + (RGB[i][1] - rgb[1]) ** 2 + (RGB[i][2] - rgb[2]) ** 2;
    if (d < bestD) { bestD = d; best = i; }
  }
  return best;
}

// Voxel grid (game space) -> .vox + sidecar. Axis mapping: vx=gx, vy=dimZ-1-gz, vz=gy.
function writeVoxFromGrid(root, id, volume) {
  const { dims, cell, step, origin, grid } = volume;
  const [nx, ny, nz] = dims;
  const size = [nx, nz, ny];
  const list = [];
  for (let gz = 0; gz < nz; gz++) {
    for (let gy = 0; gy < ny; gy++) {
      for (let gx = 0; gx < nx; gx++) {
        const c = grid[gx + nx * (gy + ny * gz)];
        if (c < 0) continue;
        list.push({ x: gx, y: nz - 1 - gz, z: gy, c: c + 1 });
      }
    }
  }
  fs.mkdirSync(path.dirname(voxPath(root, id)), { recursive: true });
  vox.writeFile(voxPath(root, id), { size, voxels: list, palette: palette256() });
  fs.writeFileSync(
    metaPath(root, id),
    JSON.stringify({ cell, step, origin, voxels: list.length, generator: "tools/vox/build.js" }, null, 1),
    "utf8",
  );
  return { voxels: list.length, size };
}

// .vox + sidecar -> voxel grid (game space)
function readVoxGrid(root, id) {
  const meta = JSON.parse(fs.readFileSync(metaPath(root, id), "utf8"));
  const file = vox.readFile(voxPath(root, id));
  const [sx, sy, sz] = file.size; // vox: x, y (depth), z (up)
  const dims = [sx, sz, sy]; // game: x, y, z
  const grid = new Int16Array(dims[0] * dims[1] * dims[2]).fill(EMPTY);
  const remap = new Map();
  for (const v of file.voxels) {
    let c = v.c - 1;
    if (c < 0 || c >= NAMES.length) {
      if (!remap.has(v.c)) {
        const rgba = file.palette[(v.c - 1) & 255];
        remap.set(v.c, nearestPaletteIndex(rgba));
      }
      c = remap.get(v.c);
    }
    const gx = v.x, gy = v.z, gz = sy - 1 - v.y;
    if (gx >= dims[0] || gy >= dims[1] || gz >= dims[2]) continue;
    grid[gx + dims[0] * (gy + dims[1] * gz)] = c;
  }
  return { dims, cell: meta.cell, step: meta.step || [meta.cell, meta.cell, meta.cell], origin: meta.origin, grid };
}

// Paintable vehicles: the body colour voxels go to a separate <id>_paint model in neutral greys
// (main -> base, light -> white, dark -> base_dk) that the game tints with the garage paint, so a
// paint job recolours only the bodywork, never tyres, glass, chrome or the cargo box.
const PAINT = {
  veh_moto: ["moto", "moto_lt", "moto_dk"],
  veh_car: ["car", "car_lt", "car_dk"],
  veh_truck: ["truck", "truck_lt", "truck_dk"],
};
const NEUTRAL = ["base", "white", "base_dk"];
const INTERIOR = -3; // blocks faces like a solid voxel but draws nothing (see tools/vox/gltf.js)

function splitPaint(volume, names) {
  const remap = new Map(names.map((n, i) => [NAMES.indexOf(n), NAMES.indexOf(NEUTRAL[i])]));
  const body = new Int16Array(volume.grid), paint = new Int16Array(volume.grid);
  for (let i = 0; i < volume.grid.length; i++) {
    const c = volume.grid[i];
    if (c < 0) continue;
    if (remap.has(c)) { body[i] = INTERIOR; paint[i] = remap.get(c); }
    else paint[i] = INTERIOR;
  }
  return [{ ...volume, grid: body }, { ...volume, grid: paint }];
}

// .vox -> assets/models/<id>.gltf (+ <id>_paint.gltf for paintable vehicles)
function buildGltf(root, id) {
  const volume = readVoxGrid(root, id);
  let info;
  if (PAINT[id]) {
    const [body, paint] = splitPaint(volume, PAINT[id]);
    info = voxelsToMesh(body).writeGltf(gltfPath(root, id), id);
    info.tris += voxelsToMesh(paint).writeGltf(gltfPath(root, id + "_paint"), id + "_paint").tris;
  } else {
    info = voxelsToMesh(volume).writeGltf(gltfPath(root, id), id);
  }
  let solid = 0;
  for (let i = 0; i < volume.grid.length; i++) if (volume.grid[i] >= 0) solid++;
  return { tris: info.tris, voxels: solid, dims: volume.dims, cell: volume.cell };
}

// Blender export assets/models/<id>.glb -> mesh-like { pos, uvs, idx } in game space (palette UVs).
function readGlb(root, id) {
  const glb = fs.readFileSync(path.join(root, "assets/models", id + ".glb"));
  const jsonLen = glb.readUInt32LE(12);
  const g = JSON.parse(glb.subarray(20, 20 + jsonLen).toString());
  const bin = glb.subarray(20 + jsonLen + 8);
  const acc = (i, Ctor, comps) => {
    const a = g.accessors[i];
    const v = g.bufferViews[a.bufferView];
    // only tightly packed float attributes are supported (what tools/blender/gen_models.py exports)
    if (v.byteStride || (Ctor === Float32Array && a.componentType !== 5126)) {
      throw new Error(`readGlb(${id}): interleaved or quantized accessor ${i} is not supported`);
    }
    const start = bin.byteOffset + (v.byteOffset || 0) + (a.byteOffset || 0);
    return new Ctor(bin.buffer.slice(start, start + a.count * comps * Ctor.BYTES_PER_ELEMENT));
  };
  for (const n of g.nodes || []) {
    if (n.matrix || n.scale || n.rotation || n.translation) {
      throw new Error(`readGlb(${id}): node transforms are not applied; export with transforms applied`);
    }
  }
  const pos = [], nrm = [], uvs = [], idx = [];
  for (const mesh of g.meshes) {
    for (const prim of mesh.primitives) {
      const base = pos.length / 3;
      for (const v of acc(prim.attributes.POSITION, Float32Array, 3)) pos.push(v);
      for (const v of acc(prim.attributes.NORMAL, Float32Array, 3)) nrm.push(v);
      for (const v of acc(prim.attributes.TEXCOORD_0, Float32Array, 2)) uvs.push(v);
      if (prim.indices === undefined) throw new Error(`readGlb(${id}): non-indexed primitives are not supported`);
      const ia = g.accessors[prim.indices];
      for (const v of acc(prim.indices, ia.componentType === 5125 ? Uint32Array : Uint16Array, 1)) idx.push(v + base);
    }
  }
  return { pos, nrm, uvs, idx };
}

// mesh -> .vox (and the sidecar), then .gltf
function buildFromMesh(root, id, mesh, opts = {}) {
  const volume = voxelize(mesh, opts);
  const written = writeVoxFromGrid(root, id, volume);
  const info = buildGltf(root, id);
  return { ...info, written };
}

const PAINT_IDS = Object.keys(PAINT).map((id) => id + "_paint");

// Same split for a procedural mesh (gen_assets --no-vox): triangles are routed by palette colour.
function splitMeshPaint(mesh, id) {
  const { Mesh } = require("../gen/mesh");
  const { uv } = require("../gen/palette");
  const names = PAINT[id];
  const key = (u, v) => Math.floor(u * 16) + Math.floor(v * 16) * 16;
  const remap = new Map(names.map((n, i) => {
    const [u, v] = uv(n);
    return [key(u, v), uv(NEUTRAL[i])];
  }));
  const body = new Mesh(), paint = new Mesh();
  for (let t = 0; t < mesh.idx.length; t += 3) {
    const ia = mesh.idx[t];
    const k = key(mesh.uvs[ia * 2], mesh.uvs[ia * 2 + 1]);
    for (let j = 1; j < 3; j++) {
      const i = mesh.idx[t + j];
      if (key(mesh.uvs[i * 2], mesh.uvs[i * 2 + 1]) !== k) throw new Error(`splitMeshPaint(${id}): triangle ${t / 3} mixes palette colours`);
    }
    const to = remap.has(k) ? paint : body;
    const base = to.pos.length / 3;
    for (let j = 0; j < 3; j++) {
      const i = mesh.idx[t + j];
      to.pos.push(mesh.pos[i * 3], mesh.pos[i * 3 + 1], mesh.pos[i * 3 + 2]);
      to.nrm.push(mesh.nrm[i * 3], mesh.nrm[i * 3 + 1], mesh.nrm[i * 3 + 2]);
      const n = remap.get(k);
      to.uvs.push(n ? n[0] : mesh.uvs[i * 2], n ? n[1] : mesh.uvs[i * 2 + 1]);
    }
    to.idx.push(base, base + 1, base + 2);
  }
  return [body, paint];
}

module.exports = {
  voxPath, metaPath, gltfPath, writeVoxFromGrid, readVoxGrid, buildGltf, buildFromMesh, readGlb, splitMeshPaint,
  NAMES, PAINT, PAINT_IDS,
};
