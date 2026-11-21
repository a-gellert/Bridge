// Procedural asset generator for Bridge Mad.
//   node tools/gen_assets.js            regenerate textures, models, UI images, sounds, font, factories
//   node tools/gen_assets.js --force    also overwrite entities/*.go (resets hand-replaced models!)
//
// Outputs:
//   assets/textures/palette.png    shared color palette (models use palette UVs)
//   assets/models/*.gltf           voxel models (see tools/gen/models.js)
//   entities/*.go                  one game object per model (only created when missing)
//   world/world.go                 world.script + one factory per entity
//   assets/images/ui/*.png + assets/images/ui.atlas
//   assets/icons/*.png             store icons for Android / iOS
//   assets/sounds/*.wav + main/sounds.go
//   assets/fonts/main.font
const path = require("path");
const fs = require("fs");
const palette = require("./gen/palette");
const models = require("./gen/models");
const vox = require("./vox/pipeline");
const ui = require("./gen/ui");
const sfx = require("./gen/sfx");
const icons = require("./gen/icons");
const blender = require("./gen/blender_assets");
const defold = require("./gen/defold");

const ROOT = path.resolve(__dirname, "..");
const force = process.argv.includes("--force");
const noVox = process.argv.includes("--no-vox");

palette.writeTexture(path.join(ROOT, "assets/textures/palette.png"));
palette.writeJson(path.join(ROOT, "tools/gen/palette.json"));

const jsIds = Object.keys(models).filter((id) => !blender.set.has(id));
// a .vox without its sidecar (or the reverse) is silently ignored below: say so
for (const id of jsIds.concat(blender.ids)) {
  const v = fs.existsSync(vox.voxPath(ROOT, id)), m = fs.existsSync(vox.metaPath(ROOT, id));
  if (v !== m) console.warn(`warning: assets/vox/${id}.${v ? "json" : "vox"} is missing, ${id} falls back to its source mesh`);
}
let tris = 0;
let voxCount = 0;
for (const id of jsIds) {
  // assets/vox/<id>.vox wins: the model is edited in MagicaVoxel, glTF is generated from it
  const hasVox = !noVox && fs.existsSync(vox.voxPath(ROOT, id)) && fs.existsSync(vox.metaPath(ROOT, id));
  let info;
  if (hasVox) {
    info = vox.buildGltf(ROOT, id); // also writes <id>_paint.gltf for paintable vehicles
    voxCount++;
  } else if (vox.PAINT[id]) {
    const [body, paint] = vox.splitMeshPaint(models[id](), id);
    info = body.writeGltf(path.join(ROOT, "assets/models", id + ".gltf"), id);
    info.tris += paint.writeGltf(path.join(ROOT, "assets/models", id + "_paint.gltf"), id + "_paint").tris;
  } else {
    info = models[id]().writeGltf(path.join(ROOT, "assets/models", id + ".gltf"), id);
  }
  tris += info.tris;
}
// Blender decor voxelised by `node tools/vox/build.js --blender`: the .vox wins over the .glb
const voxBlender = noVox ? [] : blender.ids.filter((id) => fs.existsSync(vox.voxPath(ROOT, id)) && fs.existsSync(vox.metaPath(ROOT, id)));
for (const id of voxBlender) {
  tris += vox.buildGltf(ROOT, id).tris;
  voxCount++;
}
const glbIds = new Set(blender.ids.filter((id) => !voxBlender.includes(id)));
const allIds = Array.from(new Set(Object.keys(models).concat(blender.ids).concat(vox.PAINT_IDS)));
const created = defold.entities(ROOT, allIds, force, glbIds);
// their entities must follow the mesh from .glb to .gltf (and back with --no-vox)
defold.entities(ROOT, blender.ids, true, glbIds);
defold.factories(ROOT, allIds);

const images = ui.generate(ROOT);
defold.atlas(ROOT, images);

const storeIcons = icons.generate(ROOT);

const snd = sfx.generate(ROOT);
defold.sounds(ROOT, snd, sfx.LOOPING);

defold.font(ROOT);

console.log(`js models: ${jsIds.length}, blender models: ${blender.ids.length} (${voxBlender.length} voxelised), ${tris} triangles, ${voxCount} from .vox, new entities: ${created}, ui images: ${images.length}, store icons: ${storeIcons.length}, sounds: ${snd.length}`);
