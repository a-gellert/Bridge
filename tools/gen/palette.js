// Shared color palette: one 256x256 texture of 16x16 cells. Models pick colors by name.
// Re-skin the whole game by editing these colors (or by tinting models per theme in Lua).
const fs = require("fs");
const png = require("./png");

const COLORS = {
  // neutral bases (tinted per theme at runtime)
  white: "#FFFFFF", base_hi: "#F2F2F2", base: "#DADADA", base_lo: "#B9B9B9", base_dk: "#8E8E8E",
  // road
  asphalt: "#3C4049", asphalt_lt: "#4B505D", asphalt_dk: "#292C34",
  lane: "#FFD23F", lane_w: "#F3F6FB", curb: "#E9EDF2", curb_red: "#E5484D", reflect: "#FFEDAD",
  // wood
  wood: "#C98A4B", wood_lt: "#E0A766", wood_dk: "#8F5A2B", wood_grain: "#A96C35", wood_end: "#D9A45F",
  // steel
  steel: "#DE453A", steel_dk: "#A32B24", steel_lt: "#FF7B6B", steel_edge: "#FF9A8A", rivet: "#F5D9D5",
  steelroad: "#F2A32A", steelroad_lt: "#FFC65E", steelroad_dk: "#A65F0C",
  // ropes / cables
  rope: "#E2C58D", rope_lt: "#F2E1B8", rope_dk: "#B4945C",
  cable: "#AEB6C2", cable_lt: "#DDE4EE", cable_dk: "#6E7785",
  // special decks
  boost: "#FF7A1A", boost_lt: "#FFB05A", boost_arrow: "#FFE14D", boost_dk: "#B84E06",
  bounce: "#2F86F0", bounce_lt: "#8CC8FF", bounce_dk: "#1B5AA8", spring: "#D9E3EE", spring_dk: "#93A3B7",
  // joints
  bolt: "#C7CED8", bolt_lt: "#EEF2F7", bolt_dk: "#7D8794", bolt_x: "#5B636E",
  anchor: "#E5484D", anchor_dk: "#9E2328", anchor_lt: "#FFC9C9",
  // vehicles
  moto: "#E5484D", moto_dk: "#A12A2E", moto_lt: "#FF7C78",
  rider: "#2F86F0", rider_dk: "#1E5FA8", rider_lt: "#6FB2FF",
  helmet: "#FFE14D", helmet_dk: "#D9B322", skin: "#F2C29B",
  car: "#3E8EF7", car_lt: "#7CBBFF", car_dk: "#2560B5",
  glass: "#BEE6FF", glass_dk: "#79B8E0", glass_lt: "#E8F8FF",
  light: "#FFF3B0", tail: "#FF5A4F", grille: "#23272F",
  truck: "#FFC93C", truck_lt: "#FFE27A", truck_dk: "#D69A10",
  cargo: "#5C6B7A", cargo_lt: "#7D8C9B", cargo_dk: "#3F4B57",
  tire: "#24262B", tire_lt: "#383B43", rim: "#C9D1DB", rim_dk: "#8C96A3",
  chrome: "#EEF2F6", chrome_dk: "#AEB8C4", black: "#16181C", rubber: "#1D1F24",
  // world
  water: "#3FA7F5", water_lt: "#8FD3FF", water_dk: "#2C7FD0", foam: "#EAF9FF",
  flag_w: "#FFFFFF", flag_k: "#1E2228", flag_g: "#3DD68C", pole: "#B9C2CC",
  portal_b: "#2F86F0", portal_b_lt: "#9CD0FF", portal_b_dk: "#175BB0",
  portal_o: "#FF8A1C", portal_o_lt: "#FFD08C", portal_o_dk: "#B85407",
  spike: "#C9D1DB", spike_dk: "#6E7785", hazard: "#22262E",
  trunk: "#8F5A2B", trunk_lt: "#A96C35", trunk_dk: "#6A3F1C",
  leaf: "#58C26A", leaf_dk: "#3C9A4E", leaf_lt: "#86DB8E",
  pine: "#2F8F5B", pine_dk: "#226B43", pine_lt: "#47B374",
  flower_r: "#FF5A7A", flower_y: "#FFD23F", flower_w: "#FFFFFF", flower_b: "#9B7BFF", stem: "#3C9A4E",
  snow: "#F4F8FF", cloud: "#FFFFFF", cloud_sh: "#E3ECF7",
  rock: "#9AA3AE", rock_dk: "#6F7884", rock_lt: "#C3CAD3",
  lab_panel: "#E8EEF5", lab_line: "#B8C4D2", lab_light: "#9CF3FF", lab_dark: "#7E8BA0",
  // helpers
  shadow: "#000000", ghost: "#FFFFFF", grid: "#FFFFFF", zone: "#FFFFFF", sel: "#FFE14D",
};

const NAMES = Object.keys(COLORS);
if (NAMES.length > 256) throw new Error("palette overflow");

function cell(name) {
  const i = NAMES.indexOf(name);
  if (i < 0) throw new Error("unknown color " + name);
  return [i % 16, Math.floor(i / 16)];
}

// UV at the center of a cell (glTF: v = 0 is the top of the image)
function uv(name) {
  const [c, r] = cell(name);
  return [(c + 0.5) / 16, (r + 0.5) / 16];
}

function writeTexture(file) {
  const W = 256, H = 256;
  const buf = Buffer.alloc(W * H * 4);
  for (let i = 0; i < W * H; i++) buf[i * 4 + 3] = 255;
  NAMES.forEach((name, i) => {
    const [r, g, b] = png.hex(COLORS[name]);
    const c0 = (i % 16) * 16, r0 = Math.floor(i / 16) * 16;
    for (let y = r0; y < r0 + 16; y++) {
      for (let x = c0; x < c0 + 16; x++) {
        const k = (y * W + x) * 4;
        buf[k] = r; buf[k + 1] = g; buf[k + 2] = b;
      }
    }
  });
  png.write(file, W, H, buf);
}

// JSON copy for external DCC tools (Blender): colour name -> hex + palette UV centre.
function writeJson(file) {
	const out = {};
	for (const name of NAMES) out[name] = { hex: COLORS[name], uv: uv(name) };
	fs.mkdirSync(require("path").dirname(file), { recursive: true });
	fs.writeFileSync(file, JSON.stringify(out, null, 1), "utf8");
}

module.exports = { COLORS, uv, writeTexture, writeJson };
