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

function deck(top, side, under) {
  const m = new Mesh();
  m.boxMM(-0.5, -T, -DZ, 0.5, T, DZ, { top, side, front: side, back: side, bottom: under || side });
  m.boxMM(-0.5, -T - 0.14, DZ - 0.22, 0.5, -T, DZ, under || side); // edge girders
  m.boxMM(-0.5, -T - 0.14, -DZ, 0.5, -T, -DZ + 0.22, under || side);
  return m;
}

// ---------------------------------------------------------------- beams
M.beam_road = () => {
  const m = deck("asphalt", "asphalt_dk");
  m.boxMM(-0.5, T, DZ - 0.22, 0.5, T + 0.1, DZ, { top: "curb", side: "curb_red" });
  m.boxMM(-0.5, T, -DZ, 0.5, T + 0.1, -DZ + 0.22, { top: "curb", side: "curb_red" });
  m.boxMM(-0.22, T, -0.06, 0.22, T + 0.012, 0.06, "lane");
  return m;
};

M.beam_steel_road = () => {
  const m = deck("steelroad", "steelroad_dk");
  for (const z of [-0.65, 0, 0.65]) m.boxMM(-0.5, T, z - 0.05, 0.5, T + 0.02, z + 0.05, "steelroad_dk");
  m.boxMM(-0.5, T, DZ - 0.18, 0.5, T + 0.14, DZ, "steelroad_dk");
  m.boxMM(-0.5, T, -DZ, 0.5, T + 0.14, -DZ + 0.18, "steelroad_dk");
  return m;
};

M.beam_boost = () => {
  const m = deck("boost", "steelroad_dk");
  for (const x of [-0.22, 0.2]) {
    // chevron pointing right (+x) lying on the deck: two convex arms (x, z points)
    const arms = [
      [[x - 0.12, -0.75], [x + 0.02, -0.75], [x + 0.2, 0], [x + 0.06, 0]],
      [[x + 0.06, 0], [x + 0.2, 0], [x + 0.02, 0.75], [x - 0.12, 0.75]],
    ];
    for (const pts of arms) {
      for (let i = 1; i < pts.length - 1; i++) {
        const a = pts[0], b = pts[i], c = pts[i + 1];
        m.tri([a[0], T + 0.02, a[1]], [c[0], T + 0.02, c[1]], [b[0], T + 0.02, b[1]], "boost_arrow");
      }
    }
  }
  m.boxMM(-0.5, T, DZ - 0.15, 0.5, T + 0.08, DZ, "boost_arrow");
  m.boxMM(-0.5, T, -DZ, 0.5, T + 0.08, -DZ + 0.15, "boost_arrow");
  return m;
};

M.beam_bounce = () => {
  const m = deck("bounce", "bounce");
  m.boxMM(-0.46, T, -DZ + 0.1, 0.46, T + 0.1, DZ - 0.1, { top: "bounce_lt", side: "bounce" });
  for (const x of [-0.3, 0, 0.3]) {
    m.boxMM(x - 0.07, -T - 0.25, DZ - 0.2, x + 0.07, -T, DZ, "spring");
    m.boxMM(x - 0.07, -T - 0.25, -DZ, x + 0.07, -T, -DZ + 0.2, "spring");
  }
  return m;
};

function pair(fn) {
  const m = new Mesh();
  fn(m, TZ);
  fn(m, -TZ);
  return m;
}

M.beam_wood = () => pair((m, z) => {
  m.boxMM(-0.5, -0.12, z - 0.12, 0.5, 0.12, z + 0.12, { top: "wood_lt", side: "wood", bottom: "wood_dk" });
  m.boxMM(-0.5, -0.03, z + 0.12, 0.5, 0.03, z + 0.13, "wood_dk");
});

M.beam_steel = () => pair((m, z) => {
  m.boxMM(-0.5, 0.09, z - 0.13, 0.5, 0.15, z + 0.13, { top: "steel_lt", side: "steel" });
  m.boxMM(-0.5, -0.15, z - 0.13, 0.5, -0.09, z + 0.13, "steel");
  m.boxMM(-0.5, -0.09, z - 0.04, 0.5, 0.09, z + 0.04, "steel_dk");
});

M.beam_rope = () => pair((m, z) => {
  m.boxMM(-0.5, -0.045, z - 0.045, 0.5, 0.045, z + 0.045, { top: "rope", side: "rope_dk", front: "rope" });
});

M.beam_cable = () => pair((m, z) => {
  m.boxMM(-0.5, -0.055, z - 0.055, 0.5, 0.055, z + 0.055, { top: "cable", side: "cable_dk", front: "cable" });
});

// ---------------------------------------------------------------- joints
M.node_joint = () => {
  const m = new Mesh();
  for (const s of [1, -1]) {
    m.boxMM(-0.15, -0.15, s * 1.38 - 0.16, 0.15, 0.15, s * 1.38 + 0.16, "bolt_dk");
    m.box(0, 0, s * 1.56, 0.2, 0.2, 0.06, "bolt");
  }
  m.boxMM(-0.05, -0.05, -1.4, 0.05, 0.05, 1.4, "bolt_dk");
  return m;
};

M.node_anchor = () => {
  const m = new Mesh();
  for (const s of [1, -1]) {
    m.box(0, 0, s * 1.38, 0.56, 0.56, 0.34, { side: "anchor", top: "anchor_lt", front: "anchor", back: "anchor" });
    m.box(0, 0, s * 1.58, 0.24, 0.24, 0.08, "anchor_lt");
  }
  m.boxMM(-0.08, -0.08, -1.4, 0.08, 0.08, 1.4, "anchor_dk");
  return m;
};

// ---------------------------------------------------------------- vehicles
M.veh_moto = () => {
  const m = new Mesh();
  m.boxMM(-0.5, -0.18, -0.12, 0.55, 0.05, 0.12, { side: "moto", top: "moto", front: "moto" });
  m.boxMM(-0.05, 0.02, -0.16, 0.42, 0.24, 0.16, { side: "moto", top: "moto_dk" });
  m.boxMM(-0.55, 0.04, -0.14, 0.0, 0.14, 0.14, "black");
  m.boxMM(-0.42, -0.28, -0.1, 0.1, -0.16, 0.1, "chrome"); // engine
  m.prism([[0.48, 0.24], [0.56, 0.24], [0.69, -0.34], [0.61, -0.34]], -0.06, 0.06, "chrome"); // fork
  m.prism([[-0.18, -0.08], [-0.08, -0.14], [-0.6, -0.38], [-0.67, -0.3]], -0.06, 0.06, "chrome"); // swingarm
  m.boxMM(0.42, 0.28, -0.3, 0.5, 0.34, 0.3, "black"); // handlebar
  m.boxMM(0.55, 0.1, -0.08, 0.66, 0.2, 0.08, "light");
  // rider
  m.boxMM(-0.32, 0.14, -0.16, 0.04, 0.66, 0.16, { side: "rider", top: "rider", front: "rider" });
  m.boxMM(-0.18, 0.64, -0.15, 0.16, 0.94, 0.15, { side: "helmet", top: "helmet", front: "helmet" });
  m.boxMM(0.06, 0.7, -0.12, 0.17, 0.84, 0.12, "glass_dk");
  m.prism([[-0.02, 0.6], [0.06, 0.52], [0.46, 0.3], [0.42, 0.24], [0.0, 0.46]], 0.12, 0.2, "rider");
  m.prism([[-0.02, 0.6], [0.06, 0.52], [0.46, 0.3], [0.42, 0.24], [0.0, 0.46]], -0.2, -0.12, "rider");
  m.boxMM(-0.2, 0.06, 0.12, 0.2, 0.2, 0.22, "rider");
  m.boxMM(-0.2, 0.06, -0.22, 0.2, 0.2, -0.12, "rider");
  m.boxMM(0.08, -0.16, 0.14, 0.2, 0.14, 0.24, "black");
  m.boxMM(0.08, -0.16, -0.24, 0.2, 0.14, -0.14, "black");
  return m;
};

M.veh_car = () => {
  const m = new Mesh();
  m.boxMM(-1.3, -0.36, -0.95, 1.3, 0.2, 0.95, { side: "car", top: "car", front: "car", back: "car", bottom: "car_dk" });
  m.boxMM(-1.36, -0.36, -0.9, -1.28, -0.12, 0.9, "black"); // rear bumper
  m.boxMM(1.28, -0.36, -0.9, 1.36, -0.12, 0.9, "black"); // front bumper
  m.prism([[-0.98, 0.2], [0.62, 0.2], [0.2, 0.78], [-0.78, 0.78]], -0.82, 0.82, { cap: "car", side: (a, b) => (b[1] > 0.7 && a[1] > 0.7 ? "car" : "glass") });
  // side windows (front face)
  m.prism([[-0.8, 0.3], [-0.2, 0.3], [-0.2, 0.68], [-0.66, 0.68]], 0.82, 0.84, "glass");
  m.prism([[-0.1, 0.3], [0.5, 0.3], [0.2, 0.68], [-0.1, 0.68]], 0.82, 0.84, "glass");
  m.prism([[-0.8, 0.3], [-0.2, 0.3], [-0.2, 0.68], [-0.66, 0.68]], -0.84, -0.82, "glass");
  m.prism([[-0.1, 0.3], [0.5, 0.3], [0.2, 0.68], [-0.1, 0.68]], -0.84, -0.82, "glass");
  m.boxMM(1.26, 0.0, 0.5, 1.33, 0.12, 0.85, "light");
  m.boxMM(1.26, 0.0, -0.85, 1.33, 0.12, -0.5, "light");
  m.boxMM(-1.33, 0.0, 0.55, -1.26, 0.12, 0.85, "tail");
  m.boxMM(-1.33, 0.0, -0.85, -1.26, 0.12, -0.55, "tail");
  m.boxMM(-1.3, -0.06, 0.95, 1.3, 0.0, 0.97, "car_dk"); // side stripe
  return m;
};

M.veh_truck = () => {
  const m = new Mesh();
  m.boxMM(-2.1, -0.58, -0.9, 2.1, -0.32, 0.9, "black"); // chassis
  m.boxMM(0.95, -0.36, -1.0, 2.12, 0.55, 1.0, { side: "truck", top: "truck", front: "truck", back: "truck" }); // cab lower
  m.prism([[0.95, 0.55], [2.12, 0.55], [1.98, 1.02], [0.95, 1.02]], -0.98, 0.98, { cap: "truck", side: (a, b) => (a[0] > 1.9 && b[0] > 1.9 ? "glass" : "truck_dk") });
  m.prism([[1.2, 0.6], [1.95, 0.6], [1.86, 0.92], [1.2, 0.92]], 0.98, 1.0, "glass");
  m.prism([[1.2, 0.6], [1.95, 0.6], [1.86, 0.92], [1.2, 0.92]], -1.0, -0.98, "glass");
  m.boxMM(2.1, -0.4, -0.95, 2.18, -0.2, 0.95, "chrome"); // bumper
  m.boxMM(2.1, 0.0, 0.55, 2.16, 0.18, 0.9, "light");
  m.boxMM(2.1, 0.0, -0.9, 2.16, 0.18, -0.55, "light");
  m.boxMM(-2.12, -0.32, -1.05, 0.85, 1.05, 1.05, { side: "cargo", top: "cargo_lt", front: "cargo", back: "cargo" }); // container
  for (let x = -1.9; x < 0.8; x += 0.45) {
    m.boxMM(x - 0.05, -0.3, 1.05, x + 0.05, 1.03, 1.08, "cargo_dk");
    m.boxMM(x - 0.05, -0.3, -1.08, x + 0.05, 1.03, -1.05, "cargo_dk");
  }
  m.boxMM(-2.14, 0.7, -0.9, -2.1, 0.85, -0.6, "tail");
  m.boxMM(-2.14, 0.7, 0.6, -2.1, 0.85, 0.9, "tail");
  return m;
};

function wheel(r, zs, width) {
  const m = new Mesh();
  for (const z of zs) {
    m.cylinder(0, 0, r, z - width / 2, z + width / 2, 12, { cap: "tire", side: "tire" });
    m.cylinder(0, 0, r * 0.58, z - width / 2 - 0.01, z + width / 2 + 0.01, 8, { cap: "rim", side: "rim_dk" });
    // spokes make the spin readable
    m.box(0, 0, z, r * 1.05, r * 0.16, width + 0.04, "rim_dk");
    m.box(0, 0, z, r * 0.16, r * 1.05, width + 0.04, "rim_dk");
    m.cylinder(0, 0, r * 0.18, z - width / 2 - 0.03, z + width / 2 + 0.03, 6, "chrome");
  }
  if (zs.length > 1) m.boxMM(-0.05, -0.05, zs[zs.length - 1], 0.05, 0.05, zs[0], "black");
  return m;
}
M.wheel_moto = () => wheel(0.36, [0], 0.16);
M.wheel_car = () => wheel(0.42, [0.88, -0.88], 0.26);
M.wheel_truck = () => wheel(0.5, [0.98, -0.98], 0.3);

// ---------------------------------------------------------------- terrain (tinted)
M.terrain_body = () => new Mesh().box(0, 0, 0, 1, 1, 1, { top: "base", side: "base", front: "base_lo", back: "base", bottom: "base_dk" });

// top slab: surface at y = 0, 0.4 thick, grass tufts on the front edge
M.terrain_top = () => {
  const m = new Mesh();
  m.boxMM(-0.5, -0.4, -0.5, 0.5, 0, 0.5, { top: "white", side: "base_hi", front: "base_hi" });
  for (let i = 0; i < 4; i++) {
    const x = -0.375 + i * 0.25;
    m.boxMM(x - 0.06, -0.52, 0.47, x + 0.06, -0.38, 0.51, "base_hi");
  }
  return m;
};

M.wedge_up = () => new Mesh().prism([[-0.5, 0], [0.5, 0], [0.5, 1]], -0.5, 0.5, { cap: "base_lo", side: "base" });
M.wedge_dn = () => new Mesh().prism([[-0.5, 0], [0.5, 0], [-0.5, 1]], -0.5, 0.5, { cap: "base_lo", side: "base" });

M.block = () => {
  const m = new Mesh();
  m.box(0, 0, 0, 1, 1, 1, { top: "base_hi", side: "base", front: "base_lo", bottom: "base_dk" });
  return m;
};

M.water = () => new Mesh().box(0, -0.5, 0, 1, 1, 1, { top: "water_lt", side: "water", front: "water", bottom: "water" });

// ---------------------------------------------------------------- level props
function flag(m, color1, color2, checker) {
  m.boxMM(-0.06, 0, -0.06, 0.06, 3.2, 0.06, "pole");
  for (let i = 0; i < 6; i++) {
    for (let j = 0; j < 4; j++) {
      const c = checker ? ((i + j) % 2 ? color1 : color2) : color1;
      m.boxMM(0.06 + i * 0.2, 2.4 + j * 0.2, -0.04, 0.26 + i * 0.2, 2.6 + j * 0.2, 0.04, c);
    }
  }
  m.box(0, 3.25, 0, 0.2, 0.12, 0.2, "chrome");
}
M.flag_finish = () => {
  const m = new Mesh();
  const f = new Mesh();
  flag(f, "flag_w", "flag_k", true);
  m.add(f, 0, 0, -1.7);
  m.add(f, 0, 0, 1.7);
  // checkered line across the road
  for (let k = 0; k < 13; k++) {
    for (let i = 0; i < 2; i++) {
      m.boxMM(-0.2 + i * 0.2, 0.16, -1.3 + k * 0.2, i * 0.2, 0.18, -1.1 + k * 0.2, (i + k) % 2 ? "flag_w" : "flag_k");
    }
  }
  return m;
};
M.flag_start = () => {
  const m = new Mesh();
  const f = new Mesh();
  flag(f, "flag_g", "flag_g", false);
  m.add(f, 0, 0, -1.7);
  return m;
};

function portal(color, light) {
  const m = new Mesh();
  m.ring(0, 0, 0.62, 1.2, 0.2, 0.5, 18, color);
  m.ring(0, 0, 0.48, 1.04, 0.06, 0.52, 18, light);
  m.boxMM(-0.7, -1.42, -0.5, 0.7, -1.3, 0.5, "cargo_dk"); // base plate
  return m;
}
M.portal_blue = () => portal("portal_b", "portal_b_lt");
M.portal_orange = () => portal("portal_o", "portal_o_lt");
M.portal_glow = () => new Mesh().cylinder(0, 0, 1, -0.02, 0.02, 18, "white");

M.spikes = () => {
  const m = new Mesh();
  for (const z of [-1, 0, 1]) {
    for (const x of [-0.25, 0.25]) m.pyramid(x, 0, z, 0.42, 0.8, 0.42, "spike", "spike_dk");
  }
  m.boxMM(-0.5, -0.1, -1.4, 0.5, 0, 1.4, "spike_dk");
  return m;
};

// build helpers (alpha material)
// 2x2 block of build-grid dots (dots at 0 and 1); the level tiles it over the build zone
M.grid_dots = () => {
  const m = new Mesh();
  const s = 0.06;
  for (let x = 0; x <= 1; x++) {
    for (let y = 0; y <= 1; y++) {
      m.quad([x - s, y - s, 0], [x + s, y - s, 0], [x + s, y + s, 0], [x - s, y + s, 0], "grid");
    }
  }
  return m;
};
M.zone = () => new Mesh().quad([-0.5, -0.5, 0], [0.5, -0.5, 0], [0.5, 0.5, 0], [-0.5, 0.5, 0], "zone");
M.select_ring = () => new Mesh().ring(0, 0, 0.36, 0.36, 0.09, 0.08, 16, "white");
M.debris = () => new Mesh().box(0, 0, 0, 0.24, 0.24, 0.24, { top: "white", side: "base_hi", front: "base_hi" });
M.shadow = () => new Mesh().box(0, 0, 0, 1, 0.02, 1, "shadow");

// ---------------------------------------------------------------- decor
M.tree = () => {
  const m = new Mesh();
  m.boxMM(-0.15, 0, -0.15, 0.15, 1.2, 0.15, "trunk");
  m.box(0, 1.6, 0, 1.3, 0.9, 1.3, { top: "leaf_lt", side: "leaf", front: "leaf" });
  m.box(0.1, 2.3, 0.05, 0.9, 0.7, 0.9, { top: "leaf_lt", side: "leaf_dk", front: "leaf" });
  m.box(-0.35, 1.45, 0.45, 0.5, 0.5, 0.5, { top: "leaf_lt", side: "leaf_dk", front: "leaf_dk" });
  return m;
};
M.pine = () => {
  const m = new Mesh();
  m.boxMM(-0.12, 0, -0.12, 0.12, 0.8, 0.12, "trunk");
  const lv = [[1.3, 0.8], [1.0, 1.4], [0.7, 2.0], [0.4, 2.5]];
  for (const [s, y] of lv) m.box(0, y, 0, s, 0.6, s, { top: "pine", side: "pine_dk", front: "pine" });
  return m;
};
M.bush = () => {
  const m = new Mesh();
  m.box(0, 0.3, 0, 0.9, 0.6, 0.7, { top: "leaf_lt", side: "leaf", front: "leaf" });
  m.box(0.35, 0.45, 0.1, 0.5, 0.5, 0.5, { top: "leaf_lt", side: "leaf_dk", front: "leaf_dk" });
  return m;
};
M.rock_small = () => {
  const m = new Mesh();
  m.box(0, 0.3, 0, 1.0, 0.6, 0.8, { top: "base_hi", side: "base", front: "base_lo" });
  m.box(0.3, 0.7, 0, 0.5, 0.4, 0.5, { top: "base_hi", side: "base_lo", front: "base" });
  return m;
};
M.cloud = () => {
  const m = new Mesh();
  m.box(0, 0, 0, 3, 0.8, 1, { top: "cloud", side: "cloud_sh", front: "cloud", bottom: "cloud_sh" });
  m.box(-0.4, 0.6, 0, 1.4, 0.7, 0.9, { top: "cloud", side: "cloud_sh", front: "cloud" });
  m.box(0.7, 0.45, 0, 1.0, 0.6, 0.8, { top: "cloud", side: "cloud_sh", front: "cloud" });
  return m;
};
M.mountain = () => {
  const m = new Mesh();
  const steps = 6;
  for (let i = 0; i < steps; i++) {
    const w = 1 - i / steps;
    m.box(0, (i + 0.5) / steps, 0, w, 1 / steps, w * 0.4, { top: i === steps - 1 ? "white" : "base_hi", side: "base", front: "base_lo" });
  }
  return m;
};
M.lab_panel = () => {
  const m = new Mesh();
  m.box(0, 0, 0, 2, 2, 0.2, { front: "lab_panel", side: "lab_line", top: "lab_line" });
  m.boxMM(-1, -0.04, 0.1, 1, 0.04, 0.12, "lab_line");
  m.boxMM(-0.04, -1, 0.1, 0.04, 1, 0.12, "lab_line");
  m.boxMM(-0.7, 0.55, 0.1, 0.7, 0.65, 0.14, "lab_light");
  return m;
};

module.exports = M;
