// Builds voxel models for Bridge Mad.
//   node tools/vox/build.js                  # every supported procedural model -> assets/vox/*.vox + assets/models/*.gltf
//   node tools/vox/build.js --only=veh_car,wheel_car
//   node tools/vox/build.js --preview        # also render build/vox_previews/<id>.png
//
// Dynamic / stretched helper models (terrain tiles, water, overlays) stay procedural: they are
// scaled or sliced by world/level_view.lua and a voxel grid would be distorted.
const path = require("path");
const fs = require("fs");
const models = require("../gen/models");
const blender = require("../gen/blender_assets");
const pipeline = require("./pipeline");

const ROOT = path.resolve(__dirname, "../..");
const argv = process.argv.slice(2);
const flag = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith("--" + name + "="));
  return hit ? hit.slice(name.length + 3) : dflt;
};
const only = flag("only", null);
const preview = argv.includes("--preview");
const cellScale = Number(flag("cell-scale", "1.15")) || 1.15;
// --magicavoxel[=dir] copies the sources into the MagicaVoxel vox folder so they can be opened there
const mvFlag = argv.find((a) => a === "--magicavoxel" || a.startsWith("--magicavoxel="));
const mvDir = mvFlag ? (mvFlag.includes("=") ? mvFlag.split("=")[1] : "D:/Programs/MagicaVoxel-0.99.7.1-win64/vox/bridgemad") : null;

const SKIP = new Set([
  "terrain_body", "terrain_top", // sliced into 3 m tiles and tinted per theme
  "water", "water_top", "water_wave", // tiled / animated alpha surfaces
  "sky_band", // unlit gradient quad
  "zone", "grid_dots", "select_ring", "shadow", "portal_glow", // build-mode / fx overlays
]);

function bbox(mesh) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < mesh.pos.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      const v = mesh.pos[i + k];
      if (v < min[k]) min[k] = v;
      if (v > max[k]) max[k] = v;
    }
  }
  return { min, max, ext: max.map((v, k) => v - min[k]) };
}

function pickCell(id, ext) {
  const maxExt = Math.max(...ext);
  if (id.startsWith("beam_")) return 0.05;
  if (id.startsWith("wheel_")) return 0.03;
  if (id.startsWith("node_")) return 0.035;
  if (id.startsWith("portal_")) return 0.06;
  if (id.startsWith("flag_")) return 0.06;
  if (id.startsWith("veh_")) return 0.05;
  if (maxExt < 0.7) return 0.02;
  if (maxExt < 1.6) return 0.03;
  if (maxExt < 3.2) return 0.045;
  if (maxExt < 6) return 0.055;
  return 0.07;
}

const ids = Object.keys(models).filter((id) => !SKIP.has(id) && !blender.set.has(id));
const selected = only ? ids.filter((id) => only.split(",").includes(id)) : ids;
let totalTris = 0;
let totalVoxels = 0;
const rows = [];
for (const id of selected) {
  const mesh = models[id]();
  const { ext } = bbox(mesh);
  const cell = pickCell(id, ext) * cellScale;
  const t0 = Date.now();
  const info = pipeline.buildFromMesh(ROOT, id, mesh, { cell });
  totalTris += info.tris;
  totalVoxels += info.voxels;
  rows.push({ id, dims: info.dims.join("x"), voxels: info.voxels, tris: info.tris, ms: Date.now() - t0 });
  console.log(
    `${id.padEnd(16)} ${String(info.dims.join("x")).padEnd(12)} voxels ${String(info.voxels).padStart(6)}` +
      ` tris ${String(info.tris).padStart(5)}  cell ${cell.toFixed(3)}  ${Date.now() - t0}ms`,
  );
}

console.log(`\n${rows.length} models, ${totalVoxels} voxels, ${totalTris} triangles`);

if (mvDir) {
  fs.mkdirSync(mvDir, { recursive: true });
  for (const row of rows) {
    fs.copyFileSync(pipeline.voxPath(ROOT, row.id), path.join(mvDir, row.id + ".vox"));
  }
  console.log(`copied ${rows.length} .vox to ${mvDir}`);
}

if (preview) {
  const { renderModel } = require("./preview");
  fs.mkdirSync(path.join(ROOT, "build/vox_previews"), { recursive: true });
  for (const row of rows) {
    const out = path.join(ROOT, "build/vox_previews", row.id + ".png");
    renderModel(ROOT, row.id, out, 480, 360);
    console.log("preview " + path.relative(ROOT, out));
  }
}
