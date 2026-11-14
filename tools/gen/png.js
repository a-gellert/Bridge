// Minimal RGBA PNG encoder + SDF canvas for anti-aliased procedural images.
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}

// rgba: Uint8 buffer (w*h*4)
function encode(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

function write(file, w, h, rgba) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, encode(w, h, rgba));
}

function hex(h) {
  const s = h.replace("#", "");
  return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}

// ---------------------------------------------------------------- SDF canvas
// Shapes are signed distance functions in pixel space; draw() composites them with 1px anti-aliasing.
class Canvas {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.data = Buffer.alloc(w * h * 4);
  }
  // sdf(x, y) -> distance (negative inside); color [r,g,b] 0..255; alpha 0..1
  draw(sdf, color, alpha = 1) {
    const { w, h, data } = this;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const d = sdf(x + 0.5, y + 0.5);
        const cov = Math.max(0, Math.min(1, 0.5 - d));
        if (cov <= 0) continue;
        const a = cov * alpha;
        const i = (y * w + x) * 4;
        const da = data[i + 3] / 255;
        const oa = a + da * (1 - a);
        if (oa <= 0) continue;
        for (let k = 0; k < 3; k++) {
          data[i + k] = Math.round((color[k] * a + data[i + k] * da * (1 - a)) / oa);
        }
        data[i + 3] = Math.round(oa * 255);
      }
    }
    return this;
  }
  // Erase pixels inside sdf (punch holes)
  erase(sdf) {
    const { w, h, data } = this;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const d = sdf(x + 0.5, y + 0.5);
        const cov = Math.max(0, Math.min(1, 0.5 - d));
        if (cov > 0) {
          const i = (y * w + x) * 4;
          data[i + 3] = Math.round(data[i + 3] * (1 - cov));
        }
      }
    }
    return this;
  }
  save(file) {
    write(file, this.w, this.h, this.data);
  }
}

// SDF primitives
const SDF = {
  circle: (cx, cy, r) => (x, y) => Math.hypot(x - cx, y - cy) - r,
  ring: (cx, cy, r, t) => (x, y) => Math.abs(Math.hypot(x - cx, y - cy) - r) - t / 2,
  rect: (cx, cy, hw, hh, r = 0) => (x, y) => {
    const qx = Math.abs(x - cx) - hw + r, qy = Math.abs(y - cy) - hh + r;
    return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
  },
  // capsule segment
  line: (ax, ay, bx, by, t) => (x, y) => {
    const px = x - ax, py = y - ay, ex = bx - ax, ey = by - ay;
    const h = Math.max(0, Math.min(1, (px * ex + py * ey) / (ex * ex + ey * ey)));
    return Math.hypot(px - ex * h, py - ey * h) - t / 2;
  },
  // convex polygon (points CCW or CW)
  poly: (pts) => (x, y) => {
    let d = Infinity, inside = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const [ax, ay] = pts[j], [bx, by] = pts[i];
      const ex = bx - ax, ey = by - ay, px = x - ax, py = y - ay;
      const h = Math.max(0, Math.min(1, (px * ex + py * ey) / (ex * ex + ey * ey)));
      d = Math.min(d, Math.hypot(px - ex * h, py - ey * h));
      if ((ay > y) !== (by > y) && x < ((bx - ax) * (y - ay)) / (by - ay) + ax) inside = !inside;
    }
    return inside ? -d : d;
  },
  union: (...fs) => (x, y) => Math.min(...fs.map((f) => f(x, y))),
  sub: (a, b) => (x, y) => Math.max(a(x, y), -b(x, y)),
  star: (cx, cy, ro, ri, n = 5, rot = -Math.PI / 2) => {
    const pts = [];
    for (let i = 0; i < n * 2; i++) {
      const r = i % 2 === 0 ? ro : ri;
      const a = rot + (i * Math.PI) / n;
      pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    }
    return SDF.poly(pts);
  },
};

module.exports = { write, encode, hex, Canvas, SDF };
