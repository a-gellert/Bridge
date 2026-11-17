// Mesh -> voxel grid. Used to turn the procedural low-poly models (tools/gen/models.js)
// into true voxel volumes. Coordinates stay in game space (x right, y up, z toward camera);
// the .vox writer swaps axes into MagicaVoxel's z-up space.
//
// 1. occupancy: a cell is solid when its center is within half a voxel of a triangle,
//    so trim, bolts and paint markings thinner than a voxel do not fall through the cracks;
// 2. flood fill from the border marks the outside, leftovers become the solid interior;
// 3. color: for every skin cell the outer surface facing the empty side wins (a raised dash
//    beats the road under it), otherwise the nearest surface wins.
const EMPTY = -1;
const OUTSIDE = -2;
const INTERIOR = -3;

function colorIndexAt(mesh, i) {
  const c = Math.floor(mesh.uvs[i * 2] * 16);
  const r = Math.floor(mesh.uvs[i * 2 + 1] * 16);
  return r * 16 + c;
}

function bboxOf(mesh) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < mesh.pos.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      const v = mesh.pos[i + k];
      if (v < min[k]) min[k] = v;
      if (v > max[k]) max[k] = v;
    }
  }
  return { min, max };
}

const dot3 = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const sub3 = (a, b, out) => {
  out[0] = a[0] - b[0];
  out[1] = a[1] - b[1];
  out[2] = a[2] - b[2];
  return out;
};

const _u = [0, 0, 0], _v = [0, 0, 0], _w = [0, 0, 0];
// closest point on triangle abc to p, written into out; returns squared distance
function closestPointTri(p, a, b, c, out) {
  const ab = sub3(b, a, _u), ac = sub3(c, a, _v), ap = sub3(p, a, _w);
  const d1 = dot3(ab, ap), d2 = dot3(ac, ap);
  if (d1 <= 0 && d2 <= 0) {
    out[0] = a[0]; out[1] = a[1]; out[2] = a[2];
    return dot3(ap, ap);
  }
  const bp = sub3(p, b, _w);
  const d3 = dot3(ab, bp), d4 = dot3(ac, bp);
  if (d3 >= 0 && d4 <= d3) {
    out[0] = b[0]; out[1] = b[1]; out[2] = b[2];
    return dot3(bp, bp);
  }
  const vc = d1 * d4 - d3 * d2;
  if (vc <= 0 && d1 >= 0 && d3 <= 0) {
    const v = d1 / (d1 - d3);
    out[0] = a[0] + ab[0] * v; out[1] = a[1] + ab[1] * v; out[2] = a[2] + ab[2] * v;
    const q = sub3(p, out, _w);
    return dot3(q, q);
  }
  const cp = sub3(p, c, _w);
  const d5 = dot3(ab, cp), d6 = dot3(ac, cp);
  if (d6 >= 0 && d5 <= d6) {
    out[0] = c[0]; out[1] = c[1]; out[2] = c[2];
    return dot3(cp, cp);
  }
  const vb = d5 * d2 - d1 * d6;
  if (vb <= 0 && d2 >= 0 && d6 <= 0) {
    const w = d2 / (d2 - d6);
    out[0] = a[0] + ac[0] * w; out[1] = a[1] + ac[1] * w; out[2] = a[2] + ac[2] * w;
    const q = sub3(p, out, _w);
    return dot3(q, q);
  }
  const va = d3 * d6 - d5 * d4;
  if (va <= 0 && d4 - d3 >= 0 && d5 - d6 >= 0) {
    const w = (d4 - d3) / (d4 - d3 + (d5 - d6));
    out[0] = b[0] + (c[0] - b[0]) * w;
    out[1] = b[1] + (c[1] - b[1]) * w;
    out[2] = b[2] + (c[2] - b[2]) * w;
    const q = sub3(p, out, _w);
    return dot3(q, q);
  }
  const denom = 1 / (va + vb + vc);
  const v = vb * denom, w = vc * denom;
  out[0] = a[0] + ab[0] * v + ac[0] * w;
  out[1] = a[1] + ab[1] * v + ac[1] * w;
  out[2] = a[2] + ab[2] * v + ac[2] * w;
  const q = sub3(p, out, _w);
  return dot3(q, q);
}

// opts.cell  fixed voxel size in meters (keeps the voxel scale consistent across models)
// opts.maxSide  fallback: longest side in voxels when no cell is given
function voxelize(mesh, opts = {}) {
  const { min, max } = bboxOf(mesh);
  const ext = [max[0] - min[0], max[1] - min[1], max[2] - min[2]];
  const maxExt = Math.max(...ext, 1e-4);

  let cell = opts.cell || maxExt / (opts.maxSide || 40);
  cell = Math.max(cell, 0.002);
  const dims = ext.map((e) => Math.min(256, Math.max(1, Math.round(e / cell))));
  while (Math.max(...dims) > 200) {
    cell *= 1.1;
    for (let k = 0; k < 3; k++) dims[k] = Math.min(256, Math.max(1, Math.round(ext[k] / cell)));
  }
  const center = [0, 1, 2].map((k) => (min[k] + max[k]) / 2);
  // the grid keeps the exact bounding box of the source mesh: one voxel is ext/dims along each
  // axis (near-cubic, ~1% anisotropy), so beams and wheels keep their gameplay dimensions
  const step = [0, 1, 2].map((k) => (ext[k] > 1e-6 ? ext[k] / dims[k] : cell));
  const origin = min.slice();
  if (opts.align) {
    for (let k = 0; k < 3; k++) origin[k] = Math.round((origin[k] - opts.align[k]) / step[k]) * step[k] + opts.align[k];
  }

  const P = [dims[0] + 2, dims[1] + 2, dims[2] + 2];
  const total = P[0] * P[1] * P[2];
  const solid = new Uint8Array(total);
  const idx = (x, y, z) => x + P[0] * (y + P[1] * z);
  const world = (i, k) => origin[k] + (i - 1 + 0.5) * step[k]; // padded index -> cell center
  const tris = mesh.idx.length / 3;
  const a = [0, 0, 0], b = [0, 0, 0], c = [0, 0, 0], p = [0, 0, 0], q = [0, 0, 0];
  const reach = 0.55 * Math.max(...step);
  const reach2 = reach * reach;

  const bboxCells = (lo, hi, fn) => {
    for (let z = lo[2]; z <= hi[2]; z++) {
      p[2] = world(z, 2);
      for (let y = lo[1]; y <= hi[1]; y++) {
        p[1] = world(y, 1);
        for (let x = lo[0]; x <= hi[0]; x++) {
          p[0] = world(x, 0);
          fn(idx(x, y, z));
        }
      }
    }
  };
  const triBounds = (ka) => {
    const lo = [0, 0, 0], hi = [0, 0, 0];
    for (let k = 0; k < 3; k++) {
      lo[k] = Math.max(0, Math.floor((Math.min(a[k], b[k], c[k]) - reach - origin[k]) / step[k]) + 1);
      hi[k] = Math.min(P[k] - 1, Math.ceil((Math.max(a[k], b[k], c[k]) + reach - origin[k]) / step[k]) + 1);
    }
    return [lo, hi];
  };
  const loadTri = (t) => {
    const ia = mesh.idx[t], ib = mesh.idx[t + 1], ic = mesh.idx[t + 2];
    for (let k = 0; k < 3; k++) {
      a[k] = mesh.pos[ia * 3 + k];
      b[k] = mesh.pos[ib * 3 + k];
      c[k] = mesh.pos[ic * 3 + k];
    }
    return ia;
  };

  // 1. occupancy
  for (let t = 0; t < tris; t++) {
    loadTri(t * 3);
    const [lo, hi] = triBounds();
    bboxCells(lo, hi, (k) => {
      if (closestPointTri(p, a, b, c, q) <= reach2) solid[k] = 1;
    });
  }

  // 2. outside flood fill (6-connected from the padded border)
  const outside = new Uint8Array(total);
  const queue = new Int32Array(total);
  let head = 0, tail = 0;
  const push = (k) => { if (!solid[k] && !outside[k]) { outside[k] = 1; queue[tail++] = k; } };
  for (let z = 0; z < P[2]; z++) {
    for (let y = 0; y < P[1]; y++) {
      for (let x = 0; x < P[0]; x++) {
        if (x !== 0 && x !== P[0] - 1 && y !== 0 && y !== P[1] - 1 && z !== 0 && z !== P[2] - 1) continue;
        push(idx(x, y, z));
      }
    }
  }
  const stride = [1, P[0], P[0] * P[1]];
  while (head < tail) {
    const k = queue[head++];
    const z = Math.floor(k / stride[2]);
    const r = k - z * stride[2];
    const y = Math.floor(r / stride[1]);
    const x = r - y * stride[1];
    if (x > 0) push(k - 1);
    if (x < P[0] - 1) push(k + 1);
    if (y > 0) push(k - stride[1]);
    if (y < P[1] - 1) push(k + stride[1]);
    if (z > 0) push(k - stride[2]);
    if (z < P[2] - 1) push(k + stride[2]);
  }

  // 3. outward direction per skin cell (sum of the empty neighbour axes)
  const dirs = new Float32Array(total * 3);
  const skin = [];
  for (let k = 0; k < total; k++) {
    if (!solid[k]) continue;
    const z = Math.floor(k / stride[2]);
    const r = k - z * stride[2];
    const y = Math.floor(r / stride[1]);
    const x = r - y * stride[1];
    let n = 0;
    const add = (nx, ny, nz) => {
      dirs[k * 3] += nx; dirs[k * 3 + 1] += ny; dirs[k * 3 + 2] += nz; n++;
    };
    if (x === 0 || outside[k - 1]) add(-1, 0, 0);
    if (x === P[0] - 1 || outside[k + 1]) add(1, 0, 0);
    if (y === 0 || outside[k - stride[1]]) add(0, -1, 0);
    if (y === P[1] - 1 || outside[k + stride[1]]) add(0, 1, 0);
    if (z === 0 || outside[k - stride[2]]) add(0, 0, -1);
    if (z === P[2] - 1 || outside[k + stride[2]]) add(0, 0, 1);
    if (n) {
      const len = Math.hypot(dirs[k * 3], dirs[k * 3 + 1], dirs[k * 3 + 2]) || 1;
      dirs[k * 3] /= len; dirs[k * 3 + 1] /= len; dirs[k * 3 + 2] /= len;
      skin.push(k);
    }
  }

  // 4. color the skin: the outermost face pointing at the empty side wins
  const colors = new Int16Array(total).fill(EMPTY);
  const score = new Float32Array(total).fill(-Infinity);
  const normal = [0, 0, 0];
  for (let t = 0; t < tris; t++) {
    const ia = loadTri(t * 3);
    const color = colorIndexAt(mesh, ia);
    for (let k = 0; k < 3; k++) normal[k] = mesh.nrm[ia * 3 + k];
    const [lo, hi] = triBounds();
    bboxCells(lo, hi, (k) => {
      if (!solid[k]) return;
      const d2 = closestPointTri(p, a, b, c, q);
      if (d2 > reach2) return;
      const dx = dirs[k * 3], dy = dirs[k * 3 + 1], dz = dirs[k * 3 + 2];
      let s;
      if (dx || dy || dz) {
        if (normal[0] * dx + normal[1] * dy + normal[2] * dz < 0.2) return; // wrong side
        s = q[0] * dx + q[1] * dy + q[2] * dz;
      } else {
        s = -d2; // closed pocket: nearest surface instead
      }
      if (s >= score[k]) {
        score[k] = s;
        colors[k] = color;
      }
    });
  }

  // 5. crop the padding into the final grid; interior cells become -3 (never shown)
  const out = new Int16Array(dims[0] * dims[1] * dims[2]).fill(EMPTY);
  let solidCount = 0;
  for (let z = 0; z < dims[2]; z++) {
    for (let y = 0; y < dims[1]; y++) {
      for (let x = 0; x < dims[0]; x++) {
        const k = idx(x + 1, y + 1, z + 1);
        if (!solid[k]) continue;
        out[x + dims[0] * (y + dims[1] * z)] = colors[k] >= 0 ? colors[k] : INTERIOR;
        solidCount++;
      }
    }
  }
  return { dims, cell, step, origin, grid: out, solid: solidCount, cells: total };
}

module.exports = { voxelize, EMPTY, INTERIOR };

// game space (x right, y up, z toward camera) -> MagicaVoxel (x right, y depth, z up)
const toVoxAxes = (p) => [p[0], -p[2], p[1]];
const fromVoxAxes = (p) => [p[0], p[2], -p[1]];
module.exports.toVoxAxes = toVoxAxes;
module.exports.fromVoxAxes = fromVoxAxes;
