// Store icons (Android / iOS) drawn procedurally: a voxel bridge + truck badge.
// Tiny files, no external tools, regenerated with `node tools/gen_icons.js`.
const path = require("path");
const { Canvas, SDF } = require("./png");

const SKY = [62, 147, 222];
const SKY_DARK = [27, 32, 48];
const YELLOW = [255, 210, 63];
const GREEN = [53, 201, 126];
const ASPHALT = [74, 79, 94];
const WHITE = [255, 255, 255];

function drawIcon(size) {
  const c = new Canvas(size, size);
  const s = size / 96; // design at 96 x 96
  const u = (v) => v * s;
  // rounded badge background
  c.draw(SDF.rect(48 * s, 48 * s, 46 * s, 46 * s, 18 * s), SKY);
  c.draw(SDF.rect(48 * s, 30 * s, 46 * s, 16 * s, 16 * s), [104, 180, 240]);
  // bridge deck and trusses
  c.draw(SDF.rect(48 * s, 60 * s, 34 * s, 4 * s, 2 * s), YELLOW);
  c.draw(SDF.line(20 * s, 58 * s, 20 * s, 42 * s, 4 * s), YELLOW);
  c.draw(SDF.line(76 * s, 58 * s, 76 * s, 42 * s, 4 * s), YELLOW);
  c.draw(SDF.union(
    SDF.line(20 * s, 58 * s, 38 * s, 42 * s, 3 * s),
    SDF.line(38 * s, 42 * s, 58 * s, 58 * s, 3 * s),
    SDF.line(58 * s, 58 * s, 76 * s, 42 * s, 3 * s)
  ), GREEN);
  // truck
  c.draw(SDF.rect(48 * s, 74 * s, 20 * s, 8 * s, 3 * s), YELLOW);
  c.draw(SDF.rect(64 * s, 70 * s, 8 * s, 7 * s, 3 * s), YELLOW);
  c.draw(SDF.rect(48 * s, 73 * s, 15 * s, 3 * s, 1.5 * s), ASPHALT);
  c.draw(SDF.circle(36 * s, 85 * s, 6 * s), SKY_DARK);
  c.draw(SDF.circle(63 * s, 85 * s, 6 * s), SKY_DARK);
  c.draw(SDF.circle(36 * s, 85 * s, 2.2 * s), WHITE);
  c.draw(SDF.circle(63 * s, 85 * s, 2.2 * s), WHITE);
  return c;
}

const SIZES = [36, 48, 72, 76, 96, 120, 144, 152, 167, 180, 192, 512, 1024];

function generate(root) {
  const out = [];
  for (const size of SIZES) {
    const file = path.join(root, "assets/icons", "icon_" + size + ".png");
    drawIcon(size).save(file);
    out.push(file);
  }
  return out;
}

module.exports = { generate, drawIcon };

if (require.main === module) {
  const root = path.resolve(__dirname, "..", "..");
  const files = generate(root);
  console.log("icons:", files.length);
}
