// MagicaVoxel .vox reader/writer (single model, version 150).
// Palette convention matches MagicaVoxel: XYZI color index 1..255/256 maps to RGBA entry index-1.
// The generator stores the game palette (tools/gen/palette.js) in that order, so a voxel
// color index i always means game palette index i-1 and a converted model keeps exact colors.
const fs = require("fs");

const MAIN = 0x4e49414d;
const SIZE = 0x455a4953;
const XYZI = 0x495a5958;
const RGBA = 0x41424752;

function u32(n) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(n >>> 0, 0);
  return b;
}

function chunk(id, payload) {
  return Buffer.concat([u32(id), u32(payload.length), u32(0), payload]);
}

// palette: array of 256 [r,g,b,a]; voxels: array of {x,y,z,c} with c = palette index (1-based)
function encode({ size, voxels, palette }) {
  const [sx, sy, sz] = size;
  if (sx < 1 || sy < 1 || sz < 1 || sx > 256 || sy > 256 || sz > 256) {
    throw new Error(`bad vox size ${size.join("x")}`);
  }
  const sizeChunk = Buffer.alloc(12);
  sizeChunk.writeUInt32LE(sx, 0);
  sizeChunk.writeUInt32LE(sy, 4);
  sizeChunk.writeUInt32LE(sz, 8);

  const xyzi = Buffer.alloc(4 + voxels.length * 4);
  xyzi.writeUInt32LE(voxels.length, 0);
  voxels.forEach((v, i) => {
    const o = 4 + i * 4;
    xyzi[o] = v.x;
    xyzi[o + 1] = v.y;
    xyzi[o + 2] = v.z;
    xyzi[o + 3] = v.c;
  });

  const rgba = Buffer.alloc(256 * 4);
  for (let i = 0; i < 256; i++) {
    const [r, g, b, a] = palette[i] || [0, 0, 0, 0];
    rgba[i * 4] = r;
    rgba[i * 4 + 1] = g;
    rgba[i * 4 + 2] = b;
    rgba[i * 4 + 3] = a;
  }

  const body = Buffer.concat([chunk(SIZE, sizeChunk), chunk(XYZI, xyzi), chunk(RGBA, rgba)]);
  const main = Buffer.concat([u32(MAIN), u32(0), u32(body.length), body]);
  return Buffer.concat([Buffer.from("VOX ", "ascii"), u32(150), main]);
}

function decode(buf) {
  if (buf.toString("ascii", 0, 4) !== "VOX ") throw new Error("not a .vox file");
  const version = buf.readUInt32LE(4);
  let size = null;
  let voxels = [];
  let palette = null;
  let off = 8;
  while (off + 12 <= buf.length) {
    const id = buf.readUInt32LE(off);
    const chunkSize = buf.readUInt32LE(off + 4);
    const childSize = buf.readUInt32LE(off + 8);
    const data = buf.subarray(off + 12, off + 12 + chunkSize);
    if (id === MAIN) {
      // container: descend into its children instead of skipping them
      off += 12;
      continue;
    }
    if (id === SIZE && chunkSize >= 12) {
      size = [data.readUInt32LE(0), data.readUInt32LE(4), data.readUInt32LE(8)];
    } else if (id === XYZI && chunkSize >= 4) {
      const n = data.readUInt32LE(0);
      voxels = [];
      for (let i = 0; i < n; i++) {
        const o = 4 + i * 4;
        voxels.push({ x: data[o], y: data[o + 1], z: data[o + 2], c: data[o + 3] });
      }
    } else if (id === RGBA) {
      palette = [];
      for (let i = 0; i < 256; i++) {
        palette.push([data[i * 4], data[i * 4 + 1], data[i * 4 + 2], data[i * 4 + 3]]);
      }
    }
    off += 12 + chunkSize + childSize;
  }
  if (!size) throw new Error("no SIZE chunk");
  if (!palette) palette = Array.from({ length: 256 }, () => [0, 0, 0, 0]);
  return { version, size, voxels, palette };
}

function readFile(file) {
  return decode(fs.readFileSync(file));
}

function writeFile(file, model) {
  fs.writeFileSync(file, encode(model));
}

module.exports = { encode, decode, readFile, writeFile };
