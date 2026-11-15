// Low-poly mesh builder -> self-contained glTF 2.0 (positions, normals, palette UVs).
// Coordinates: x = right, y = up, z = toward the camera. Colors are palette names (see palette.js).
const fs = require("fs");
const path = require("path");
const { uv } = require("./palette");

function colorsOf(colors) {
  return typeof colors === "string"
    ? { top: colors, bottom: colors, side: colors, front: colors, back: colors }
    : colors;
}

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

class Mesh {
  constructor() {
    this.pos = [];
    this.nrm = [];
    this.uvs = [];
    this.idx = [];
  }

  tri(a, b, c, color) {
    const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
    const vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
    let nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    const l = Math.hypot(nx, ny, nz) || 1;
    nx /= l; ny /= l; nz /= l;
    const [u, v] = uv(color);
    const base = this.pos.length / 3;
    for (const p of [a, b, c]) {
      this.pos.push(p[0], p[1], p[2]);
      this.nrm.push(nx, ny, nz);
      this.uvs.push(u, v);
    }
    this.idx.push(base, base + 1, base + 2);
    return this;
  }

  // quad a-b-c-d counter-clockwise when looking at its front face
  quad(a, b, c, d, color) {
    this.tri(a, b, c, color);
    this.tri(a, c, d, color);
    return this;
  }

  // Axis-aligned box from center + size. `colors` = one name or { top, bottom, side, front, back }.
  box(cx, cy, cz, sx, sy, sz, colors) {
    const c = colorsOf(colors);
    const side = c.side || c.front;
    const hx = sx / 2, hy = sy / 2, hz = sz / 2;
    const p = (x, y, z) => [cx + x * hx, cy + y * hy, cz + z * hz];
    this.quad(p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1), c.front || side); // +z
    this.quad(p(1, -1, -1), p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1), c.back || side); // -z
    this.quad(p(1, -1, 1), p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), side); // +x
    this.quad(p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1), side); // -x
    this.quad(p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), p(-1, 1, -1), c.top || side); // +y
    this.quad(p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1), c.bottom || side); // -y
    return this;
  }

  // Box from min/max corners
  boxMM(x0, y0, z0, x1, y1, z1, colors) {
    return this.box((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, colors);
  }

  // Box rotated around the z axis (spokes, tread blocks, diagonal braces).
  boxRotZ(cx, cy, cz, sx, sy, sz, angle, colors) {
    const c = colorsOf(colors);
    const side = c.side || c.front;
    const hx = sx / 2, hy = sy / 2, hz = sz / 2;
    const ca = Math.cos(angle), sa = Math.sin(angle);
    const p = (x, y, z) => [cx + x * hx * ca - y * hy * sa, cy + x * hx * sa + y * hy * ca, cz + z * hz];
    this.quad(p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1), c.front || side);
    this.quad(p(1, -1, -1), p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1), c.back || side);
    this.quad(p(1, -1, 1), p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), side);
    this.quad(p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1), side);
    this.quad(p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), p(-1, 1, -1), c.top || side);
    this.quad(p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1), c.bottom || side);
    return this;
  }

  // Voxel bevel: a core box with slightly inset top and bottom plates. Cheap and reads as a
  // chamfered cube at any scale (Drive Mad style).
  bevelBox(cx, cy, cz, sx, sy, sz, bevel, colors) {
    const c = colorsOf(colors);
    const b = clamp(bevel || 0, 0.001, Math.min(sx * 0.45, sy * 0.45, sz * 0.45));
    const hx = sx / 2, hy = sy / 2, hz = sz / 2;
    const side = c.side || c.front;
    if (sy <= b * 2.02) return this.box(cx, cy, cz, sx, sy, sz, colors);
    // body
    this.box(cx, cy, cz, sx, sy - b * 2, sz, {
      top: c.topSide || c.top || side,
      bottom: c.bottomSide || c.bottom || side,
      side,
      front: c.front || side,
      back: c.back || side,
    });
    // top plate
    this.box(cx, cy + hy - b / 2, cz, sx - b * 2, b, sz - b * 2, {
      top: c.top || c.layer || side,
      bottom: c.topSide || c.layer || side,
      side: c.topSide || c.layer || side,
      front: c.frontTop || c.layer || side,
      back: c.backTop || c.layer || side,
    });
    // bottom plate
    this.box(cx, cy - hy + b / 2, cz, sx - b * 2, b, sz - b * 2, {
      top: c.bottomSide || c.layer || side,
      bottom: c.bottom || c.layer || side,
      side: c.bottomSide || c.layer || side,
      front: c.frontBottom || c.layer || side,
      back: c.backBottom || c.layer || side,
    });
    return this;
  }

  bevelBoxMM(x0, y0, z0, x1, y1, z1, bevel, colors) {
    return this.bevelBox((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, bevel, colors);
  }

  // Prism along z from a 2D convex polygon (CCW in xy), z from z0 to z1.
  prism(pts, z0, z1, colors) {
    const c = typeof colors === "string" ? { cap: colors, side: colors } : colors;
    let area = 0;
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length];
      area += a[0] * b[1] - b[0] * a[1];
    }
    if (area < 0) pts = pts.slice().reverse();
    const n = pts.length;
    const cx = pts.reduce((s, p) => s + p[0], 0) / n, cy = pts.reduce((s, p) => s + p[1], 0) / n;
    for (let i = 0; i < n; i++) {
      const a = pts[i], b = pts[(i + 1) % n];
      this.tri([cx, cy, z1], [a[0], a[1], z1], [b[0], b[1], z1], c.front || c.cap || c.side);
      this.tri([cx, cy, z0], [b[0], b[1], z0], [a[0], a[1], z0], c.back || c.cap || c.side);
      const sideColor = typeof c.side === "function" ? c.side(a, b) : (c.side || c.cap || c.front);
      this.quad([a[0], a[1], z0], [b[0], b[1], z0], [b[0], b[1], z1], [a[0], a[1], z1], sideColor);
    }
    return this;
  }

  // Prism along y from a 2D polygon in the xz plane (ramps, chevrons, flat plates).
  prismY(pts, y0, y1, colors) {
    const c = typeof colors === "string" ? { cap: colors, side: colors } : colors;
    // normalise to CCW in (x, z) so the generated faces point outward
    let area = 0;
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length];
      area += a[0] * b[1] - b[0] * a[1];
    }
    const p = area < 0 ? pts.slice().reverse() : pts;
    const n = p.length;
    const cx = p.reduce((s, q) => s + q[0], 0) / n;
    const cz = p.reduce((s, q) => s + q[1], 0) / n;
    for (let i = 0; i < n; i++) {
      const a = p[i], b = p[(i + 1) % n];
      // +y cap (reversed winding) and -y cap
      this.tri([cx, y1, cz], [b[0], y1, b[1]], [a[0], y1, a[1]], c.top || c.cap || c.side);
      this.tri([cx, y0, cz], [a[0], y0, a[1]], [b[0], y0, b[1]], c.bottom || c.cap || c.side);
      const sideColor = typeof c.side === "function" ? c.side(a, b) : (c.side || c.cap || c.top);
      this.quad([a[0], y0, a[1]], [a[0], y1, a[1]], [b[0], y1, b[1]], [b[0], y0, b[1]], sideColor);
    }
    return this;
  }

  // Regular n-gon cylinder along z (wheels), centered at (cx, cy)
  cylinder(cx, cy, r, z0, z1, n, colors) {
    const pts = [];
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 + Math.PI / n;
      pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    }
    return this.prism(pts, z0, z1, colors);
  }

  // Ring in the xy plane (portals, selection) made of n box-like segments
  ring(cx, cy, rx, ry, thick, depth, n, color, z = 0) {
    for (let i = 0; i < n; i++) {
      const a0 = (i / n) * Math.PI * 2, a1 = ((i + 1) / n) * Math.PI * 2;
      const o0 = [cx + Math.cos(a0) * (rx + thick / 2), cy + Math.sin(a0) * (ry + thick / 2)];
      const o1 = [cx + Math.cos(a1) * (rx + thick / 2), cy + Math.sin(a1) * (ry + thick / 2)];
      const i1 = [cx + Math.cos(a1) * (rx - thick / 2), cy + Math.sin(a1) * (ry - thick / 2)];
      const i0 = [cx + Math.cos(a0) * (rx - thick / 2), cy + Math.sin(a0) * (ry - thick / 2)];
      this.prism([i0, o0, o1, i1], z - depth / 2, z + depth / 2, color);
    }
    return this;
  }

  // Square pyramid (spikes)
  pyramid(cx, cy, cz, w, h, d, color, color2) {
    const t = [cx, cy + h, cz];
    const a = [cx - w / 2, cy, cz + d / 2], b = [cx + w / 2, cy, cz + d / 2];
    const c = [cx + w / 2, cy, cz - d / 2], e = [cx - w / 2, cy, cz - d / 2];
    this.tri(a, b, t, color);
    this.tri(b, c, t, color2 || color);
    this.tri(c, e, t, color);
    this.tri(e, a, t, color2 || color);
    this.quad(e, c, b, a, color2 || color);
    return this;
  }

  // Append another mesh transformed by (dx, dy, dz)
  add(other, dx = 0, dy = 0, dz = 0) {
    const base = this.pos.length / 3;
    for (let i = 0; i < other.pos.length; i += 3) {
      this.pos.push(other.pos[i] + dx, other.pos[i + 1] + dy, other.pos[i + 2] + dz);
    }
    this.nrm.push(...other.nrm);
    this.uvs.push(...other.uvs);
    for (const k of other.idx) this.idx.push(k + base);
    return this;
  }

  writeGltf(file, name) {
    const count = this.pos.length / 3;
    const big = count > 65535;
    const pos = new Float32Array(this.pos), nrm = new Float32Array(this.nrm), uvs = new Float32Array(this.uvs);
    const idx = big ? new Uint32Array(this.idx) : new Uint16Array(this.idx);
    const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < pos.length; i += 3) {
      for (let k = 0; k < 3; k++) {
        min[k] = Math.min(min[k], pos[i + k]);
        max[k] = Math.max(max[k], pos[i + k]);
      }
    }
    const bufs = [Buffer.from(pos.buffer), Buffer.from(nrm.buffer), Buffer.from(uvs.buffer), Buffer.from(idx.buffer)];
    const pad = bufs[3].length % 4 ? Buffer.alloc(4 - (bufs[3].length % 4)) : Buffer.alloc(0);
    const bin = Buffer.concat([...bufs, pad]);
    let off = 0;
    const views = bufs.map((b, i) => {
      const v = { buffer: 0, byteOffset: off, byteLength: b.length, target: i === 3 ? 34963 : 34962 };
      off += b.length;
      return v;
    });
    const gltf = {
      asset: { version: "2.0", generator: "BridgeMad-gen" },
      scene: 0,
      scenes: [{ nodes: [0] }],
      nodes: [{ name, mesh: 0 }],
      meshes: [{ name, primitives: [{ attributes: { POSITION: 0, NORMAL: 1, TEXCOORD_0: 2 }, indices: 3, mode: 4 }] }],
      buffers: [{ uri: "data:application/octet-stream;base64," + bin.toString("base64"), byteLength: bin.length }],
      bufferViews: views,
      accessors: [
        { bufferView: 0, componentType: 5126, count, type: "VEC3", min, max },
        { bufferView: 1, componentType: 5126, count, type: "VEC3" },
        { bufferView: 2, componentType: 5126, count, type: "VEC2" },
        { bufferView: 3, componentType: big ? 5125 : 5123, count: idx.length, type: "SCALAR" },
      ],
    };
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(gltf));
    return { tris: idx.length / 3 };
  }
}

module.exports = { Mesh };
