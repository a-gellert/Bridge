// Writers for Defold resource files (font, atlas, game objects with models, factories, sounds).
const fs = require("fs");
const path = require("path");

// Models drawn in the translucent pass (material voxel_alpha, predicate model_alpha)
const ALPHA_MODELS = new Set(["water", "water_top", "water_wave", "grid_dots", "zone", "portal_glow", "shadow"]);
const SKY_MODELS = new Set(["sky_band"]);

function write(root, rel, text, { keep = false } = {}) {
  const file = path.join(root, rel);
  if (keep && fs.existsSync(file)) return false;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text, "utf8");
  return true;
}

function escapeChars(chars) {
  let out = "";
  for (const ch of chars) {
    const code = ch.codePointAt(0);
    if (ch === "\\" || ch === '"') out += "\\" + ch;
    else if (code >= 32 && code <= 126) out += ch;
    else for (const b of Buffer.from(ch, "utf8")) out += "\\" + b.toString(8).padStart(3, "0");
  }
  return out;
}

function font(root) {
  let chars = "";
  for (let c = 32; c <= 126; c++) chars += String.fromCharCode(c);
  chars += "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя";
  chars += "—–•×→°«»…№";
  write(root, "assets/fonts/main.font", `font: "/assets/fonts/Nunito-Black.ttf"
material: "/builtins/fonts/font-df.material"
size: 48
antialias: 1
alpha: 1.0
outline_alpha: 1.0
outline_width: 4.0
shadow_alpha: 0.0
shadow_blur: 0
output_format: TYPE_DISTANCE_FIELD
render_mode: MODE_MULTI_LAYER
characters: "${escapeChars(chars)}"
`);
}

function atlas(root, images) {
  let s = "";
  for (const im of images) s += `images {\n  image: "/assets/images/ui/${im.name}.png"\n}\n`;
  s += "margin: 2\nextrude_borders: 2\ninner_padding: 0\n";
  write(root, "assets/images/ui.atlas", s);
}

function modelGo(id, glbIds) {
  const alpha = ALPHA_MODELS.has(id);
  const ext = glbIds && glbIds.has(id) ? "glb" : "gltf";
  const material = SKY_MODELS.has(id)
    ? "/assets/materials/sky.material"
    : alpha ? "/assets/materials/voxel_alpha.material" : "/assets/materials/voxel.material";
  const data =
    `mesh: \\"/assets/models/${id}.${ext}\\"\\n` +
    `name: \\"model\\"\\n` +
    `materials {\\n  name: \\"default\\"\\n  material: \\"${material}\\"\\n` +
    `  textures {\\n    sampler: \\"tex0\\"\\n    texture: \\"/assets/textures/palette.png\\"\\n  }\\n}\\n`;
  return `embedded_components {\n  id: "model"\n  type: "model"\n  data: "${data}"\n}\n`;
}

// entities/<id>.go: written only if missing, so hand-made replacements survive regeneration
function entities(root, ids, force, glbIds) {
  let n = 0;
  for (const id of ids) {
    if (write(root, `entities/${id}.go`, modelGo(id, glbIds), { keep: !force })) n++;
  }
  return n;
}

// world/world.go: the world controller script + one factory per entity (spawned as "#f_<id>")
function factories(root, ids) {
  let s = 'components {\n  id: "script"\n  component: "/world/world.script"\n}\n';
  for (const id of ids) {
    s += `embedded_components {\n  id: "f_${id}"\n  type: "factory"\n  data: "prototype: \\"/entities/${id}.go\\"\\n"\n}\n`;
  }
  write(root, "world/world.go", s);
}

function sounds(root, names, looping) {
  let s = "";
  for (const n of names) {
    const loop = looping.includes(n) ? 1 : 0;
    s += `embedded_components {\n  id: "${n}"\n  type: "sound"\n  data: "sound: \\"/assets/sounds/${n}.wav\\"\\nlooping: ${loop}\\ngroup: \\"master\\"\\ngain: 1.0\\n"\n}\n`;
  }
  write(root, "main/sounds.go", s);
}

module.exports = { font, atlas, entities, factories, sounds, ALPHA_MODELS };
