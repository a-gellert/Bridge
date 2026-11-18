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
let tris = 0;
let voxCount = 0;
for (const id of jsIds) {
  // assets/vox/<id>.vox wins: the model is edited in MagicaVoxel, glTF is generated from it
  const hasVox = !noVox && fs.existsSync(vox.voxPath(ROOT, id)) && fs.existsSync(vox.metaPath(ROOT, id));
  const info = hasVox
    ? vox.buildGltf(ROOT, id)
    : models[id]().writeGltf(path.join(ROOT, "assets/models", id + ".gltf"), id);
  if (hasVox) voxCount++;
  tris += info.tris;
}
const extraIds = ["bg_sky", "bg_mountains"];
const allIds = Array.from(new Set(Object.keys(models).concat(blender.ids).concat(extraIds)));
const created = defold.entities(ROOT, allIds, force, blender.set);
defold.factories(ROOT, allIds);

const images = ui.generate(ROOT);
defold.atlas(ROOT, images);

const storeIcons = icons.generate(ROOT);

const snd = sfx.generate(ROOT);
defold.sounds(ROOT, snd, sfx.LOOPING);

defold.font(ROOT);

console.log(`js models: ${jsIds.length} (${tris} triangles, ${voxCount} from .vox), blender models: ${blender.ids.length}, new entities: ${created}, ui images: ${images.length}, store icons: ${storeIcons.length}, sounds: ${snd.length}`);
