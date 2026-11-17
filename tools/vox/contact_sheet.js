// Renders a contact sheet of every voxel-generated model (build/vox_contact_sheet.png).
// Models are normalized into equal cells, so a flower and a truck are comparable.
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const { voxPath, gltfPath } = require("./pipeline");

const ROOT = path.resolve(__dirname, "../..");
const OUT = path.join(ROOT, "build/vox_contact_sheet.png");
const W = 1400, H = 900, COLS = 10;
const GAP = 1.22;

function bounds(file) {
  const g = JSON.parse(fs.readFileSync(file, "utf8"));
  const a = g.accessors[g.meshes[0].primitives[0].attributes.POSITION];
  return { min: a.min, max: a.max };
}
const norm = (v) => {
  const l = Math.hypot(...v) || 1;
  return v.map((x) => x / l);
};
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

const ids = fs
  .readdirSync(path.join(ROOT, "assets/vox"))
  .filter((f) => f.endsWith(".vox"))
  .map((f) => f.slice(0, -4))
  .filter((id) => fs.existsSync(gltfPath(ROOT, id)))
  .sort();

const rows = Math.ceil(ids.length / COLS);
const gw = (COLS - 1) * GAP, gh = (rows - 1) * GAP;
const objects = ids.map((id, i) => {
  const { min, max } = bounds(gltfPath(ROOT, id));
  const ext = max.map((v, k) => v - min[k]);
  const s = 1 / Math.max(...ext, 1e-4);
  const cx = (min[0] + max[0]) / 2, cy = (min[1] + max[1]) / 2, cz = (min[2] + max[2]) / 2;
  const col = i % COLS, row = Math.floor(i / COLS);
  return {
    m: id,
    p: [col * GAP - gw / 2 - cx * s, -min[1] * s, row * GAP - gh / 2 - cz * s],
    q: [0, 0, 0, 1],
    s: [s, s, s],
    t: [1, 1, 1, 1],
    o: [1, 1, 1, 0],
  };
});

const dist = 40;
const eye = norm([0.15, 1.0, 0.8]).map((v) => v * dist);
const f = norm(eye.map((v) => -v));
const s = norm(cross(f, [0, 1, 0]));
const u = cross(s, f);
const view = [
  [s[0], s[1], s[2], -dot(s, eye)],
  [u[0], u[1], u[2], -dot(u, eye)],
  [-f[0], -f[1], -f[2], dot(f, eye)],
  [0, 0, 0, 1],
];
const t = 1 / Math.tan((20 * Math.PI) / 360);
const near = 1, far = 100;
const proj = [
  [t / (W / H), 0, 0, 0],
  [0, t, 0, 0],
  [0, 0, (far + near) / (near - far), (2 * far * near) / (near - far)],
  [0, 0, -1, 0],
];

const scene = {
  objects,
  view: view.flat(),
  proj: proj.flat(),
  sky: [0.86, 0.9, 0.96],
  w: W,
  h: H,
};
const tmp = path.join(ROOT, "build", "_contact_scene.json");
fs.writeFileSync(tmp, JSON.stringify(scene));
execFileSync(process.execPath, [path.join(ROOT, "tools/preview.js"), tmp, OUT], { stdio: "ignore" });
fs.unlinkSync(tmp);
console.log("contact sheet", path.relative(ROOT, OUT), ids.length + " models");
console.log(ids.join(" "));
