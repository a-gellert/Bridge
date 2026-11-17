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

// .vox -> assets/models/<id>.gltf
function buildGltf(root, id) {
  const volume = readVoxGrid(root, id);
  const mesh = voxelsToMesh(volume);
  const info = mesh.writeGltf(gltfPath(root, id), id);
  let solid = 0;
  for (let i = 0; i < volume.grid.length; i++) if (volume.grid[i] >= 0) solid++;
  return { tris: info.tris, voxels: solid, dims: volume.dims, cell: volume.cell };
}

// mesh -> .vox (and the sidecar), then .gltf
function buildFromMesh(root, id, mesh, opts = {}) {
  const volume = voxelize(mesh, opts);
  const written = writeVoxFromGrid(root, id, volume);
  const info = buildGltf(root, id);
  return { ...info, written };
}

module.exports = { voxPath, metaPath, gltfPath, writeVoxFromGrid, readVoxGrid, buildGltf, buildFromMesh, NAMES };
