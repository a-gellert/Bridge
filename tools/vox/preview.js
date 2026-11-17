// Renders one generated model to a PNG through the project's software preview renderer
// (tools/preview.js), so voxel models can be checked without Defold or Blender.
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

function readBounds(gltfFile) {
  const g = JSON.parse(fs.readFileSync(gltfFile, "utf8"));
  const pos = g.accessors[g.meshes[0].primitives[0].attributes.POSITION];
  return { min: pos.min, max: pos.max };
}

function normalize(v) {
  const l = Math.hypot(...v) || 1;
  return v.map((x) => x / l);
}
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

function lookAt(eye, target, up) {
  const f = normalize([target[0] - eye[0], target[1] - eye[1], target[2] - eye[2]]);
  const s = normalize(cross(f, up));
  const u = cross(s, f);
  return [
    [s[0], s[1], s[2], -dot(s, eye)],
    [u[0], u[1], u[2], -dot(u, eye)],
    [-f[0], -f[1], -f[2], dot(f, eye)],
    [0, 0, 0, 1],
  ];
}

function perspective(fovDeg, aspect, near, far) {
  const t = 1 / Math.tan((fovDeg * Math.PI) / 360);
  return [
    [t / aspect, 0, 0, 0],
    [0, t, 0, 0],
    [0, 0, (far + near) / (near - far), (2 * far * near) / (near - far)],
    [0, 0, -1, 0],
  ];
}

const flat = (m) => m.flat();

function renderModel(root, id, out, w = 480, h = 360, options = {}) {
  const gltfFile = path.join(root, "assets/models", id + ".gltf");
  const { min, max } = readBounds(gltfFile);
  const center = min.map((v, k) => (v + max[k]) / 2);
  const ext = max.map((v, k) => v - min[k]);
  const radius = Math.hypot(...ext) / 2 || 0.5;
  const dir = normalize(options.dir || [1, 0.72, 1.35]);
  const fov = options.fov || 32;
  const dist = (radius / Math.sin((fov * Math.PI) / 360)) * (options.zoom || 1.1);
  const eye = center.map((v, k) => v + dir[k] * dist);

  const scene = {
    objects: [
      {
        m: id,
        p: [0, 0, 0],
        q: [0, 0, 0, 1],
        s: [1, 1, 1],
        t: [1, 1, 1, 1],
        o: [1, 1, 1, 0],
      },
    ],
    view: flat(lookAt(eye, center, [0, 1, 0])),
    proj: flat(perspective(fov, w / h, 0.01, radius * 40 + 10)),
    sky: options.sky || [0.82, 0.88, 0.95],
    w,
    h,
  };
  const tmp = path.join(root, "build", "vox_previews", "_scene_" + id + ".json");
  fs.mkdirSync(path.dirname(tmp), { recursive: true });
  fs.writeFileSync(tmp, JSON.stringify(scene));
  execFileSync(process.execPath, [path.join(root, "tools/preview.js"), tmp, out], { stdio: "ignore" });
  fs.unlinkSync(tmp);
  return out;
}

module.exports = { renderModel };

if (require.main === module) {
  const [id, out] = process.argv.slice(2);
  if (!id) throw new Error("usage: node tools/vox/preview.js <id> <out.png>");
  const ROOT = path.resolve(__dirname, "../..");
  renderModel(ROOT, id, out || path.join(ROOT, "build/vox_previews", id + ".png"));
  console.log("preview ready");
}
