// Models authored in Blender (tools/blender/gen_models.py) and exported as .glb.
// Kept out of the JS voxel generator, but included in entity/factory generation.
const IDS = [
  "tree_blossom",
  "pine_tall",
  "rock_arch",
  "crystal_cluster",
  "ruin_arch",
  "windmill",
  "windmill_blades",
  "bird",
  "butterfly",
  "portal_blue",
  "portal_orange",
  "lab_generator",
  "lab_terminal",
  "energy_pylon",
  "chamber_sign",
  "cactus_saguaro",
  "lantern_post",
];

module.exports = { ids: IDS, set: new Set(IDS) };
