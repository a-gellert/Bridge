// Voxel grid -> low-poly glTF with palette UVs (tools/gen/mesh.js).
// Hidden faces (solid neighbor) are dropped and coplanar faces of one color are greedy-merged,
// so a 40^3 voxel model stays in the low thousands of triangles.
const { Mesh } = require("../gen/mesh");
const { COLORS } = require("../gen/palette");

const NAMES = Object.keys(COLORS);

// volume: { dims, step: [sx, sy, sz], origin, grid }
function voxelsToMesh({ dims, step, origin, grid }) {
  const mesh = new Mesh();
  const at = (x, y, z) => {
    if (x < 0 || y < 0 || z < 0 || x >= dims[0] || y >= dims[1] || z >= dims[2]) return -1;
    return grid[x + dims[0] * (y + dims[1] * z)];
  };
  const nameOf = (c) => NAMES[c] || "white";

  for (let axis = 0; axis < 3; axis++) {
    const U = (axis + 1) % 3;
    const V = (axis + 2) % 3;
    const uN = dims[U], vN = dims[V], aN = dims[axis];
    const mask = new Int32Array(uN * vN);
    for (const dir of [1, -1]) {
      for (let s = 0; s < aN; s++) {
        // 1. mask of visible faces on this slice
        let any = false;
        const p = [0, 0, 0];
        for (let v = 0; v < vN; v++) {
          for (let u = 0; u < uN; u++) {
            p[axis] = s;
            p[U] = u;
            p[V] = v;
            const c = at(p[0], p[1], p[2]);
            let m = 0;
            if (c >= 0) {
              const q = p.slice();
              q[axis] = s + dir;
              if (at(q[0], q[1], q[2]) === -1) m = c + 1; // -1 = empty; negative interior still blocks
            }
            mask[v * uN + u] = m;
            if (m) any = true;
          }
        }
        if (!any) continue;

        // 2. greedy rectangles
        for (let v = 0; v < vN; v++) {
          for (let u = 0; u < uN; ) {
            const m = mask[v * uN + u];
            if (!m) { u++; continue; }
            let w = 1;
            while (u + w < uN && mask[v * uN + u + w] === m) w++;
            let h = 1;
            grow: while (v + h < vN) {
              for (let k = 0; k < w; k++) {
                if (mask[(v + h) * uN + u + k] !== m) break grow;
              }
              h++;
            }
            for (let j = 0; j < h; j++) {
              for (let k = 0; k < w; k++) mask[(v + j) * uN + u + k] = 0;
            }

            // 3. quad in world space (CCW seen from outside)
            const plane = origin[axis] + (s + (dir > 0 ? 1 : 0)) * step[axis];
            const u0 = origin[U] + u * step[U], u1 = origin[U] + (u + w) * step[U];
            const v0 = origin[V] + v * step[V], v1 = origin[V] + (v + h) * step[V];
            const corner = (uu, vv) => {
              const pt = [0, 0, 0];
              pt[axis] = plane;
              pt[U] = uu;
              pt[V] = vv;
              return pt;
            };
            const a = corner(u0, v0), b = corner(u1, v0), c = corner(u1, v1), d = corner(u0, v1);
            // normal of a-b-c points along (U x V) = +axis; flip for the negative side
            if (dir > 0) mesh.quad(a, b, c, d, nameOf(m - 1));
            else mesh.quad(d, c, b, a, nameOf(m - 1));

            u += w;
          }
        }
      }
    }
  }
  return mesh;
}

module.exports = { voxelsToMesh, NAMES };
