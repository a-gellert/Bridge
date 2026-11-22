// UI images for the GUI atlas. One style for the whole game:
//   glyphs  white, rounded, one stroke weight (~11 px at 96 px); the GUI tints them. Two-tone glyphs
//           (coin) use light grey for the second tone so the tint keeps both shades.
//   items   coloured icons rendered from the game's own models (tools/gen/icon3d.js): vehicles,
//           materials, the eraser and the garage previews. Same palette and lighting as the world,
//           outlined with the ink colour of the GUI text outline.
// Every image is generated here: there are no hand-painted or external bitmaps in the atlas.
// Also writes gui/icon_sizes.lua (image -> width / height) so the GUI keeps aspect ratios.
const fs = require("fs");
const path = require("path");
const { Canvas, SDF, hex } = require("./png");
const { COLORS } = require("./palette");
const { Mesh } = require("./mesh");
const ic = require("./icon3d");

const W = [255, 255, 255];
const G2 = [196, 196, 196]; // second tone of two-tone glyphs (tinted together with white)
const S = 96; // glyph size

function icon(draw) {
  const c = new Canvas(S, S);
  draw(c, S / 2);
  return c;
}

// ellipse helpers (approximate SDF, good enough for anti-aliased glyph edges)
const ellipse = (cx, cy, rx, ry) => (x, y) => (Math.hypot((x - cx) / rx, (y - cy) / ry) - 1) * Math.min(rx, ry);
const eRing = (cx, cy, rx, ry, t) => {
  const e = ellipse(cx, cy, rx, ry);
  return (x, y) => Math.abs(e(x, y)) - t / 2;
};
const chevron = (cx, cy, dir, size, t) => {
  // dir: 1 right, -1 left, 2 up, -2 down
  const s = size;
  let a, b, c;
  if (dir === 1) { a = [cx - s / 2, cy - s]; b = [cx + s / 2, cy]; c = [cx - s / 2, cy + s]; }
  else if (dir === -1) { a = [cx + s / 2, cy - s]; b = [cx - s / 2, cy]; c = [cx + s / 2, cy + s]; }
  else if (dir === 2) { a = [cx - s, cy + s / 2]; b = [cx, cy - s / 2]; c = [cx + s, cy + s / 2]; }
  else { a = [cx - s, cy - s / 2]; b = [cx, cy + s / 2]; c = [cx + s, cy - s / 2]; }
  return SDF.union(SDF.line(a[0], a[1], b[0], b[1], t), SDF.line(b[0], b[1], c[0], c[1], t));
};

const GLYPHS = {
  white: () => new Canvas(8, 8).draw(() => -10, W),
  panel: () => new Canvas(64, 64).draw(SDF.rect(32, 32, 31, 31, 18), W),
  btn: () => {
    // rounded button with a darker bottom lip (tinted as a whole)
    const c = new Canvas(64, 72);
    c.draw(SDF.rect(32, 40, 31, 31, 18), [170, 170, 170]);
    c.draw(SDF.rect(32, 33, 31, 31, 18), W);
    return c;
  },
  circle: () => new Canvas(128, 128).draw(SDF.circle(64, 64, 62), W),
  ring: () => new Canvas(128, 128).draw(SDF.ring(64, 64, 56, 10), W),
  glow: () => {
    const c = new Canvas(128, 128);
    for (let r = 62; r > 2; r -= 2) c.draw(SDF.circle(64, 64, r), W, 0.035);
    return c;
  },
  star: () => icon((c, h) => c.draw(SDF.star(h, h + 3, 44, 19), W)),
  star_slot: () => icon((c, h) => c.draw(SDF.sub(SDF.star(h, h + 3, 44, 19), SDF.star(h, h + 3, 27, 10.5)), W)),
  undo: () => icon((c) => {
    c.draw(SDF.sub(SDF.ring(54, 54, 24, 11), SDF.rect(30, 34, 24, 20)), W);
    c.draw(SDF.rect(49, 30, 6, 5.5), W);
    c.draw(SDF.poly([[14, 30], [42, 10], [42, 50]]), W);
  }),
  trash: () => icon((c) => {
    c.draw(SDF.rect(48, 22, 32, 5, 2.5), W);
    c.draw(SDF.rect(48, 14, 10, 5, 2.5), W);
    c.draw(SDF.sub(SDF.rect(48, 57, 24, 28, 6), SDF.union(SDF.rect(38, 57, 3, 18, 1.5), SDF.rect(48, 57, 3, 18, 1.5), SDF.rect(58, 57, 3, 18, 1.5))), W);
  }),
  play: () => icon((c) => c.draw(SDF.poly([[30, 16], [82, 48], [30, 80]]), W)),
  home: () => icon((c) => {
    c.draw(SDF.poly([[48, 12], [88, 48], [8, 48]]), W);
    c.draw(SDF.sub(SDF.rect(48, 64, 27, 22, 4), SDF.rect(48, 73, 8, 13, 2)), W);
  }),
  sound_on: () => icon((c) => {
    c.draw(SDF.poly([[12, 38], [30, 38], [50, 18], [50, 78], [30, 58], [12, 58]]), W);
    c.draw(SDF.sub(SDF.ring(52, 48, 17, 8), SDF.rect(36, 48, 16, 40)), W);
    c.draw(SDF.sub(SDF.ring(52, 48, 31, 8), SDF.rect(36, 48, 16, 48)), W);
  }),
  sound_off: () => icon((c) => {
    c.draw(SDF.poly([[12, 38], [30, 38], [50, 18], [50, 78], [30, 58], [12, 58]]), W);
    c.draw(SDF.line(60, 34, 84, 62, 10), W);
    c.draw(SDF.line(84, 34, 60, 62, 10), W);
  }),
  lock: () => icon((c) => {
    c.draw(SDF.sub(SDF.ring(48, 38, 17, 10), SDF.rect(48, 58, 30, 14)), W);
    c.draw(SDF.sub(SDF.rect(48, 62, 28, 22, 7), SDF.union(SDF.circle(48, 58, 6), SDF.rect(48, 67, 3, 7, 1.5))), W);
  }),
  back: () => icon((c) => {
    c.draw(SDF.poly([[14, 48], [48, 16], [48, 80]]), W);
    c.draw(SDF.rect(62, 48, 22, 10, 4), W);
  }),
  next: () => icon((c) => {
    c.draw(SDF.poly([[82, 48], [48, 16], [48, 80]]), W);
    c.draw(SDF.rect(34, 48, 22, 10, 4), W);
  }),
  plus: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 32, 8, 4), W);
    c.draw(SDF.rect(48, 48, 8, 32, 4), W);
  }),
  minus: () => icon((c) => c.draw(SDF.rect(48, 48, 32, 8, 4), W)),
  fit: () => icon((c) => {
    const L = (x, y, dx, dy) => c.draw(SDF.union(SDF.rect(x + dx * 9, y, 14, 5.5, 2.5), SDF.rect(x, y + dy * 9, 5.5, 14, 2.5)), W);
    L(18, 18, 1, 1); L(78, 18, -1, 1); L(18, 78, 1, -1); L(78, 78, -1, -1);
  }),
  // light bulb with three short rays
  hint: () => icon((c) => {
    c.draw(SDF.circle(48, 44, 22), W);
    c.draw(SDF.rect(48, 66, 11, 9, 3), W);
    c.draw(SDF.rect(48, 80, 8, 4, 2), W);
    c.erase(SDF.rect(48, 72, 13, 1.5));
    c.erase(SDF.sub(SDF.ring(48, 44, 13, 5), SDF.rect(48, 52, 20, 14)));
    for (const a of [-150, -90, -30]) {
      const r = (a * Math.PI) / 180, cx = 48 + Math.cos(r) * 30, cy = 44 + Math.sin(r) * 30;
      c.draw(SDF.line(cx, cy, 48 + Math.cos(r) * 38, 44 + Math.sin(r) * 38, 7.5), W);
    }
  }),
  retry: () => icon((c) => {
    c.draw(SDF.sub(SDF.ring(48, 50, 26, 11), SDF.poly([[48, 50], [92, 8], [92, 50]])), W);
    c.draw(SDF.poly([[58, 8], [86, 30], [54, 42]]), W);
  }),
  // two-tone coin: bright rim, darker face, bright "$"
  coin: () => icon((c) => {
    c.draw(SDF.circle(48, 48, 40), W);
    c.draw(SDF.circle(48, 48, 30), G2);
    const top = SDF.sub(SDF.ring(48, 40, 9, 6.5), SDF.rect(54, 46, 6, 6));
    const bot = SDF.sub(SDF.ring(48, 56, 9, 6.5), SDF.rect(42, 50, 6, 6));
    c.draw(SDF.union(top, bot, SDF.rect(48, 48, 2.5, 22, 1.2)), W);
  }),
  check: () => icon((c) => c.draw(SDF.union(SDF.line(20, 50, 40, 70, 13), SDF.line(40, 70, 78, 28, 13)), W)),
  close: () => icon((c) => c.draw(SDF.union(SDF.line(24, 24, 72, 72, 13), SDF.line(72, 24, 24, 72, 13)), W)),
  menu: () => icon((c) => {
    for (const y of [26, 48, 70]) c.draw(SDF.rect(48, y, 32, 6, 3), W);
  }),
  stop: () => icon((c) => c.draw(SDF.rect(48, 48, 26, 26, 6), W)),
  // open-jaw spanner
  wrench: () => icon((c) => {
    c.draw(SDF.line(26, 72, 60, 38, 15), W);
    c.draw(SDF.sub(SDF.circle(66, 30, 20), SDF.union(SDF.line(66, 30, 92, 4, 14), SDF.circle(66, 30, 6))), W);
    c.draw(SDF.circle(24, 74, 11), W);
    c.erase(SDF.circle(24, 74, 4));
  }),
  // pedals: gas drives forward (right), brake slows / reverses (left)
  pedal_gas: () => icon((c) => {
    c.draw(chevron(36, 48, 1, 20, 12), W);
    c.draw(chevron(62, 48, 1, 20, 12), W);
  }),
  pedal_brake: () => icon((c) => {
    c.draw(chevron(60, 48, -1, 20, 12), W);
    c.draw(chevron(34, 48, -1, 20, 12), W);
  }),
  // garage: a house with a roller door
  garage: () => icon((c) => {
    c.draw(SDF.poly([[48, 8], [92, 42], [4, 42]]), W);
    c.draw(SDF.rect(48, 62, 34, 24, 4), W);
    c.erase(SDF.rect(48, 70, 22, 16, 2));
    for (const y of [62, 71, 80]) c.draw(SDF.rect(48, y, 20, 2.8, 1.4), W);
  }),
  trophy: () => icon((c) => {
    c.draw(SDF.sub(SDF.poly([[24, 14], [72, 14], [68, 42], [58, 56], [38, 56], [28, 42]]), SDF.star(48, 33, 11, 5)), W);
    c.draw(SDF.sub(SDF.ring(24, 30, 11, 7), SDF.rect(34, 30, 10, 18)), W);
    c.draw(SDF.sub(SDF.ring(72, 30, 11, 7), SDF.rect(62, 30, 10, 18)), W);
    c.draw(SDF.rect(48, 63, 6, 8), W);
    c.draw(SDF.rect(48, 72, 13, 4, 2), W);
    c.draw(SDF.rect(48, 81, 22, 6, 3), W);
  }),
  vibrate_on: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 22, 38, 7), W);
    c.erase(SDF.rect(48, 52, 14, 24, 3));
    c.erase(SDF.circle(48, 19, 3));
    c.draw(SDF.sub(SDF.ring(24, 48, 18, 7), SDF.rect(32, 48, 18, 48)), W);
    c.draw(SDF.sub(SDF.ring(72, 48, 18, 7), SDF.rect(64, 48, 18, 48)), W);
  }),
  vibrate_off: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 22, 38, 7), W);
    c.erase(SDF.rect(48, 52, 14, 24, 3));
    c.erase(SDF.circle(48, 19, 3));
    c.erase(SDF.line(14, 16, 82, 84, 16));
    c.draw(SDF.line(18, 20, 78, 80, 8), W);
  }),
  // rewarded video: a screen with a play button
  video: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 38, 28, 8), W);
    c.erase(SDF.rect(48, 48, 30, 20, 4));
    c.draw(SDF.poly([[40, 35], [63, 48], [40, 61]]), W);
  }),
  // tutorial hand: index finger pointing up
  hand: () => icon((c) => {
    c.draw(SDF.line(40, 16, 40, 54, 17), W);
    c.draw(SDF.rect(54, 66, 22, 20, 10), W);
    c.draw(SDF.circle(56, 48, 8.5), W);
    c.draw(SDF.circle(70, 51, 8), W);
    c.draw(SDF.line(36, 64, 24, 50, 13), W);
  }),
  // ---------------------------------------------------------------- achievements / garage tabs
  bridge: () => icon((c) => {
    c.draw(SDF.rect(48, 64, 43, 6.5, 3), W);
    const top = [[26, 32], [48, 32], [70, 32]], bot = [[8, 64], [37, 64], [59, 64], [88, 64]];
    c.draw(SDF.line(26, 32, 70, 32, 9), W);
    for (let i = 0; i < 3; i++) {
      c.draw(SDF.line(bot[i][0], bot[i][1], top[i][0], top[i][1], 8.5), W);
      c.draw(SDF.line(top[i][0], top[i][1], bot[i + 1][0], bot[i + 1][1], 8.5), W);
    }
    c.draw(SDF.rect(12, 78, 6, 12, 2.5), W);
    c.draw(SDF.rect(84, 78, 6, 12, 2.5), W);
  }),
  // capsule for thin progress bars (slice9 = 6 keeps both ends perfectly round at 12 px)
  pill: () => new Canvas(48, 12).draw(SDF.rect(24, 6, 23.5, 5.5, 5.5), W),
  // a car under a looping arrow: a full flip in the air
  flip: () => icon((c) => {
    c.draw(SDF.sub(SDF.ring(48, 54, 33, 11), SDF.rect(48, 78, 46, 24)), W);
    c.draw(SDF.poly([[70, 50], [92, 50], [81, 68]]), W);
    c.draw(SDF.rect(48, 72, 20, 7, 3.5), W);
    c.draw(SDF.poly([[36, 66], [41, 56], [56, 56], [62, 66]]), W);
    c.draw(SDF.circle(37, 81, 6.5), W);
    c.draw(SDF.circle(59, 81, 6.5), W);
  }),
  // "never give up": a heart
  heart: () => icon((c) => {
    c.draw(SDF.union(SDF.circle(33, 38, 19), SDF.circle(63, 38, 19), SDF.poly([[15, 46], [81, 46], [48, 84]])), W);
  }),
  // "held together by a prayer": a sticking plaster
  bandage: () => icon((c) => {
    c.draw(SDF.line(22, 74, 74, 22, 30), W);
    const d = (r) => SDF.poly([[48, 48 - r], [48 + r, 48], [48, 48 + r], [48 - r, 48]]);
    c.erase(SDF.sub(d(17), d(12.5)));
    for (const [x, y] of [[26, 62], [34, 70], [62, 26], [70, 34]]) c.erase(SDF.circle(x, y, 2.6));
  }),
  truck: () => icon((c) => {
    c.draw(SDF.rect(34, 46, 28, 20, 4), W);
    c.draw(SDF.poly([[64, 30], [80, 30], [90, 46], [90, 66], [64, 66]]), W);
    c.erase(SDF.poly([[68, 35], [78, 35], [85, 46], [68, 46]]));
    c.draw(SDF.rect(48, 66, 44, 4), W);
    for (const x of [20, 40, 78]) {
      c.draw(SDF.circle(x, 74, 11), W);
      c.erase(SDF.circle(x, 74, 4));
    }
  }),
  portal: () => icon((c) => {
    c.draw(eRing(58, 48, 20, 36, 10), W);
    c.draw(eRing(58, 48, 9, 22, 5), W, 0.6);
    c.draw(SDF.line(8, 48, 34, 48, 10), W);
    c.draw(SDF.poly([[30, 34], [50, 48], [30, 62]]), W);
  }),
  flag: () => icon((c) => {
    c.draw(SDF.line(22, 10, 22, 88, 8), W);
    c.draw(SDF.rect(52, 30, 28, 20, 3), W);
    for (let i = 0; i < 4; i++) {
      for (let j = 0; j < 3; j++) {
        if ((i + j) % 2 === 0) c.erase(SDF.rect(31 + i * 14, 17 + j * 13, 5.5, 5));
      }
    }
  }),
  stopwatch: () => icon((c) => {
    c.draw(SDF.ring(48, 54, 30, 10), W);
    c.draw(SDF.rect(48, 14, 9, 5, 2.5), W);
    c.draw(SDF.rect(48, 21, 4, 4), W);
    c.draw(SDF.line(48, 54, 48, 34, 8), W);
    c.draw(SDF.line(48, 54, 62, 62, 7), W);
    c.draw(SDF.line(72, 24, 79, 17, 8), W);
  }),
  nobrake: () => icon((c) => {
    c.draw(SDF.ring(48, 48, 36, 10), W);
    c.draw(chevron(56, 48, -1, 14, 9), W);
    c.draw(chevron(38, 48, -1, 14, 9), W);
    c.erase(SDF.line(18, 18, 78, 78, 16));
    c.draw(SDF.line(22, 22, 74, 74, 9), W);
  }),
  boom: () => icon((c) => {
    c.draw(SDF.star(48, 48, 44, 24, 8, -Math.PI / 2 + 0.2), W);
    c.erase(SDF.star(48, 48, 22, 12, 8, -Math.PI / 2 + 0.2));
    c.draw(SDF.circle(48, 48, 8), W);
  }),
  brush: () => icon((c) => {
    c.draw(SDF.rect(40, 22, 28, 12, 6), W);
    c.draw(SDF.line(68, 22, 84, 22, 6), W);
    c.draw(SDF.line(84, 22, 84, 44, 6), W);
    c.draw(SDF.line(84, 44, 50, 52, 6), W);
    c.draw(SDF.line(50, 52, 50, 86, 13), W);
  }),
  paint: () => icon((c) => {
    c.draw(SDF.union(SDF.circle(48, 58, 26), SDF.poly([[48, 8], [72, 48], [24, 48]])), W);
    c.erase(SDF.sub(SDF.ring(48, 58, 15, 6), SDF.rect(58, 52, 12, 18)));
  }),
  tire: () => icon((c) => {
    c.draw(SDF.ring(48, 48, 32, 18), W);
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2;
      c.erase(SDF.line(48 + Math.cos(a) * 38, 48 + Math.sin(a) * 38, 48 + Math.cos(a) * 44, 48 + Math.sin(a) * 44, 5));
    }
    c.draw(SDF.circle(48, 48, 9), W);
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2 - Math.PI / 2;
      c.draw(SDF.line(48, 48, 48 + Math.cos(a) * 22, 48 + Math.sin(a) * 22, 5), W);
    }
  }),
  // cowboy hat: a tall pinched crown over a short brim with lightly curled ends
  hat: () => icon((c) => {
    c.draw(SDF.rect(48, 40, 20, 25, 9), W);
    c.draw(SDF.union(SDF.line(20, 66, 76, 66, 13), SDF.line(20, 66, 13, 57, 9), SDF.line(76, 66, 83, 57, 9)), W);
    c.erase(SDF.rect(48, 55, 21, 3.2));
    c.erase(SDF.poly([[42, 14], [54, 14], [48, 24]]));
  }),
};

// ------------------------------------------------------------------ rendered item icons
const ROOT = path.resolve(__dirname, "../..");

// game/config/vehicles.lua and skins.lua are the source of truth for wheel positions, mounts, paint
// and toppers. The readers are strict: a config they cannot read fails the build loudly instead of
// silently dropping icons (CRLF / LF and spacing are tolerated).
const lua = (file) => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/\r\n/g, "\n");
const NUM = "(-?[\\d.]+)";

function readVehicles() {
  const src = lua("game/config/vehicles.lua");
  const list = src.slice(src.indexOf("M.list = {"), src.indexOf("M.by_id"));
  const out = {};
  for (const b of list.split(/\n\s*\{\s*\n/).slice(1)) {
    const id = (b.match(/\bid\s*=\s*"(\w+)"/) || [])[1];
    if (!id) continue;
    const wsec = (b.match(/wheels\s*=\s*\{([\s\S]*?)\n\s*\},/) || [])[1] || "";
    const wheels = [...wsec.matchAll(new RegExp(`x\\s*=\\s*${NUM},\\s*y\\s*=\\s*${NUM},\\s*r\\s*=\\s*${NUM}`, "g"))]
      .map((m) => [+m[1], +m[2], +m[3]]);
    const mount = (name) => {
      const m = b.match(new RegExp(`${name}\\s*=\\s*\\{\\s*x\\s*=\\s*${NUM},\\s*y\\s*=\\s*${NUM}\\s*\\}`));
      if (!m) throw new Error(`ui.js: vehicle "${id}" has no ${name} mount in vehicles.lua`);
      return [+m[1], +m[2]];
    };
    const ts = b.match(new RegExp(`topper_scale\\s*=\\s*${NUM}`));
    const pm = b.match(new RegExp(`\\bpaint\\s*=\\s*\\{\\s*${NUM},\\s*${NUM},\\s*${NUM}\\s*\\}`));
    if (!wheels.length || !pm || !ts) throw new Error(`ui.js: could not read wheels / paint / topper_scale of vehicle "${id}"`);
    out[id] = { wheels, paint: [+pm[1], +pm[2], +pm[3]], roof: mount("roof"), rear: mount("rear"), topperScale: +ts[1] };
  }
  if (Object.keys(out).length < 3) throw new Error("ui.js: expected 3 vehicles in vehicles.lua, read " + Object.keys(out).join(","));
  return out;
}

function readToppers() {
  const src = lua("game/config/skins.lua");
  const sec = src.slice(src.indexOf("topper = {"), src.indexOf("M.by_kind"));
  const items = sec.split(/\n\s*\{/).slice(1);
  const toppers = [];
  for (const it of items) {
    const id = (it.match(/\bid\s*=\s*"(\w+)"/) || [])[1];
    const visual = (it.match(/\bvisual\s*=\s*"(\w+)"/) || [])[1];
    const mount = (it.match(/\bmount\s*=\s*"(\w+)"/) || [])[1];
    if (id && visual) {
      if (mount !== "roof" && mount !== "rear") throw new Error(`ui.js: topper "${id}" needs mount = "roof" | "rear"`);
      toppers.push({ id, visual, mount });
    }
  }
  const big = src.match(new RegExp(`id\\s*=\\s*"monster"[^\\n]*?scale\\s*=\\s*${NUM}`));
  if (!toppers.length || !big) throw new Error("ui.js: could not read toppers / the monster wheel scale from skins.lua");
  return { toppers, monsterScale: +big[1] };
}

// the motorbike reads best almost side-on; wide vehicles show a bit of their front
const VEH_YAW = { moto: -0.16, car: -0.3, truck: -0.3 };
const VEH_PITCH = 0.2;

// paint models are neutral grey (main = palette "base", 218/255): this tint maps main grey to white,
// so a GUI colour multiplies it straight to the paint colour (and the world tint is colour / 0.855)
const NEUTRAL = 218 / 255;
const PAINT_WHITE = [1 / NEUTRAL, 1 / NEUTRAL, 1 / NEUTRAL];

function vehicleParts(id, v, opts = {}) {
  const parts = [
    { mesh: ic.model("veh_" + id), layer: "body" },
    { mesh: ic.model("veh_" + id + "_paint"), layer: "paint", tint: opts.paint || PAINT_WHITE },
  ];
  for (const [x, y] of v.wheels) {
    parts.push({ mesh: ic.model("wheel_" + id), layer: "wheel", t: [x, y, 0], s: opts.wheelScale || 1 });
  }
  if (opts.topper) {
    const p = opts.topper.mount === "rear" ? v.rear : v.roof;
    parts.push({ mesh: ic.model(opts.topper.visual), layer: "top", t: [p[0], p[1], 0], s: v.topperScale });
  }
  return parts;
}

// keep only the near half (z > 0) of a model: truss members come in pairs at z = +-1.38
function nearHalf(mesh) {
  const idx = [];
  for (let t = 0; t < mesh.idx.length; t += 3) {
    const a = mesh.idx[t], b = mesh.idx[t + 1], c = mesh.idx[t + 2];
    const z = (mesh.pos[a * 3 + 2] + mesh.pos[b * 3 + 2] + mesh.pos[c * 3 + 2]) / 3;
    if (z > 0) idx.push(a, b, c);
  }
  return { ...mesh, idx };
}

function eraserMesh() {
  const m = new Mesh();
  m.bevelBox(-0.32, 0, 0, 0.66, 0.42, 0.52, 0.07, {
    top: "tail", side: "curb_red", front: "curb_red", back: "anchor_dk", bottom: "anchor_dk", layer: "anchor_dk",
  });
  m.bevelBox(0.32, 0, 0, 0.66, 0.42, 0.52, 0.07, {
    top: "car_lt", side: "bounce", front: "bounce", back: "bounce_dk", bottom: "bounce_dk", layer: "bounce_dk",
  });
  m.boxMM(-0.16, -0.235, -0.285, 0.16, 0.235, 0.285, { top: "white", side: "cloud_sh", front: "white", back: "cloud_sh" });
  m.boxMM(-0.1, -0.05, 0.285, 0.1, 0.05, 0.29, "cable");
  return m;
}

const DECKS = ["road", "steel_road", "boost", "bounce"];
const MEMBERS = { wood: 1.2, steel: 1.2, rope: 1.8, cable: 1.8 };

function materialIcon(id) {
  const beam = ic.model("beam_" + id);
  if (DECKS.includes(id)) {
    const parts = [{ mesh: beam, t: [-0.5, 0, 0] }, { mesh: beam, t: [0.5, 0, 0] }];
    return ic.render(parts, { w: 96, h: 64, outline: 2.5, pad: 2, yaw: -0.5, pitch: 0.55 }).layers.main;
  }
  const len = MEMBERS[id];
  const near = nearHalf(beam);
  // icon exaggeration: a chunkier cross-section than in the world so the member reads at 60 px.
  // Rigid members get their bolt joints; rope and cable stay bare so their own colour dominates.
  const rz = 0.32;
  const dx = Math.cos(rz) * len / 2, dy = Math.sin(rz) * len / 2;
  const flexible = id === "rope" || id === "cable";
  const parts = [{ mesh: near, s: [len, flexible ? 2.6 : 1.8, flexible ? 2.6 : 1], rz }];
  if (!flexible) {
    const joint = nearHalf(ic.model("node_joint"));
    parts.push({ mesh: joint, t: [-dx, -dy, 0], s: 1.3 }, { mesh: joint, t: [dx, dy, 0], s: 1.3 });
  }
  return ic.render(parts, { w: 96, h: 64, outline: 2.5, pad: 2, yaw: -0.25, pitch: 0.2 }).layers.main;
}

function rendered() {
  const out = {};
  const vehicles = readVehicles();
  const { toppers, monsterScale } = readToppers();
  // body + paint share one outer outline (the "sil" ink layer under them); wheels and toppers
  // keep their own outline, which reads as a cartoon line where they cross the body
  const bodyOpts = { silhouettes: { sil: ["body", "paint"] }, noOutline: ["body", "paint"] };
  for (const [id, v] of Object.entries(vehicles)) {
    // compact HUD icon in the factory paint
    const yaw = VEH_YAW[id] === undefined ? -0.3 : VEH_YAW[id];
    const factory = v.paint.map((c) => c / NEUTRAL);
    const r = ic.render(vehicleParts(id, v, { paint: factory }), {
      w: 132, h: 84, outline: 3, pad: 2, yaw, pitch: VEH_PITCH, layers: ["body", "paint", "wheel"], ...bodyOpts,
    });
    out["veh_" + id] = ic.compose([r.layers.sil, r.layers.body, r.layers.paint, r.layers.wheel]);
    // garage preview layers, all in one shared frame so the GUI can stack and tint them:
    // sil, body, paint (white: the GUI colour is the paint), wheel / wheel_xl, topper
    const fit = [...vehicleParts(id, v, { wheelScale: monsterScale })];
    for (const t of toppers) fit.push(vehicleParts(id, v, { topper: t })[v.wheels.length + 2]);
    const o = { w: 208, h: 128, outline: 3.5, pad: 3, yaw, pitch: VEH_PITCH, fit };
    const base = ic.render(vehicleParts(id, v), { ...o, layers: ["body", "paint", "wheel"], ...bodyOpts });
    out[`gv_${id}_sil`] = base.layers.sil;
    out[`gv_${id}_body`] = base.layers.body;
    out[`gv_${id}_paint`] = base.layers.paint;
    out[`gv_${id}_wheel`] = base.layers.wheel;
    out[`gv_${id}_wheel_xl`] = ic.render(vehicleParts(id, v, { wheelScale: monsterScale }), { ...o, layers: ["wheel"] }).layers.wheel;
    for (const t of toppers) {
      out[`gv_${id}_${t.id}`] = ic.render(vehicleParts(id, v, { topper: t }), { ...o, layers: ["top"] }).layers.top;
    }
    // wheel close-up for the garage wheels tab (car / truck wheel models are axle pairs: near tyre only)
    const wheel = ic.model("wheel_" + id);
    out[`gw_${id}`] = ic.render([{ mesh: id === "moto" ? wheel : nearHalf(wheel) }], {
      w: 96, h: 96, outline: 3, pad: 3, yaw: -0.38, pitch: 0.12,
    }).layers.main;
  }
  return out;
}

// Materials and eraser: classic, clear 2.5D/isometric icons preserved from earlier release
const PRESERVED_ICONS = new Set([
  "mat_road", "mat_steel_road", "mat_wood", "mat_steel",
  "mat_rope", "mat_cable", "mat_boost", "mat_bounce",
  "eraser",
]);

// Garage layers share a 208x128 frame but most of it is empty (a topper is a few pixels): store only
// the opaque box and remember where it sits in the frame, so the atlas stays small.
function trim(im) {
  let x0 = im.w, y0 = im.h, x1 = -1, y1 = -1;
  for (let y = 0; y < im.h; y++) {
    for (let x = 0; x < im.w; x++) {
      if (im.data[(y * im.w + x) * 4 + 3] > 0) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) { x0 = 0; y0 = 0; x1 = 0; y1 = 0; }
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const data = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) im.data.copy(data, y * w * 4, ((y0 + y) * im.w + x0) * 4, ((y0 + y) * im.w + x0 + w) * 4);
  return { w, h, data, frame: [x0, y0, im.w, im.h] };
}

// name = { w, h } or, for trimmed frame layers, { w, h, x, y, frame_w, frame_h } (pixels, y down)
function writeSizes(list) {
  let s = "-- Generated by tools/gen/ui.js: pixel size of every UI atlas image (keeps icon aspect ratios).\n" +
    "-- Trimmed garage layers also give their offset inside the shared frame: { w, h, x, y, frame_w, frame_h }.\nreturn {\n";
  for (const im of list) {
    s += im.frame
      ? `\t${im.name} = { ${im.w}, ${im.h}, ${im.frame[0]}, ${im.frame[1]}, ${im.frame[2]}, ${im.frame[3]} },\n`
      : `\t${im.name} = { ${im.w}, ${im.h} },\n`;
  }
  s += "}\n";
  fs.writeFileSync(path.join(ROOT, "gui/icon_sizes.lua"), s, "utf8");
}

function generate(root) {
  const out = [];
  const dir = path.join(root, "assets/images/ui");
  fs.mkdirSync(dir, { recursive: true });
  for (const [name, fn] of Object.entries(GLYPHS)) {
    const c = fn();
    c.save(path.join(dir, name + ".png"));
    out.push({ name, w: c.w, h: c.h });
  }
  for (const [name, full] of Object.entries(rendered())) {
    const im = name.startsWith("gv_") ? trim(full) : full;
    ic.save(path.join(dir, name + ".png"), im);
    out.push({ name, w: im.w, h: im.h, frame: im.frame });
  }
  for (const name of PRESERVED_ICONS) {
    const targetFile = path.join(dir, name + ".png");
    if (fs.existsSync(targetFile)) {
      const buf = fs.readFileSync(targetFile);
      const w = buf.readUInt32BE(16);
      const h = buf.readUInt32BE(20);
      out.push({ name, w, h });
    }
  }
  writeSizes(out);
  return out;
}

module.exports = { generate, GLYPHS, rendered, PRESERVED_ICONS };

if (require.main === module) {
  const list = generate(ROOT);
  require("./defold").atlas(ROOT, list);
  console.log("ui images:", list.length);
}
