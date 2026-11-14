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
//   assets/sounds/*.wav + main/sounds.go
//   assets/fonts/main.font
const path = require("path");
const palette = require("./gen/palette");
const models = require("./gen/models");
const ui = require("./gen/ui");
const sfx = require("./gen/sfx");
const defold = require("./gen/defold");

const ROOT = path.resolve(__dirname, "..");
const force = process.argv.includes("--force");

palette.writeTexture(path.join(ROOT, "assets/textures/palette.png"));

const ids = Object.keys(models);
let tris = 0;
for (const id of ids) {
  const info = models[id]().writeGltf(path.join(ROOT, "assets/models", id + ".gltf"), id);
  tris += info.tris;
}
const created = defold.entities(ROOT, ids, force);
defold.factories(ROOT, ids);

const images = ui.generate(ROOT);
defold.atlas(ROOT, images);

const snd = sfx.generate(ROOT);
defold.sounds(ROOT, snd, sfx.LOOPING);

defold.font(ROOT);

console.log(`models: ${ids.length} (${tris} triangles), new entities: ${created}, ui images: ${images.length}, sounds: ${snd.length}`);
