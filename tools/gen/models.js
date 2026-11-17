// Procedural voxel models. Every model is one glTF in assets/models/<id>.gltf.
// Conventions (must match the Lua side):
//   beams      unit length along x (-0.5..0.5); the game scales x by the beam length
//   decks      thickness 0.3 (2 * DECK_HALF), width along z 2.6
//   trusses    two parallel members at z = +-1.38 (both sides of the deck)
//   vehicles   origin = physics body center, wheels are separate models
//   terrain    unit cubes / slabs, tinted per theme at runtime (base colors are near white)
const { Mesh } = require("./mesh");

const M = {};
const T = 0.15; // DECK_HALF
const DZ = 1.3; // deck half width
const TZ = 1.38; // truss member z (outside the deck so vehicles never clip them)

// ------------------------------------------------------------------ helpers
function deck(top, side, under, opts) {
  opts = opts || {};
  const m = new Mesh();
  const w = opts.w || DZ;
  m.boxMM(-0.5, -T, -w, 0.5, T, w, { top, side, front: side, back: side, bottom: under || side });
  // side fascia panel
  m.boxMM(-0.5, -T + 0.02, -w - 0.02, 0.5, T - 0.02, -w, side);
  m.boxMM(-0.5, -T + 0.02, w, 0.5, T - 0.02, w + 0.02, side);
  // two main girders under the slab
  for (const z of [-w + 0.22, w - 0.22]) {
    m.boxMM(-0.5, -T - 0.18, z - 0.07, 0.5, -T, z + 0.07, under || side);
  }
  // cross braces
  for (const x of [-0.37, 0, 0.37]) {
    m.boxMM(x - 0.05, -T - 0.16, -w + 0.3, x + 0.05, -T - 0.02, w - 0.3, under || side);
  }
  return m;
}

function endPlates(m, mat, halfY) {
  halfY = halfY || 0.16;
  for (const s of [1, -1]) {
    const x0 = s > 0 ? 0.46 : -0.5, x1 = s > 0 ? 0.5 : -0.46;
    m.boxMM(x0, -halfY, -1.18, x1, halfY, 1.18, mat);
    for (const z of [-0.72, 0.72]) {
      const zx = z - 0.035, zz = z + 0.035;
      m.boxMM(s > 0 ? 0.5 : -0.5, -0.05, zx, s > 0 ? 0.505 : -0.505, 0.03, zz, "bolt_lt");
    }
  }
}

function pair(fn) {
  const m = new Mesh();
  fn(m, TZ);
  fn(m, -TZ);
  return m;
}

// ------------------------------------------------------------------ beams
M.beam_road = () => {
  const m = deck("asphalt", "asphalt_dk");
  // worn wheel tracks
  for (const z of [-0.66, 0.66]) m.boxMM(-0.5, T, z - 0.26, 0.5, T + 0.006, z + 0.26, "asphalt_lt");
  // one centre dash per metre (the model repeats along the whole span)
  m.boxMM(-0.3, T + 0.008, -0.055, 0.06, T + 0.02, 0.055, "lane");
  // two short edge dashes
  for (const z of [-0.97, 0.97]) {
    m.boxMM(-0.3, T + 0.007, z - 0.035, 0.02, T + 0.018, z + 0.035, "lane_w");
  }
  // curbs: white base with red stripes and a raised outer lip
  for (const s of [1, -1]) {
    const za = s > 0 ? DZ : -DZ, zb = s > 0 ? DZ - 0.19 : -DZ + 0.19;
    const z0 = Math.min(za, zb), z1 = Math.max(za, zb);
    m.boxMM(-0.5, T, z0, 0.5, T + 0.095, z1, "curb");
    for (let i = 1; i < 2; i++) {
      m.boxMM(-0.5 + i * 0.5, T + 0.095, z0, -0.5 + (i + 1) * 0.5, T + 0.1, z1, "curb_red");
    }
    for (const x of [-0.38, 0.38]) {
      m.boxMM(x - 0.03, T + 0.1, s > 0 ? DZ - 0.14 : -DZ + 0.055, x + 0.03, T + 0.125, s > 0 ? DZ - 0.055 : -DZ + 0.14, "reflect");
    }
  }
  endPlates(m, "steel_dk", 0.2);
  return m;
};

M.beam_steel_road = () => {
  const m = deck("steelroad", "steelroad_dk");
  // plate seams
  for (const x of [-0.25, 0, 0.25]) {
    m.boxMM(x - 0.012, T + 0.002, -DZ, x + 0.012, T + 0.012, DZ, "steelroad_dk");
  }
  // diamond anti-slip studs
  for (let i = 0; i < 4; i++) {
    for (let k = 0; k < 4; k++) {
      const x = -0.36 + i * 0.24, z = -0.76 + k * 0.5 + (i % 2) * 0.12;
      m.boxMM(x - 0.035, T + 0.012, z - 0.035, x + 0.035, T + 0.03, z + 0.035, "steelroad_lt");
    }
  }
  // guard rails
  for (const s of [1, -1]) {
    const z = s * (DZ - 0.08);
    m.boxMM(-0.5, T, z - 0.03, 0.5, T + 0.3, z + 0.03, "steelroad_dk");
    for (const x of [-0.42, 0, 0.42]) {
      m.boxMM(x - 0.035, T, z - 0.06, x + 0.035, T + 0.36, z + 0.06, "steelroad_dk");
      m.boxMM(x - 0.045, T + 0.34, z - 0.07, x + 0.045, T + 0.38, z + 0.07, "steelroad_lt");
    }
  }
  endPlates(m, "steelroad_dk", 0.2);
  return m;
};

M.beam_boost = () => {
  const m = deck("boost_dk", "boost_dk");
  // glowing surface plates
  m.boxMM(-0.48, T, -DZ + 0.12, 0.48, T + 0.025, DZ - 0.12, "boost");
  for (const z of [-0.62, 0.62]) m.boxMM(-0.48, T + 0.025, z - 0.16, 0.48, T + 0.035, z + 0.16, "boost_lt");
  // three forward chevrons
  for (const x of [-0.3, 0.02, 0.34]) {
    const pts = [
      [x - 0.16, -0.66], [x - 0.02, -0.66], [x + 0.2, 0],
      [x - 0.02, 0.66], [x - 0.16, 0.66], [x + 0.04, 0],
    ];
    m.prismY(pts, T + 0.03, T + 0.06, { top: "boost_arrow", side: "boost_dk", bottom: "boost_dk" });
  }
  // hazard side rails
  for (const s of [1, -1]) {
    const z0 = s > 0 ? DZ - 0.14 : -DZ, z1 = s > 0 ? DZ : -DZ + 0.14;
    for (let i = 0; i < 4; i++) {
      const x = -0.5 + i * 0.25;
      m.boxMM(x, T + 0.02, z0, x + 0.125, T + 0.12, z1, "boost_arrow");
      m.boxMM(x + 0.125, T + 0.02, z0, x + 0.25, T + 0.12, z1, "hazard");
    }
  }
  return m;
};

M.beam_bounce = () => {
  const m = deck("bounce_dk", "bounce_dk");
  // cushion (low enough that the wheels only sink a little into it)
  m.bevelBox(0, T + 0.045, 0, 0.96, 0.14, 2.46, 0.028, {
    top: "bounce_lt", side: "bounce", bottom: "bounce_dk", layer: "bounce_dk",
  });
  for (const x of [-0.3, -0.1, 0.1, 0.3]) {
    m.boxMM(x - 0.035, T + 0.105, -1.15, x + 0.035, T + 0.115, 1.15, "white");
  }
  // springs underneath
  for (const x of [-0.32, 0, 0.32]) {
    for (const s of [1, -1]) {
      const z = s * (DZ - 0.22);
      for (let i = 0; i < 4; i++) {
        m.boxMM(x - 0.07, -T - 0.07 - i * 0.075, z - 0.07, x + 0.07, -T - i * 0.075, z + 0.07, i % 2 ? "spring_dk" : "spring");
      }
      m.boxMM(x - 0.1, -T - 0.34, z - 0.1, x + 0.1, -T - 0.29, z + 0.1, "steel_dk");
    }
  }
  return m;
};

M.beam_wood = () => pair((m, z) => {
  m.bevelBox(0, 0, z, 1.0, 0.28, 0.28, 0.035, {
    top: "wood_lt", side: "wood", front: "wood", back: "wood", bottom: "wood_dk", layer: "wood_dk",
  });
  // grain
  for (const y of [-0.065, 0.015]) m.boxMM(-0.36, y, z + 0.14, 0.36, y + 0.012, z + 0.142, "wood_grain");
  // iron end bands + bolts
  for (const s of [1, -1]) {
    const x0 = s > 0 ? 0.42 : -0.5, x1 = s > 0 ? 0.5 : -0.42;
    m.boxMM(x0, -0.15, z - 0.15, x1, 0.15, z + 0.15, "bolt_dk");
    for (const y of [-0.08, 0.08]) {
      m.boxMM(s > 0 ? 0.5 : -0.505, y - 0.028, z - 0.028, s > 0 ? 0.505 : -0.5, y + 0.028, z + 0.028, "bolt_lt");
    }
  }
});

M.beam_steel = () => pair((m, z) => {
  m.boxMM(-0.5, 0.095, z - 0.13, 0.5, 0.17, z + 0.13, { top: "steel_lt", side: "steel" });
  m.boxMM(-0.5, -0.17, z - 0.13, 0.5, -0.095, z + 0.13, { top: "steel", side: "steel_dk" });
  m.boxMM(-0.5, -0.095, z - 0.045, 0.5, 0.095, z + 0.045, "steel_dk");
  // rivets on the web
  for (const x of [-0.36, -0.12, 0.12, 0.36]) {
    m.boxMM(x - 0.022, -0.022, z + 0.045, x + 0.022, 0.022, z + 0.062, "rivet");
  }
  // end plates
  for (const s of [1, -1]) {
    const x0 = s > 0 ? 0.455 : -0.5, x1 = s > 0 ? 0.5 : -0.455;
    m.boxMM(x0, -0.18, z - 0.15, x1, 0.18, z + 0.15, "steel_dk");
  }
});

M.beam_rope = () => pair((m, z) => {
  m.boxMM(-0.5, -0.045, z - 0.045, 0.5, 0.045, z + 0.045, { top: "rope_lt", side: "rope", front: "rope", back: "rope_dk" });
  // braided wraps
  for (let i = 0; i < 7; i++) {
    const x = -0.38 + i * 0.126;
    m.boxRotZ(x, 0, z, 0.13, 0.105, 0.105, i % 2 ? 0.32 : -0.32, "rope_dk");
  }
  // thimbles and end knots
  for (const s of [1, -1]) {
    const x0 = s > 0 ? 0.4 : -0.5, x1 = s > 0 ? 0.5 : -0.4;
    m.boxMM(x0, -0.12, z - 0.12, x1, 0.12, z + 0.12, "bolt_dk");
    m.boxMM(s > 0 ? 0.5 : -0.51, -0.028, z - 0.028, s > 0 ? 0.51 : -0.5, 0.028, z + 0.028, "bolt_lt");
  }
});

M.beam_cable = () => pair((m, z) => {
  // three bright strands wrapped into one cable
  m.boxMM(-0.5, -0.02, z - 0.06, 0.5, 0.02, z + 0.06, { top: "cable_lt", side: "cable", front: "cable", back: "cable_dk" });
  m.boxMM(-0.5, 0.02, z - 0.03, 0.5, 0.06, z + 0.015, "cable");
  m.boxMM(-0.5, -0.06, z - 0.015, 0.5, -0.02, z + 0.03, "cable_dk");
  // clamps
  for (const x of [-0.3, 0, 0.3]) {
    m.boxMM(x - 0.025, -0.085, z - 0.085, x + 0.025, 0.085, z + 0.085, "bolt_dk");
    m.boxMM(x - 0.012, -0.028, z + 0.085, x + 0.012, 0.028, z + 0.095, "bolt_lt");
  }
  for (const s of [1, -1]) {
    m.boxMM(s > 0 ? 0.42 : -0.5, -0.1, z - 0.1, s > 0 ? 0.5 : -0.42, 0.1, z + 0.1, "bolt_dk");
  }
});

// ------------------------------------------------------------------ joints
M.node_joint = () => {
  const m = new Mesh();
  m.boxMM(-0.055, -0.055, -1.46, 0.055, 0.055, 1.46, "bolt_dk");
  for (const s of [1, -1]) {
    const z = s * TZ;
    m.cylinder(0, 0, 0.19, z - 0.1, z + 0.1, 8, { cap: "bolt", side: "bolt_dk" });
    m.cylinder(0, 0, 0.125, z + s * 0.1, z + s * 0.13, 8, { cap: "bolt_lt", side: "bolt" });
    m.cylinder(0, 0, 0.06, z + s * 0.13, z + s * 0.17, 6, { cap: "chrome", side: "chrome_dk" });
    for (let i = 0; i < 4; i++) {
      const a = (i / 4) * Math.PI * 2 + Math.PI / 4;
      const x = Math.cos(a) * 0.135, y = Math.sin(a) * 0.135;
      m.boxMM(x - 0.022, y - 0.022, z + s * 0.1, x + 0.022, y + 0.022, z + s * 0.135, "bolt_dk");
    }
  }
  return m;
};

M.node_anchor = () => {
  const m = new Mesh();
  m.boxMM(-0.07, -0.07, -1.48, 0.07, 0.07, 1.48, "anchor_dk");
  for (const s of [1, -1]) {
    const z = s * TZ;
    m.bevelBox(0, 0, z, 0.56, 0.56, 0.24, 0.035, {
      top: "anchor_lt", side: "anchor", front: "anchor", back: "anchor_dk", bottom: "anchor_dk", layer: "anchor_dk",
    });
    m.boxMM(-0.16, -0.16, z + s * 0.12, 0.16, 0.16, z + s * 0.17, "anchor_lt");
    m.boxMM(-0.06, -0.06, z + s * 0.17, 0.06, 0.06, z + s * 0.2, "anchor_dk");
    for (const dx of [-0.2, 0.2]) {
      for (const dy of [-0.2, 0.2]) {
        m.boxMM(dx - 0.035, dy - 0.035, z + s * 0.12, dx + 0.035, dy + 0.035, z + s * 0.16, "bolt_lt");
      }
    }
    // gusset toward the centre
    m.prism([[-0.26, -0.26], [0.26, -0.26], [0.26, 0.24]], z - 0.1, z + 0.1, "anchor_dk");
  }
  return m;
};

// ------------------------------------------------------------------ vehicles
M.veh_moto = () => {
  const m = new Mesh();
  // frame and swingarm
  m.prism([[-0.56, 0.02], [-0.32, -0.12], [-0.5, -0.16], [-0.62, -0.04]], -0.06, 0.06, "chrome_dk");
  m.prism([[-0.24, 0.14], [0.32, 0.24], [0.36, 0.16], [-0.2, 0.02]], -0.05, 0.05, "moto_dk");
  // engine with fins
  m.boxMM(-0.2, -0.33, -0.17, 0.2, -0.03, 0.17, "black");
  for (const y of [-0.3, -0.25, -0.2, -0.15]) {
    m.boxMM(-0.17, y - 0.018, -0.19, 0.19, y + 0.018, 0.19, "chrome_dk");
  }
  m.boxMM(-0.23, -0.16, -0.07, 0.06, 0.08, 0.07, "chrome");
  // fuel tank
  m.bevelBox(0.03, 0.18, 0, 0.48, 0.26, 0.34, 0.04, {
    top: "moto_lt", side: "moto", front: "moto", back: "moto_dk", bottom: "moto_dk", layer: "moto_dk",
  });
  m.boxMM(-0.12, 0.32, -0.18, 0.16, 0.34, 0.18, "moto_lt");
  // seat and tail
  m.bevelBox(-0.27, 0.27, 0, 0.42, 0.12, 0.32, 0.03, { top: "black", side: "black", bottom: "black", layer: "tire_lt" });
  m.bevelBox(-0.55, 0.2, 0, 0.24, 0.2, 0.28, 0.03, { top: "moto", side: "moto_dk", bottom: "moto_dk", layer: "moto_dk" });
  m.boxMM(-0.68, 0.18, -0.05, -0.64, 0.26, 0.05, "tail");
  // rear fender
  m.boxMM(-0.82, 0.0, -0.11, -0.44, 0.12, 0.11, "moto");
  m.boxMM(-0.82, 0.0, -0.115, -0.44, 0.04, 0.115, "moto_dk");
  // front fork and fender
  m.prism([[0.36, 0.34], [0.66, -0.3], [0.72, -0.26], [0.42, 0.38]], -0.08, -0.03, "chrome");
  m.prism([[0.36, 0.34], [0.66, -0.3], [0.72, -0.26], [0.42, 0.38]], 0.03, 0.08, "chrome");
  m.boxMM(0.44, 0.02, -0.115, 0.84, 0.12, 0.115, "moto");
  m.boxMM(0.44, 0.02, -0.12, 0.84, 0.05, 0.12, "moto_dk");
  // handlebar, grips, mirrors
  m.boxMM(0.34, 0.38, -0.06, 0.48, 0.45, 0.06, "black");
  m.boxMM(0.4, 0.4, -0.34, 0.5, 0.45, 0.34, "black");
  for (const s of [1, -1]) {
    const z0 = s > 0 ? 0.24 : -0.36, z1 = s > 0 ? 0.36 : -0.24;
    m.boxMM(0.38, 0.38, z0, 0.51, 0.46, z1, "rubber");
    m.boxMM(0.48, 0.5, s > 0 ? 0.27 : -0.31, 0.5, 0.56, s > 0 ? 0.33 : -0.27, "chrome_dk");
    m.boxMM(0.47, 0.53, s > 0 ? 0.265 : -0.335, 0.51, 0.59, s > 0 ? 0.335 : -0.265, "glass");
  }
  // headlight
  m.boxMM(0.5, 0.28, -0.09, 0.62, 0.4, 0.09, "chrome_dk");
  m.boxMM(0.6, 0.29, -0.07, 0.64, 0.38, 0.07, "light");
  // exhaust
  m.boxMM(-0.62, -0.26, 0.16, 0.06, -0.19, 0.24, "chrome");
  m.boxMM(-0.7, -0.28, 0.15, -0.58, -0.17, 0.25, "chrome_dk");
  // footpegs
  for (const s of [1, -1]) m.boxMM(-0.16, -0.12, s * 0.18, 0.02, -0.07, s * 0.3, "chrome_dk");
  // rider: legs
  for (const s of [1, -1]) {
    const z = s * 0.23;
    m.boxRotZ(-0.02, 0.08, z, 0.42, 0.2, 0.2, 0.42, "rider_dk");
    m.boxRotZ(0.12, -0.16, z, 0.16, 0.36, 0.18, -0.18, "rider");
    m.boxRotZ(0.18, -0.28, z, 0.24, 0.14, 0.16, 0.06, "black");
  }
  // torso (leaning forward)
  m.prism([[-0.3, 0.31], [-0.02, 0.33], [0.2, 0.66], [-0.14, 0.72]], -0.2, 0.2, {
    cap: "rider", side: (a, b) => (b[1] > 0.15 && a[1] > 0.1 ? "rider" : "rider_dk"),
  });
  m.boxMM(-0.14, 0.38, -0.21, 0.08, 0.48, 0.21, "rider_lt");
  // arms
  for (const s of [1, -1]) {
    m.boxRotZ(0.24, 0.54, s * 0.24, 0.54, 0.13, 0.13, -0.55, "rider");
    m.boxRotZ(0.42, 0.45, s * 0.285, 0.15, 0.1, 0.11, -0.55, "skin");
  }
  // helmet and visor
  m.bevelBox(0.12, 0.82, 0, 0.3, 0.28, 0.3, 0.035, {
    top: "helmet", side: "helmet_dk", front: "helmet", back: "helmet_dk", bottom: "helmet_dk", layer: "helmet_dk",
  });
  m.boxMM(0.26, 0.79, -0.12, 0.29, 0.88, 0.12, "glass_dk");
  m.boxMM(0.23, 0.93, -0.045, 0.29, 0.955, 0.045, "helmet_dk");
  return m;
};

M.veh_car = () => {
  const m = new Mesh();
  // lower body
  m.bevelBox(0, -0.07, 0, 2.5, 0.5, 1.8, 0.09, {
    top: "car", side: "car", front: "car", back: "car", bottom: "car_dk", layer: "car_dk",
  });
  // bonnet and boot
  m.prism([[0.5, 0.16], [1.25, 0.16], [1.25, 0.22], [0.5, 0.29]], -0.88, 0.88, { cap: "car", side: "car" });
  m.prism([[-1.25, 0.16], [-0.78, 0.16], [-0.78, 0.27], [-1.25, 0.22]], -0.88, 0.88, { cap: "car", side: "car" });
  // cabin greenhouse: glass sides, car roof and pillar structure added on top
  m.prism([[-0.86, 0.17], [0.58, 0.17], [0.27, 0.73], [-0.64, 0.73]], -0.79, 0.79, {
    cap: "glass",
    side: (a, b) => {
      const top = a[1] > 0.7 && b[1] > 0.7;
      const bottom = a[1] < 0.2 && b[1] < 0.2;
      return top || bottom ? "car" : "glass_dk";
    },
  });
  // roof panel + pillars
  m.boxMM(-0.66, 0.73, -0.72, 0.29, 0.8, 0.72, { top: "car_lt", side: "car", front: "car", back: "car" });
  m.boxMM(-0.9, 0.15, -0.83, 0.62, 0.23, 0.83, "car");
  for (const s of [1, -1]) {
    const z = s * 0.805;
    m.boxMM(-0.1, 0.2, z - 0.018, 0.02, 0.76, z + 0.018, "car_dk"); // B pillar
    m.boxMM(-0.88, 0.2, z - 0.018, -0.74, 0.7, z + 0.018, "car_dk"); // C pillar
    m.boxMM(0.25, 0.2, z - 0.018, 0.58, 0.55, z + 0.018, "car_dk"); // A pillar
    m.boxMM(-0.62, 0.7, z - 0.018, 0.27, 0.76, z + 0.018, "car_dk");
    // mirrors
    m.boxMM(0.48, 0.28, z + s * 0.05, 0.62, 0.4, z + s * 0.14, "car_dk");
    m.boxMM(0.49, 0.3, z + s * 0.14, 0.58, 0.38, z + s * 0.16, "glass_dk");
    // door seam + handle
    m.boxMM(-0.02, -0.3, z + 0.005, 0.0, 0.42, z + 0.016, "car_dk");
    m.boxMM(0.06, 0.06, z + 0.012, 0.24, 0.1, z + 0.026, "chrome_dk");
    // side skirt and stripe
    m.boxMM(-1.2, -0.33, z + 0.005, 1.2, -0.18, z + 0.03, "car_dk");
    m.boxMM(-1.12, -0.04, z + 0.012, 1.05, 0.015, z + 0.022, "car_dk");
  }
  // bumpers
  m.boxMM(1.22, -0.32, -0.9, 1.34, -0.02, 0.9, "car_dk");
  m.boxMM(-1.34, -0.32, -0.9, -1.22, -0.02, 0.9, "car_dk");
  m.boxMM(1.3, -0.22, -0.55, 1.36, -0.12, 0.55, "black");
  m.boxMM(-1.36, -0.18, -0.4, -1.3, -0.08, 0.4, "chrome_dk");
  // grille + lights
  m.boxMM(1.3, -0.13, -0.42, 1.34, 0.1, 0.42, "grille");
  for (const y of [-0.06, 0.01, 0.08]) m.boxMM(1.34, y - 0.012, -0.4, 1.36, y + 0.012, 0.4, "chrome_dk");
  for (const z of [-0.72, 0.72]) {
    m.boxMM(1.3, 0.0, z - 0.14, 1.36, 0.12, z + 0.14, "light");
    m.boxMM(-1.34, 0.0, z - 0.15, -1.28, 0.1, z + 0.15, "tail");
  }
  // roof rails + crossbars (not a solid plate)
  for (const z of [-0.48, 0.48]) m.boxMM(-0.58, 0.8, z - 0.04, 0.2, 0.87, z + 0.04, "black");
  for (const x of [-0.5, 0.1]) m.boxMM(x - 0.035, 0.81, -0.48, x + 0.035, 0.85, 0.48, "chrome_dk");
  // exhaust
  m.boxMM(-1.38, -0.3, -0.42, -1.28, -0.24, -0.32, "chrome_dk");
  return m;
};

M.veh_truck = () => {
  const m = new Mesh();
  // chassis rails
  m.boxMM(-2.06, -0.52, -0.86, 2.06, -0.4, 0.86, "black");
  for (const x of [-1.8, -0.8, 0.2, 1.4]) m.boxMM(x - 0.05, -0.56, -0.8, x + 0.05, -0.4, 0.8, "steel_dk");
  // cab lower
  m.bevelBox(1.48, -0.03, 0, 1.18, 0.78, 2.0, 0.07, {
    top: "truck", side: "truck", front: "truck", back: "truck_dk", bottom: "truck_dk", layer: "truck_dk",
  });
  // bonnet / grille block
  m.bevelBox(2.0, 0.0, 0, 0.22, 0.5, 1.7, 0.04, { top: "truck_lt", side: "truck_dk", front: "truck_dk", bottom: "truck_dk" });
  // cab greenhouse
  m.prism([[0.93, 0.36], [2.02, 0.36], [1.92, 0.98], [0.93, 0.98]], -0.96, 0.96, {
    cap: "truck_dk",
    side: (a, b) => (b[0] > 1.9 && a[0] > 1.9 ? "glass_dk" : "truck_dk"),
  });
  // windscreen and side windows
  m.boxMM(1.75, 0.45, -0.9, 1.95, 0.92, 0.9, "glass");
  for (const s of [1, -1]) {
    const z = s * 0.965;
    m.boxMM(1.08, 0.46, z - 0.012, 1.68, 0.9, z + 0.012, "glass");
    m.boxMM(1.36, 0.44, z - 0.018, 1.42, 0.93, z + 0.018, "truck_dk");
    m.boxMM(1.02, 0.38, z - 0.02, 1.08, 0.46, z + 0.02, "truck_dk");
    // door seam, handle, step
    m.boxMM(1.03, -0.4, z + 0.005, 1.05, 0.36, z + 0.02, "truck_dk");
    m.boxMM(1.16, 0.06, z + 0.02, 1.34, 0.11, z + 0.05, "chrome_dk");
    m.boxMM(1.02, -0.44, z + 0.02, 1.3, -0.38, z + 0.14, "steel_dk");
    // mirror arm and glass
    m.boxMM(1.8, 0.62, z + 0.03, 1.9, 0.7, z + s * 0.05, "truck_dk");
    m.boxMM(1.76, 0.48, z + s * 0.05, 1.9, 0.76, z + s * 0.1, "truck_dk");
    m.boxMM(1.77, 0.5, z + s * 0.1, 1.89, 0.74, z + s * 0.12, "glass_dk");
  }
  // roof, marker lights
  m.boxMM(0.9, 0.98, -0.96, 1.94, 1.05, 0.96, { top: "truck_lt", side: "truck" });
  for (const z of [-0.7, -0.35, 0, 0.35, 0.7]) m.boxMM(1.9, 0.92, z - 0.05, 1.95, 1.0, z + 0.05, "light");
  // grille, bumper, lights
  m.boxMM(2.1, -0.28, -0.62, 2.14, 0.24, 0.62, "grille");
  for (const y of [-0.2, -0.1, 0, 0.1, 0.2]) m.boxMM(2.14, y - 0.018, -0.6, 2.16, y + 0.018, 0.6, "chrome_dk");
  m.boxMM(2.06, -0.42, -0.98, 2.18, -0.24, 0.98, "chrome");
  for (const z of [-0.82, -0.62, 0.62, 0.82]) {
    m.boxMM(2.14, -0.1, z - 0.1, 2.2, 0.1, z + 0.1, "light");
  }
  // fuel tank + battery box
  m.boxMM(-0.1, -0.4, 0.98, 0.8, -0.14, 1.12, "chrome");
  for (const x of [0.05, 0.65]) m.boxMM(x - 0.03, -0.41, 0.97, x + 0.03, -0.13, 1.13, "chrome_dk");
  m.boxMM(-0.7, -0.4, 0.98, -0.15, -0.2, 1.1, "cargo_lt");
  // exhaust stacks (behind cab)
  for (const s of [1, -1]) {
    const z = s * 0.88;
    m.boxMM(0.82, 0.38, z - 0.07, 0.96, 1.4, z + 0.07, "chrome");
    m.boxMM(0.82, 0.3, z - 0.08, 0.96, 0.4, z + 0.08, "chrome_dk");
    m.boxMM(0.8, 1.38, z - 0.09, 0.98, 1.44, z + 0.09, "chrome_dk");
  }
  // cargo container
  m.bevelBox(-0.6, 0.29, 0, 2.9, 1.46, 2.06, 0.08, {
    top: "cargo_lt", side: "cargo", front: "cargo", back: "cargo_dk", bottom: "cargo_dk", layer: "cargo_dk",
  });
  for (let x = -1.95; x < 0.78; x += 0.34) {
    for (const s of [1, -1]) {
      m.boxMM(x - 0.035, -0.38, s > 0 ? 1.03 : -1.08, x + 0.035, 0.98, s > 0 ? 1.08 : -1.03, "cargo_dk");
    }
  }
  m.boxMM(-2.08, -0.4, -1.03, 0.85, -0.36, 1.03, "cargo_dk");
  m.boxMM(-2.12, -0.38, -1.02, -2.05, 1.0, 1.02, "cargo");
  for (const z of [-0.5, 0, 0.5]) m.boxMM(-2.14, -0.36, z - 0.025, -2.09, 0.98, z + 0.025, "cargo_dk");
  for (const z of [-0.85, 0.85]) m.boxMM(-2.16, 0.5, z - 0.07, -2.08, 0.88, z + 0.07, "steel_dk");
  m.boxMM(-2.16, 0.55, -0.98, -2.1, 0.72, -0.8, "tail");
  m.boxMM(-2.16, 0.55, 0.8, -2.1, 0.72, 0.98, "tail");
  // mudflaps
  for (const x of [-1.55, -0.5, 1.45]) {
    for (const s of [1, -1]) {
      m.boxMM(x - 0.26, -0.62, s * 0.86 - 0.02, x + 0.26, -0.36, s * 0.86 + 0.02, "rubber");
    }
  }
  return m;
};

function wheel(r, zs, width, treads) {
  const m = new Mesh();
  for (const z of zs) {
    const z0 = z - width / 2, z1 = z + width / 2;
    m.cylinder(0, 0, r, z0, z1, 18, { cap: "tire", side: "tire" });
    // tread blocks
    for (let i = 0; i < treads; i++) {
      const a = (i / treads) * Math.PI * 2;
      m.boxRotZ(Math.cos(a) * (r - 0.02), Math.sin(a) * (r - 0.02), z, 0.1, 0.17, width + 0.014, a, {
        top: "tire_lt", side: "tire_lt", front: "tire", back: "tire",
      });
    }
    // sidewalls
    for (const s of [1, -1]) {
      const zz = z + s * (width / 2 + 0.002);
      m.cylinder(0, 0, r * 0.93, zz - 0.012, zz, 18, { cap: "tire_lt", side: "tire_lt" });
      m.cylinder(0, 0, r * 0.57, zz, zz + s * 0.03, 12, { cap: "rim", side: "rim_dk" });
    }
    // rim barrel and spokes
    m.cylinder(0, 0, r * 0.57, z0 - 0.012, z1 + 0.012, 12, { cap: "rim_dk", side: "rim_dk" });
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2 + 0.25;
      m.boxRotZ(Math.cos(a) * r * 0.31, Math.sin(a) * r * 0.31, z, r * 0.58, r * 0.13, width + 0.03, a, "rim_dk");
    }
    // hub, lugs, brake disc
    m.cylinder(0, 0, r * 0.2, z0 - 0.03, z1 + 0.03, 8, { cap: "chrome", side: "chrome_dk" });
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2;
      const x = Math.cos(a) * r * 0.11, y = Math.sin(a) * r * 0.11;
      m.boxMM(x - r * 0.03, y - r * 0.03, z + width / 2 + 0.025, x + r * 0.03, y + r * 0.03, z + width / 2 + 0.05, "bolt_dk");
    }
    m.cylinder(0, 0, r * 0.42, z - width / 2 - 0.02, z - width / 2, 12, { cap: "rim_dk", side: "rim_dk" });
  }
  if (zs.length > 1) {
    m.boxMM(-0.06, -0.06, zs[zs.length - 1], 0.06, 0.06, zs[0], "black");
    m.boxMM(-0.04, -0.04, zs[0] - 0.02, 0.04, 0.04, zs[zs.length - 1] + 0.02, "steel_dk");
  }
  return m;
}
M.wheel_moto = () => wheel(0.36, [0], 0.16, 12);
M.wheel_car = () => wheel(0.42, [0.88, -0.88], 0.26, 14);
M.wheel_truck = () => wheel(0.5, [0.98, -0.98], 0.3, 16);

// ------------------------------------------------------------------ terrain (tinted)
M.terrain_body = () => new Mesh().box(0, 0, 0, 1, 1, 1, { top: "base", side: "base", front: "base_lo", back: "base", bottom: "base_dk" });

// top slab: surface at y = 0, 0.4 thick, grass fringe on the front edge
M.terrain_top = () => {
  const m = new Mesh();
  m.boxMM(-0.5, -0.4, -0.5, 0.5, 0, 0.5, { top: "white", side: "base_hi", front: "base_hi", back: "base_hi" });
  // overhanging grass lip (front)
  m.boxMM(-0.5, -0.09, 0.46, 0.5, 0.01, 0.54, { top: "white", side: "base_lo", front: "base" });
  // grass tufts along the visible front edge
  const tufts = [-0.39, -0.16, 0.09, 0.33];
  for (let i = 0; i < tufts.length; i++) {
    const x = tufts[i];
    const h = 0.1 + (i % 3) * 0.035;
    m.boxMM(x - 0.012, 0, 0.49, x + 0.012, h, 0.505, "base_hi");
    m.boxMM(x - 0.045, 0, 0.485, x - 0.012, h * 0.6, 0.5, "base_hi");
    m.boxMM(x + 0.012, 0, 0.485, x + 0.045, h * 0.45, 0.5, "base_hi");
  }
  // a few darker clumps so the top surface is not a flat plane
  for (const [x, z] of [[-0.3, 0.1], [0.15, -0.15], [0.38, 0.2]]) {
    m.boxMM(x - 0.08, 0, z - 0.06, x + 0.08, 0.012, z + 0.06, "base_hi");
  }
  return m;
};

// terrain wedges: sloped hypotenuse face omitted to prevent Z-fighting with cap_row's terrain_top
M.wedge_up = () => new Mesh().prism([[-0.5, 0], [0.5, 0], [0.5, 1]], -0.5, 0.5, {
  cap: "base_lo",
  side: (a, b) => (a[0] !== b[0] && a[1] !== b[1] ? null : "base"),
});
M.wedge_dn = () => new Mesh().prism([[-0.5, 0], [0.5, 0], [-0.5, 1]], -0.5, 0.5, {
  cap: "base_lo",
  side: (a, b) => (a[0] !== b[0] && a[1] !== b[1] ? null : "base"),
});
M.spoiler = () => new Mesh().prism([[-0.5, 0], [0.5, 0], [0.5, 1]], -0.5, 0.5, { cap: "base_lo", side: "base" });

M.block = () => new Mesh().bevelBox(0, 0, 0, 1, 1, 1, 0.07, {
  top: "base_hi", side: "base", front: "base_lo", back: "base", bottom: "base_dk", layer: "base_dk",
});

M.water = () => new Mesh().box(0, -0.5, 0, 1, 1, 1, { top: "water_lt", side: "water", front: "water", back: "water", bottom: "water_dk" });
// thin translucent surface and wave crest (both alpha)
M.water_top = () => new Mesh().boxMM(-0.5, -0.015, -0.5, 0.5, 0.018, 0.5, { top: "water_lt", side: "water", front: "water_lt", back: "water_lt" });
M.water_wave = () => {
  const m = new Mesh();
  m.boxMM(-0.5, -0.01, -0.055, 0.5, 0.05, 0.055, { top: "foam", side: "foam", front: "foam", back: "foam" });
  for (const x of [-0.34, 0.04, 0.36]) m.boxMM(x - 0.09, 0.0, -0.12, x + 0.09, 0.035, 0.12, "white");
  return m;
};

// ------------------------------------------------------------------ level props
function flag(m, color1, color2, checker) {
  m.boxMM(-0.06, 0, -0.06, 0.06, 3.2, 0.06, "pole");
  for (let i = 0; i < 6; i++) {
    for (let j = 0; j < 4; j++) {
      const c = checker ? ((i + j) % 2 ? color1 : color2) : ((i + j) % 2 ? color1 : color2);
      m.boxMM(0.06 + i * 0.2, 2.4 + j * 0.2, -0.04, 0.26 + i * 0.2, 2.6 + j * 0.2, 0.04, c);
    }
  }
  m.box(0, 3.25, 0, 0.2, 0.12, 0.2, "chrome");
  m.box(0, 0.06, 0, 0.34, 0.12, 0.34, "chrome_dk");
}
M.flag_finish = () => {
  const m = new Mesh();
  const f = new Mesh();
  flag(f, "flag_w", "flag_k", true);
  m.add(f, 0, 0, -1.7);
  m.add(f, 0, 0, 1.7);
  // checkered banner between the poles
  for (let i = 0; i < 6; i++) {
    for (let j = 0; j < 2; j++) {
      m.boxMM(0.06 + i * 0.2, 2.9 - j * 0.2, -1.7, 0.26 + i * 0.2, 3.1 - j * 0.2, 1.7, (i + j) % 2 ? "flag_w" : "flag_k");
    }
  }
  // checkered line across the road
  for (let k = 0; k < 13; k++) {
    for (let i = 0; i < 2; i++) {
      m.boxMM(-0.2 + i * 0.2, 0.16, -1.3 + k * 0.2, i * 0.2, 0.185, -1.1 + k * 0.2, (i + k) % 2 ? "flag_w" : "flag_k");
    }
  }
  return m;
};
M.flag_start = () => {
  const m = new Mesh();
  const f = new Mesh();
  flag(f, "flag_g", "flag_g", false);
  m.add(f, 0, 0, -1.7);
  m.add(f, 0, 0, 1.7);
  m.boxMM(0.06, 2.55, -1.68, 1.2, 2.85, 1.68, "flag_g");
  m.boxMM(0.12, 2.62, -1.6, 1.1, 2.7, 1.6, "white");
  return m;
};

function portal(color, light, dark) {
  const m = new Mesh();
  // outer frame
  m.ring(0, 0, 0.66, 1.24, 0.24, 0.52, 18, { front: dark, side: dark }, 0);
  m.ring(0, 0, 0.62, 1.2, 0.17, 0.56, 18, { front: color, side: dark }, 0);
  m.ring(0, 0, 0.48, 1.04, 0.08, 0.58, 18, { front: light, side: color }, 0);
  // emitter studs
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2 + Math.PI / 8;
    const x = Math.cos(a) * 0.62, y = Math.sin(a) * 1.2;
    m.boxMM(x - 0.07, y - 0.07, -0.25, x + 0.07, y + 0.07, 0.25, "chrome_dk");
    m.boxMM(x - 0.045, y - 0.045, 0.26, x + 0.045, y + 0.045, 0.3, light);
  }
  // base plate with hazard marks
  m.bevelBox(0, -1.4, 0, 1.5, 0.24, 1.1, 0.03, {
    top: "cargo_lt", side: "cargo_dk", front: "cargo_dk", back: "cargo_dk", bottom: "black", layer: "cargo_dk",
  });
  for (const x of [-0.5, 0, 0.5]) m.boxMM(x - 0.09, -1.27, 0.56, x + 0.09, -1.25, 0.575, light);
  // cable conduits
  m.boxMM(-0.1, -1.34, -0.6, 0.1, -0.2, -0.48, "cargo_dk");
  m.boxMM(-0.1, -1.34, 0.48, 0.1, -0.2, 0.6, "cargo_dk");
  return m;
}
M.portal_blue = () => portal("portal_b", "portal_b_lt", "portal_b_dk");
M.portal_orange = () => portal("portal_o", "portal_o_lt", "portal_o_dk");
M.portal_glow = () => new Mesh().cylinder(0, 0, 1, -0.02, 0.02, 18, { cap: "white", side: "white" });

M.spikes = () => {
  const m = new Mesh();
  m.bevelBox(0, -0.06, 0, 1.0, 0.12, 2.8, 0.02, {
    top: "spike_dk", side: "spike_dk", front: "spike_dk", back: "spike_dk", bottom: "black", layer: "black",
  });
  let k = 0;
  for (const z of [-1, 0, 1]) {
    for (const x of [-0.25, 0.25]) {
      const h = 0.6 + (k % 2) * 0.2;
      m.pyramid(x, 0, z, 0.42, h, 0.42, "spike", "spike_dk");
      m.boxMM(x - 0.06, 0, z - 0.06, x + 0.06, 0.12, z + 0.06, "chrome_dk");
      k++;
    }
  }
  for (const z of [-0.7, 0.7]) m.boxMM(-0.5, 0.0, z - 0.05, 0.5, 0.05, z + 0.05, "hazard");
  return m;
};

// build helpers (alpha material)
M.grid_dots = () => {
  const m = new Mesh();
  const s = 0.045;
  for (let x = 0; x <= 1; x++) {
    for (let y = 0; y <= 1; y++) {
      m.quad([x - s, y - s, 0], [x + s, y - s, 0], [x + s, y + s, 0], [x - s, y + s, 0], "grid");
      m.quad([x - s * 0.35, y - s * 1.8, 0], [x + s * 0.35, y - s * 1.8, 0], [x + s * 0.35, y - s, 0], [x - s * 0.35, y - s, 0], "grid");
      m.quad([x - s * 0.35, y + s, 0], [x + s * 0.35, y + s, 0], [x + s * 0.35, y + s * 1.8, 0], [x - s * 0.35, y + s * 1.8, 0], "grid");
    }
  }
  return m;
};
M.zone = () => new Mesh().quad([-0.5, -0.5, 0], [0.5, -0.5, 0], [0.5, 0.5, 0], [-0.5, 0.5, 0], "zone");
M.select_ring = () => {
  const m = new Mesh();
  m.ring(0, 0, 0.38, 0.38, 0.09, 0.1, 18, { front: "white", side: "sel" });
  m.ring(0, 0, 0.5, 0.5, 0.035, 0.06, 18, { front: "white", side: "sel" });
  return m;
};
M.debris = () => new Mesh().bevelBox(0, 0, 0, 0.24, 0.24, 0.24, 0.035, {
  top: "white", side: "base_hi", front: "base_hi", back: "base_hi", bottom: "base_lo", layer: "base_lo",
});
M.shadow = () => {
  const m = new Mesh();
  m.prismY([[-0.5, -0.3], [-0.32, -0.5], [0.32, -0.5], [0.5, -0.3], [0.5, 0.3], [0.32, 0.5], [-0.32, 0.5], [-0.5, 0.3]], -0.01, 0.01, "shadow");
  return m;
};
M.sky_band = () => new Mesh().quad([-0.5, -0.5, 0], [0.5, -0.5, 0], [0.5, 0.5, 0], [-0.5, 0.5, 0], "white");

// ------------------------------------------------------------------ decor
M.tree = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.7, 0, 0.3, 1.5, 0.3, 0.025, {
    top: "trunk_lt", side: "trunk", front: "trunk", back: "trunk_dk", bottom: "trunk_dk", layer: "trunk_dk",
  });
  for (const y of [0.35, 0.85]) m.boxMM(-0.16, y, 0.14, 0.16, y + 0.03, 0.17, "trunk_dk");
  // layered canopy
  m.bevelBox(0, 1.85, 0, 1.25, 0.95, 1.15, 0.12, { top: "leaf_lt", side: "leaf", front: "leaf", back: "leaf_dk", bottom: "leaf_dk", layer: "leaf_dk" });
  m.bevelBox(0.14, 2.45, 0.06, 0.82, 0.72, 0.78, 0.1, { top: "leaf_lt", side: "leaf_dk", front: "leaf", back: "leaf_dk", bottom: "leaf_dk", layer: "leaf_dk" });
  m.bevelBox(-0.38, 1.55, 0.34, 0.6, 0.55, 0.55, 0.07, { top: "leaf_lt", side: "leaf", front: "leaf", back: "leaf_dk", bottom: "leaf_dk" });
  m.bevelBox(0.42, 1.6, -0.25, 0.5, 0.48, 0.5, 0.06, { top: "leaf", side: "leaf_dk", front: "leaf_dk", back: "leaf_dk", bottom: "leaf_dk" });
  // fruit / flowers
  for (const [x, y, z, c] of [[0.45, 2.1, 0.35, "flower_r"], [-0.3, 2.25, -0.4, "flower_r"], [0.05, 1.5, 0.55, "flower_y"]]) {
    m.boxMM(x - 0.05, y - 0.05, z - 0.05, x + 0.05, y + 0.05, z + 0.05, c);
  }
  return m;
};
M.pine = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.5, 0, 0.24, 1.1, 0.24, 0.02, { top: "trunk_lt", side: "trunk", front: "trunk", back: "trunk_dk", bottom: "trunk_dk" });
  const tiers = [[1.35, 1.15, 0.92], [1.0, 1.0, 0.8], [1.65, 0.8, 0.64], [2.15, 0.58, 0.46], [2.55, 0.36, 0.28]];
  for (let i = 0; i < tiers.length; i++) {
    const [y, w, d] = tiers[i];
    m.bevelBox(0, y, 0, w, 0.52, d, 0.05, {
      top: "pine_lt", side: i % 2 ? "pine" : "pine_dk", front: "pine", back: "pine_dk", bottom: "pine_dk", layer: "pine_dk",
    });
  }
  m.box(0, 2.75, 0, 0.12, 0.2, 0.12, "pine_lt");
  return m;
};
M.bush = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.32, 0, 0.9, 0.64, 0.7, 0.09, { top: "leaf_lt", side: "leaf", front: "leaf", back: "leaf_dk", bottom: "leaf_dk", layer: "leaf_dk" });
  m.bevelBox(0.38, 0.46, 0.08, 0.52, 0.5, 0.5, 0.07, { top: "leaf_lt", side: "leaf_dk", front: "leaf_dk", back: "leaf_dk", bottom: "leaf_dk" });
  m.bevelBox(-0.35, 0.38, -0.12, 0.45, 0.4, 0.45, 0.06, { top: "leaf", side: "leaf", front: "leaf", back: "leaf_dk", bottom: "leaf_dk" });
  for (const [x, y, z] of [[-0.18, 0.55, 0.36], [0.3, 0.6, 0.3]]) m.boxMM(x - 0.04, y - 0.04, z - 0.04, x + 0.04, y + 0.04, z + 0.04, "flower_r");
  return m;
};
M.rock_small = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.28, 0, 1.0, 0.56, 0.8, 0.08, { top: "base_hi", side: "base", front: "base_lo", back: "base_dk", bottom: "base_dk", layer: "base_dk" });
  m.bevelBox(0.3, 0.6, 0.02, 0.5, 0.36, 0.5, 0.05, { top: "base_hi", side: "base_lo", front: "base", back: "base_dk", bottom: "base_dk" });
  m.bevelBox(-0.34, 0.2, 0.18, 0.36, 0.28, 0.4, 0.04, { top: "base_hi", side: "base", front: "base_lo", back: "base_dk", bottom: "base_dk" });
  return m;
};
M.rock_big = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.55, 0, 1.8, 1.1, 1.3, 0.12, { top: "base_hi", side: "base", front: "base_lo", back: "base_dk", bottom: "base_dk", layer: "base_dk" });
  m.bevelBox(0.55, 1.1, 0.1, 0.9, 0.7, 0.8, 0.08, { top: "base_hi", side: "base_lo", front: "base", back: "base_dk", bottom: "base_dk" });
  m.bevelBox(-0.62, 0.4, 0.36, 0.7, 0.6, 0.6, 0.06, { top: "base_hi", side: "base", front: "base_lo", back: "base_dk", bottom: "base_dk" });
  return m;
};
M.cloud = () => {
  const m = new Mesh();
  m.bevelBox(0, 0, 0, 3.0, 0.62, 0.9, 0.12, { top: "cloud", side: "cloud_sh", front: "cloud", back: "cloud_sh", bottom: "cloud_sh" });
  m.bevelBox(-0.55, 0.45, 0.02, 1.5, 0.7, 0.8, 0.1, { top: "cloud", side: "cloud_sh", front: "cloud", back: "cloud_sh", bottom: "cloud_sh" });
  m.bevelBox(0.72, 0.34, -0.04, 1.1, 0.56, 0.75, 0.08, { top: "cloud", side: "cloud_sh", front: "cloud", back: "cloud_sh", bottom: "cloud_sh" });
  m.bevelBox(0.12, 0.65, 0, 0.9, 0.45, 0.65, 0.07, { top: "cloud", side: "cloud_sh", front: "cloud", back: "cloud_sh", bottom: "cloud_sh" });
  return m;
};
M.mountain = () => {
  const m = new Mesh();
  // Broad low-poly domes: overlapping copies make a natural ridgeline, not a picket fence.
  m.prism([
    [-0.55, 0], [0.55, 0], [0.46, 0.16], [0.34, 0.32], [0.2, 0.44],
    [0.06, 0.58], [-0.06, 0.5], [-0.2, 0.38], [-0.36, 0.24], [-0.46, 0.12],
  ], -0.2, 0.2, { cap: "base_lo", side: "base", back: "base_dk" });
  // secondary shoulder
  m.prism([[-0.5, 0], [-0.02, 0], [-0.22, 0.46]], -0.12, 0.14, { cap: "base", side: "base_lo", back: "base_dk" });
  // shaded side
  m.prism([[0.06, 0.58], [0.55, 0], [0.27, 0.02]], 0.2, 0.212, "base_dk");
  // snow caps
  m.prism([[-0.075, 0.49], [0.14, 0.49], [0.04, 0.6]], 0.2, 0.215, "snow");
  m.prism([[-0.36, 0.31], [-0.12, 0.31], [-0.22, 0.46]], 0.14, 0.155, "snow");
  return m;
};
M.lab_panel = () => {
  const m = new Mesh();
  m.box(0, 0, 0, 2, 2, 0.16, { front: "lab_panel", side: "lab_line", top: "lab_line", back: "lab_dark", bottom: "lab_dark" });
  // frame
  for (const s of [1, -1]) {
    m.boxMM(s * 0.93 - 0.04, -0.98, -0.1, s * 0.93 + 0.04, 0.98, 0.1, "lab_line");
    m.boxMM(-0.98, s * 0.93 - 0.04, -0.1, 0.98, s * 0.93 + 0.04, 0.1, "lab_line");
  }
  // inner panel lines
  m.boxMM(-0.9, -0.02, 0.08, 0.9, 0.02, 0.1, "lab_line");
  m.boxMM(-0.02, -0.9, 0.08, 0.02, 0.9, 0.1, "lab_line");
  // a single glowing strip per panel (the wall tiles many times: keep it quiet)
  m.boxMM(-0.68, 0.55, 0.08, 0.68, 0.62, 0.13, "lab_light");
  for (const x of [-0.86, 0.86]) {
    for (const y of [-0.86, 0.86]) m.boxMM(x - 0.03, y - 0.03, 0.1, x + 0.03, y + 0.03, 0.13, "bolt_dk");
  }
  return m;
};

// small ground decor
M.flower_red = () => flower("flower_r");
M.flower_yellow = () => flower("flower_y");
M.flower_blue = () => flower("flower_b");
M.flower_white = () => flower("flower_w");
function flower(color) {
  const m = new Mesh();
  m.boxMM(-0.02, 0, -0.02, 0.02, 0.42, 0.02, "stem");
  m.boxMM(-0.12, 0.12, -0.015, 0.02, 0.17, 0.015, "stem");
  m.boxMM(-0.12, 0.12, -0.015, -0.08, 0.16, 0.015, "leaf");
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    const x = Math.cos(a) * 0.08, z = Math.sin(a) * 0.08;
    m.boxMM(x - 0.055, 0.4, z - 0.055, x + 0.055, 0.49, z + 0.055, color);
  }
  m.boxMM(-0.045, 0.42, -0.045, 0.045, 0.49, 0.045, "flower_y");
  return m;
}
M.stump = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.22, 0, 0.5, 0.44, 0.5, 0.04, { top: "wood_end", side: "trunk", front: "trunk", back: "trunk_dk", bottom: "trunk_dk" });
  m.boxMM(-0.18, 0.44, -0.18, 0.18, 0.46, 0.18, "wood_lt");
  for (const [x, z] of [[0.24, 0.1], [-0.24, -0.06], [0.06, -0.24]]) {
    m.boxMM(x - 0.07, 0.0, z - 0.07, x + 0.07, 0.1, z + 0.07, "trunk_dk");
  }
  return m;
};
M.crate = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.28, 0, 0.56, 0.56, 0.56, 0.04, { top: "wood_lt", side: "wood", front: "wood", back: "wood_dk", bottom: "wood_dk", layer: "wood_dk" });
  for (const s of [1, -1]) {
    m.boxMM(s * 0.27 - 0.03, 0.04, -0.26, s * 0.27 + 0.03, 0.52, 0.26, "wood_dk");
    m.boxMM(-0.26, 0.04, s * 0.27 - 0.03, 0.26, 0.52, s * 0.27 + 0.03, "wood_dk");
  }
  m.boxMM(-0.22, 0.26, 0.285, 0.22, 0.34, 0.3, "bolt_dk");
  return m;
};
M.fence = () => {
  const m = new Mesh();
  for (const x of [-0.55, 0.55]) {
    m.bevelBox(x, 0.4, 0, 0.12, 0.8, 0.12, 0.02, { top: "wood_lt", side: "wood", front: "wood", back: "wood_dk", bottom: "wood_dk" });
    m.boxMM(x - 0.08, 0.78, -0.08, x + 0.08, 0.84, 0.08, "wood_dk");
  }
  for (const y of [0.28, 0.55]) m.boxMM(-0.62, y, -0.04, 0.62, y + 0.1, 0.04, { top: "wood_lt", side: "wood", front: "wood" });
  return m;
};
M.sign = () => {
  const m = new Mesh();
  m.bevelBox(0, 0.55, 0, 0.1, 1.1, 0.1, 0.02, { top: "wood_lt", side: "wood", front: "wood", back: "wood_dk", bottom: "wood_dk" });
  m.boxMM(-0.42, 0.75, -0.04, 0.32, 1.02, 0.04, { top: "wood_lt", side: "wood", front: "wood", back: "wood_dk" });
  m.prism([[0.32, 0.75], [0.5, 0.885], [0.32, 1.02]], -0.04, 0.04, "wood");
  m.boxMM(-0.3, 0.84, 0.04, 0.2, 0.93, 0.055, "boost_arrow");
  return m;
};

module.exports = M;
