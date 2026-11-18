// UI images for the GUI atlas (white shapes tinted in the GUI + colored material icons).
const path = require("path");
const { Canvas, SDF, hex } = require("./png");
const { COLORS } = require("./palette");

const W = [255, 255, 255];
const S = 96; // icon size

function icon(draw) {
  const c = new Canvas(S, S);
  draw(c, S / 2);
  return c;
}

const IMAGES = {
  white: () => {
    const c = new Canvas(8, 8);
    c.draw(() => -10, W);
    return c;
  },
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
  star_slot: () => icon((c, h) => c.draw(SDF.sub(SDF.star(h, h + 3, 44, 19), SDF.star(h, h + 3, 32, 13)), W)),
  undo: () => icon((c, h) => {
    c.draw(SDF.sub(SDF.ring(h + 4, h + 6, 26, 10), SDF.rect(h - 22, h + 20, 22, 18)), W);
    c.draw(SDF.poly([[16, 34], [44, 16], [44, 52]]), W);
  }),
  trash: () => icon((c) => {
    c.draw(SDF.rect(48, 22, 30, 5, 2), W);
    c.draw(SDF.rect(48, 15, 10, 5, 2), W);
    c.draw(SDF.sub(SDF.rect(48, 56, 23, 28, 5), SDF.union(SDF.rect(38, 56, 3, 18), SDF.rect(48, 56, 3, 18), SDF.rect(58, 56, 3, 18))), W);
  }),
  eraser: () => icon((c) => {
    const p = [[20, 62], [52, 22], [80, 44], [50, 82], [32, 82]];
    c.draw(SDF.poly(p), W);
    c.erase(SDF.poly([[22, 62], [36, 45], [58, 64], [47, 78], [33, 78]]));
    c.draw(SDF.rect(60, 84, 26, 3), W);
  }),
  play: () => icon(() => {}).draw(SDF.poly([[30, 18], [80, 48], [30, 78]]), W),
  home: () => icon((c) => {
    c.draw(SDF.poly([[48, 14], [86, 48], [10, 48]]), W);
    c.draw(SDF.sub(SDF.rect(48, 64, 26, 20), SDF.rect(48, 72, 8, 13)), W);
  }),
  sound_on: () => icon((c) => {
    c.draw(SDF.poly([[14, 38], [30, 38], [50, 18], [50, 78], [30, 58], [14, 58]]), W);
    c.draw(SDF.sub(SDF.ring(52, 48, 18, 7), SDF.rect(36, 48, 16, 40)), W);
    c.draw(SDF.sub(SDF.ring(52, 48, 32, 7), SDF.rect(36, 48, 16, 48)), W);
  }),
  sound_off: () => icon((c) => {
    c.draw(SDF.poly([[14, 38], [30, 38], [50, 18], [50, 78], [30, 58], [14, 58]]), W);
    c.draw(SDF.line(60, 34, 84, 62, 8), W);
    c.draw(SDF.line(84, 34, 60, 62, 8), W);
  }),
  lock: () => icon((c) => {
    c.draw(SDF.sub(SDF.ring(48, 38, 18, 9), SDF.rect(48, 56, 30, 14)), W);
    c.draw(SDF.sub(SDF.rect(48, 60, 28, 22, 6), SDF.circle(48, 58, 6)), W);
  }),
  back: () => icon((c) => {
    c.draw(SDF.poly([[18, 48], [50, 18], [50, 78]]), W);
    c.draw(SDF.rect(62, 48, 20, 10), W);
  }),
  next: () => icon((c) => {
    c.draw(SDF.poly([[78, 48], [46, 18], [46, 78]]), W);
    c.draw(SDF.rect(34, 48, 20, 10), W);
  }),
  plus: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 30, 8, 3), W);
    c.draw(SDF.rect(48, 48, 8, 30, 3), W);
  }),
  minus: () => icon((c) => c.draw(SDF.rect(48, 48, 30, 8, 3), W)),
  fit: () => icon((c) => {
    const L = (x, y, dx, dy) => c.draw(SDF.union(SDF.rect(x + dx * 8, y, 12, 5), SDF.rect(x, y + dy * 8, 5, 12)), W);
    L(20, 20, 1, 1); L(76, 20, -1, 1); L(20, 76, 1, -1); L(76, 76, -1, -1);
  }),
  hint: () => icon((c) => {
    c.draw(SDF.circle(48, 40, 24), W);
    c.draw(SDF.rect(48, 66, 12, 10, 3), W);
    c.draw(SDF.rect(48, 82, 9, 4, 2), W);
  }),
  retry: () => icon((c) => {
    c.draw(SDF.sub(SDF.ring(48, 50, 26, 10), SDF.poly([[48, 50], [90, 10], [90, 50]])), W);
    c.draw(SDF.poly([[60, 10], [84, 30], [56, 40]]), W);
  }),
  coin: () => icon((c) => {
    c.draw(SDF.circle(48, 48, 40), W);
    c.erase(SDF.ring(48, 48, 31, 5));
  }),
  check: () => icon((c) => c.draw(SDF.union(SDF.line(20, 50, 40, 70, 13), SDF.line(40, 70, 78, 28, 13)), W)),
  close: () => icon((c) => c.draw(SDF.union(SDF.line(24, 24, 72, 72, 13), SDF.line(72, 24, 24, 72, 13)), W)),
  menu: () => icon((c) => {
    for (const y of [26, 48, 70]) c.draw(SDF.rect(48, y, 32, 6, 3), W);
  }),
  stop: () => icon((c) => c.draw(SDF.rect(48, 48, 26, 26, 6), W)),
  wrench: () => icon((c) => {
    c.draw(SDF.line(30, 66, 64, 32, 14), W);
    c.draw(SDF.sub(SDF.circle(68, 28, 18), SDF.rect(74, 22, 8, 8)), W);
    c.draw(SDF.circle(28, 68, 12), W);
  }),
  pedal_gas: () => icon((c) => {
    c.draw(SDF.poly([[24, 70], [48, 40], [72, 70], [60, 70], [48, 55], [36, 70]]), W);
    c.draw(SDF.poly([[24, 46], [48, 16], [72, 46], [60, 46], [48, 31], [36, 46]]), W);
  }),
  pedal_brake: () => icon((c) => {
    c.draw(SDF.poly([[24, 26], [48, 56], [72, 26], [60, 26], [48, 41], [36, 26]]), W);
    c.draw(SDF.poly([[24, 50], [48, 80], [72, 50], [60, 50], [48, 65], [36, 50]]), W);
  }),
  // vehicle silhouettes (side view, facing right)
  veh_moto: () => icon((c) => {
    c.draw(SDF.ring(24, 66, 13, 7), W);
    c.draw(SDF.ring(72, 66, 13, 7), W);
    c.draw(SDF.poly([[24, 66], [44, 48], [66, 48], [72, 66], [60, 58], [38, 58]]), W);
    c.draw(SDF.rect(42, 34, 8, 12, 4), W);
    c.draw(SDF.circle(48, 22, 8), W);
    c.draw(SDF.line(62, 48, 70, 36, 6), W);
  }),
  veh_car: () => icon((c) => {
    c.draw(SDF.rect(48, 56, 40, 12, 6), W);
    c.draw(SDF.poly([[22, 46], [32, 28], [62, 28], [74, 46]]), W);
    c.erase(SDF.poly([[34, 42], [38, 33], [47, 33], [47, 42]]));
    c.erase(SDF.poly([[51, 42], [51, 33], [60, 33], [66, 42]]));
    c.draw(SDF.circle(28, 70, 11), W);
    c.draw(SDF.circle(68, 70, 11), W);
    c.erase(SDF.circle(28, 70, 4));
    c.erase(SDF.circle(68, 70, 4));
  }),
  veh_truck: () => icon((c) => {
    c.draw(SDF.rect(34, 46, 28, 20, 3), W);
    c.draw(SDF.poly([[64, 30], [80, 30], [90, 46], [90, 66], [64, 66]]), W);
    c.erase(SDF.poly([[68, 34], [78, 34], [85, 46], [68, 46]]));
    c.draw(SDF.rect(48, 66, 44, 4), W);
    for (const x of [18, 36, 78]) {
      c.draw(SDF.circle(x, 74, 10), W);
      c.erase(SDF.circle(x, 74, 4));
    }
  }),
  // garage: a car under a roller door
  garage: () => icon((c) => {
    c.draw(SDF.rect(48, 24, 42, 6, 3), W);
    c.draw(SDF.poly([[10, 42], [10, 22], [86, 22], [86, 42]]), W);
    for (const y of [28, 34, 40]) c.erase(SDF.rect(48, y, 68, 2));
    c.draw(SDF.rect(48, 58, 32, 10, 5), W);
    c.draw(SDF.poly([[24, 68], [32, 56], [62, 56], [72, 68]]), W);
    c.erase(SDF.poly([[34, 65], [38, 59], [46, 59], [46, 65]]));
    c.erase(SDF.poly([[50, 65], [50, 59], [58, 59], [62, 65]]));
    c.draw(SDF.circle(32, 78, 8), W);
    c.draw(SDF.circle(64, 78, 8), W);
    c.erase(SDF.circle(32, 78, 3));
    c.erase(SDF.circle(64, 78, 3));
  }),
  trophy: () => icon((c) => {
    c.draw(SDF.rect(48, 20, 26, 8, 3), W);
    c.draw(SDF.rect(48, 28, 10, 8), W);
    c.draw(SDF.sub(SDF.poly([[26, 34], [70, 34], [64, 60], [54, 68], [42, 68], [32, 60]]),
      SDF.rect(48, 48, 18, 6)), W);
    c.draw(SDF.sub(SDF.ring(22, 40, 14, 6), SDF.rect(32, 40, 14, 26)), W);
    c.draw(SDF.sub(SDF.ring(74, 40, 14, 6), SDF.rect(64, 40, 14, 26)), W);
  }),
  // vibration: a phone with motion waves
  vibrate_on: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 26, 44, 6), W);
    c.erase(SDF.rect(48, 56, 18, 22, 3));
    c.erase(SDF.circle(48, 22, 4));
    c.draw(SDF.sub(SDF.ring(24, 48, 20, 7), SDF.rect(32, 48, 20, 48)), W);
    c.draw(SDF.sub(SDF.ring(72, 48, 20, 7), SDF.rect(64, 48, 20, 48)), W);
  }),
  vibrate_off: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 26, 44, 6), W);
    c.erase(SDF.rect(48, 56, 18, 22, 3));
    c.erase(SDF.circle(48, 22, 4));
    c.erase(SDF.line(16, 18, 80, 82, 10));
  }),
  // rewarded video: a screen with a play button
  video: () => icon((c) => {
    c.draw(SDF.rect(48, 48, 38, 28, 7), W);
    c.erase(SDF.rect(48, 48, 31, 21, 4));
    c.draw(SDF.poly([[40, 36], [62, 48], [40, 60]]), W);
  }),
  // ghost finger / tutorial hand
  hand: () => icon((c) => {
    c.draw(SDF.rect(44, 22, 30, 30, 10), W);       // palm
    c.draw(SDF.rect(44, 58, 12, 34, 6), W);        // index finger
    c.draw(SDF.rect(62, 44, 9, 24, 4.5), W);
    c.draw(SDF.rect(30, 40, 8, 20, 4), W);
    c.erase(SDF.rect(44, 40, 8, 2));                // knuckle line
  }),
};

// Material icons: a beam piece in the material's colors (not tinted).
function matIcon(top, side, extra) {
  const c = new Canvas(96, 64);
  c.draw(SDF.rect(48, 36, 42, 14, 6), hex(COLORS[side]));
  c.draw(SDF.rect(48, 30, 42, 12, 6), hex(COLORS[top]));
  if (extra) extra(c);
  return c;
}
const MAT_ICONS = {
  mat_road: () => matIcon("asphalt", "asphalt_dk", (c) => c.draw(SDF.rect(48, 30, 14, 2), hex(COLORS.lane))),
  mat_steel_road: () => matIcon("steelroad", "steelroad_dk", (c) => {
    for (const x of [24, 40, 56, 72]) c.draw(SDF.rect(x, 30, 2, 10), hex(COLORS.steelroad_dk));
  }),
  mat_boost: () => matIcon("boost", "steelroad_dk", (c) => {
    for (const x of [34, 56]) c.draw(SDF.poly([[x, 21], [x + 6, 21], [x + 16, 30], [x + 6, 39], [x, 39], [x + 10, 30]]), hex(COLORS.boost_arrow));
  }),
  mat_bounce: () => matIcon("bounce_lt", "bounce", (c) => {
    for (const x of [26, 48, 70]) c.draw(SDF.rect(x, 52, 5, 8, 2), hex(COLORS.spring));
  }),
  mat_wood: () => {
    const c = new Canvas(96, 64);
    c.draw(SDF.line(10, 50, 86, 14, 16), hex(COLORS.wood_dk));
    c.draw(SDF.line(10, 46, 86, 10, 12), hex(COLORS.wood));
    return c;
  },
  mat_steel: () => {
    const c = new Canvas(96, 64);
    c.draw(SDF.line(10, 50, 86, 14, 18), hex(COLORS.steel_dk));
    c.draw(SDF.line(10, 46, 86, 10, 10), hex(COLORS.steel));
    return c;
  },
  mat_rope: () => {
    const c = new Canvas(96, 64);
    c.draw(SDF.line(8, 54, 88, 10, 7), hex(COLORS.rope_dk));
    c.draw(SDF.line(8, 52, 88, 8, 4), hex(COLORS.rope));
    return c;
  },
  mat_cable: () => {
    const c = new Canvas(96, 64);
    c.draw(SDF.line(8, 54, 88, 10, 8), hex(COLORS.cable_dk));
    c.draw(SDF.line(8, 52, 88, 8, 5), hex(COLORS.cable));
    return c;
  },
};

const fs = require("fs");

const UI_SIZES = {
  white: [8, 8],
  panel: [64, 64],
  btn: [64, 72],
  circle: [128, 128],
  ring: [128, 128],
  glow: [128, 128],
};

const TWODOTS_UI = new Set([
  // Primitives
  "white", "panel", "btn", "circle", "ring", "glow",
  // Materials
  "mat_road", "mat_steel_road", "mat_wood", "mat_steel",
  "mat_cable", "mat_rope", "mat_boost", "mat_bounce",
  // Vehicles & controls
  "veh_moto", "veh_car", "veh_truck", "pedal_gas", "pedal_brake",
  // Tools & actions
  "wrench", "eraser", "trash", "undo", "fit", "hint",
  // Rewards & meta
  "coin", "star", "star_slot", "trophy", "garage", "lock",
  // Navigation
  "play", "stop", "retry", "next", "back", "home", "menu", "close",
  // Settings, gestures & math
  "check", "hand", "video", "sound_on", "sound_off", "vibrate_on", "vibrate_off", "plus", "minus"
]);

function generate(root) {
  const out = [];
  const dir = path.join(root, "assets/images/ui");
  for (const [name, fn] of Object.entries({ ...IMAGES, ...MAT_ICONS })) {
    const targetFile = path.join(dir, name + ".png");
    if (TWODOTS_UI.has(name) && fs.existsSync(targetFile)) {
      const sz = UI_SIZES[name] || (name.startsWith("mat_") ? [96, 64] : [96, 96]);
      out.push({ name, w: sz[0], h: sz[1] });
      continue;
    }
    const c = fn();
    c.save(targetFile);
    out.push({ name, w: c.w, h: c.h });
  }
  return out;
}

module.exports = { generate };
