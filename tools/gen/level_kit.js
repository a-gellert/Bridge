// Level design kit: reusable geometry helpers for hand-flavoured campaign levels.
// Every structure here comes with a reference solution, so it can be validated headlessly.
const { checkLevelInLua } = require("./gen_campaign_40");

const materials = {
  road: { max: 3.0 },
  wood: { max: 4.0 },
  rope: { max: 8.0 },
  steel: { max: 5.0 },
  cable: { max: 12.0 },
  steel_road: { max: 4.0 },
  boost: { max: 3.0 },
  bounce: { max: 3.0 },
};

// Round to the 1 cm grid used by the blueprint node keys.
const R = (v) => Math.round(v * 100) / 100;

function dedupe(list) {
  const seen = new Set();
  const out = [];
  for (const b of list) {
    const k = b[1] + ":" + b[2] + ":" + b[3] + ":" + b[4];
    const kr = b[1] + ":" + b[2] + ":" + b[3] + ":" + b[4];
    if (seen.has(k)) continue;
    seen.add(k);
    out.push([b[0], R(b[1]), R(b[2]), R(b[3]), R(b[4])]);
  }
  return out;
}

// Deck + chord truss over an arbitrary polyline of deck points [[x,y], ...].
// mode: "above" (classic), "below" (underslung), "both" (double chord), "arch" (arched deck is caller's path).
function trussOver(path, opts) {
  opts = opts || {};
  const deckMat = opts.deckMat || "road";
  const trussMat = opts.trussMat || "wood";
  const h = opts.height == null ? 2.4 : opts.height;
  const mode = opts.mode || "above";
  const verticals = opts.verticals !== false;
  const diagonals = opts.diagonals == null ? "both" : opts.diagonals; // "both" | "zigzag" | "none"
  const solu = [];

  const deck = path.map((p) => [R(p[0]), R(p[1])]);
  for (let k = 0; k < deck.length - 1; k++) {
    solu.push([deckMat, deck[k][0], deck[k][1], deck[k + 1][0], deck[k + 1][1]]);
  }

  const above = mode === "above" || mode === "both";
  const below = mode === "below" || mode === "both";
  const top = deck.map((p) => [p[0], R(p[1] + h)]);
  const bot = deck.map((p) => [p[0], R(p[1] - h)]);
  const chord = (pts) => {
    for (let k = 0; k < pts.length - 1; k++) {
      solu.push([trussMat, pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1]]);
    }
  };
  if (above) chord(top);
  if (below) chord(bot);

  for (let k = 0; k < deck.length; k++) {
    if (verticals) {
      if (above) solu.push([trussMat, deck[k][0], deck[k][1], top[k][0], top[k][1]]);
      if (below) solu.push([trussMat, deck[k][0], deck[k][1], bot[k][0], bot[k][1]]);
    }
    if (k < deck.length - 1) {
      if (above) {
        if (diagonals === "both") {
          solu.push([trussMat, deck[k][0], deck[k][1], top[k + 1][0], top[k + 1][1]]);
          solu.push([trussMat, top[k][0], top[k][1], deck[k + 1][0], deck[k + 1][1]]);
        } else if (diagonals === "zigzag") {
          if (k % 2 === 0) solu.push([trussMat, deck[k][0], deck[k][1], top[k + 1][0], top[k + 1][1]]);
          else solu.push([trussMat, top[k][0], top[k][1], deck[k + 1][0], deck[k + 1][1]]);
        }
      }
      if (below && diagonals !== "none") {
        if (diagonals === "both") {
          solu.push([trussMat, deck[k][0], deck[k][1], bot[k + 1][0], bot[k + 1][1]]);
          solu.push([trussMat, bot[k][0], bot[k][1], deck[k + 1][0], deck[k + 1][1]]);
        } else if (diagonals === "zigzag") {
          if (k % 2 === 0) solu.push([trussMat, deck[k][0], deck[k][1], bot[k + 1][0], bot[k + 1][1]]);
          else solu.push([trussMat, bot[k][0], bot[k][1], deck[k + 1][0], deck[k + 1][1]]);
        }
      }
    }
  }

  const anchors = [[deck[0][0], deck[0][1]], [deck[deck.length - 1][0], deck[deck.length - 1][1]]];
  if (above) {
    anchors.push([top[0][0], top[0][1]]);
    anchors.push([top[top.length - 1][0], top[top.length - 1][1]]);
  }
  if (below) {
    anchors.push([bot[0][0], bot[0][1]]);
    anchors.push([bot[bot.length - 1][0], bot[bot.length - 1][1]]);
  }
  return { solution: dedupe(solu), anchors, top, bot };
}

// Straight or sloped span with a truss. Most bridges use this.
function spanLevel(o) {
  const x0 = o.x0, x1 = o.x1;
  const y0 = o.y0 == null ? 0 : o.y0;
  const y1 = o.y1 == null ? 0 : o.y1;
  const deckMat = o.deckMat || "road";
  const trussMat = o.trussMat || "wood";
  const h0 = o.height == null ? 2.4 : o.height;
  const maxDeck = materials[deckMat].max * 0.99;
  const maxTruss = materials[trussMat].max * 0.99;
  let segments = o.segments;
  if (!segments) {
    for (segments = 2; segments < 40; segments++) {
      const dx = (x1 - x0) / segments;
      const dy = (y1 - y0) / segments;
      if (Math.hypot(dx, dy) <= maxDeck && Math.hypot(Math.abs(dx), h0 + Math.abs(dy)) <= maxTruss) break;
    }
  }
  const path = [];
  for (let k = 0; k <= segments; k++) {
    path.push([x0 + ((x1 - x0) * k) / segments, y0 + ((y1 - y0) * k) / segments]);
  }
  const t = trussOver(path, {
    deckMat,
    trussMat,
    height: o.height,
    mode: o.mode || "above",
    verticals: o.verticals,
    diagonals: o.diagonals,
  });

  const blocks = [...(o.blocks || [])];
  const h = o.height == null ? 2.4 : o.height;
  if ((o.mode || "above") !== "below" && o.topBlocks !== false) {
    blocks.push([x0 - 5, y0 + h, x0, y0 + h + 2]);
    blocks.push([x1, y1 + h, x1 + 5, y1 + h + 2]);
  }

  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip,
    assist: o.assist,
    budget: o.budget,
    materials: o.materials || ["road", "wood"],
    ground: o.ground || [
      [-40, x0, y0],
      [x1, x1 + 40, y1],
    ],
    ramps: o.ramps,
    blocks,
    anchors: t.anchors.concat(o.extraAnchors || []),
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(x0 - 6) : o.start,
    finish: o.finish == null ? R(x1 + 8) : o.finish,
    water: o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: t.solution.concat(o.extraSolution || []),
  });
}

// Deck points along an arc: rise is the height of the apex above the chord.
function arcPath(x0, x1, y0, y1, rise, segments) {
  const pts = [];
  for (let k = 0; k <= segments; k++) {
    const t = k / segments;
    pts.push([x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + Math.sin(Math.PI * t) * rise]);
  }
  return pts;
}

// Generic deck along explicit points, with a truss above.
function pathLevel(o) {
  const deckMat = o.deckMat || "road";
  const trussMat = o.trussMat || "wood";
  const h = o.height == null ? 2.4 : o.height;
  const t = trussOver(o.points, { deckMat, trussMat, height: h, mode: o.mode, diagonals: o.diagonals });
  const first = o.points[0], last = o.points[o.points.length - 1];
  const blocks = [...(o.blocks || [])];
  if ((o.mode || "above") !== "below" && o.topBlocks !== false) {
    blocks.push([first[0] - 5, first[1] + h, first[0], first[1] + h + 2]);
    blocks.push([last[0], last[1] + h, last[0] + 5, last[1] + h + 2]);
  }
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip,
    budget: o.budget,
    materials: o.materials || ["road", "wood"],
    ground: o.ground || [
      [-40, first[0], first[1]],
      [last[0], 90, last[1]],
    ],
    ramps: o.ramps,
    blocks,
    anchors: t.anchors.concat(o.extraAnchors || []),
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(first[0] - 6) : o.start,
    finish: o.finish == null ? R(last[0] + 8) : o.finish,
    water: o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: t.solution.concat(o.extraSolution || []),
  });
}

function fitPath(makePath, deckMat, trussMat, h) {
  const maxDeck = materials[deckMat].max * 0.99;
  const maxTruss = materials[trussMat].max * 0.99;
  for (let n = 3; n <= 40; n++) {
    const pts = makePath(n);
    let ok = true;
    for (let k = 0; k < pts.length - 1; k++) {
      const dx = pts[k + 1][0] - pts[k][0], dy = pts[k + 1][1] - pts[k][1];
      if (Math.hypot(dx, dy) > maxDeck || Math.hypot(dx, h + Math.abs(dy)) > maxTruss) { ok = false; break; }
    }
    if (ok) return pts;
  }
  return makePath(12);
}

function archLevel(o) {
  const x0 = o.x0, x1 = o.x1;
  const y0 = o.y0 == null ? 0 : o.y0;
  const y1 = o.y1 == null ? 0 : o.y1;
  const rise = o.rise == null ? 1.5 : o.rise;
  const deckMat = o.deckMat || "road";
  const trussMat = o.trussMat || "wood";
  const h = o.height == null ? 2.4 : o.height;
  const pts = fitPath((n) => arcPath(x0, x1, y0, y1, rise, n).map((p) => [R(p[0]), R(p[1])]), deckMat, trussMat, h);
  return pathLevel({ ...o, points: pts, deckMat, trussMat, height: h, ground: o.ground || [[-40, x0, y0], [x1, 90, y1]] });
}

function humpLevel(o) {
  const x0 = o.x0, x1 = o.x1;
  const y0 = o.y0 == null ? 0 : o.y0;
  const y1 = o.y1 == null ? 0 : o.y1;
  const rise = o.rise == null ? 1.5 : o.rise;
  const deckMat = o.deckMat || "road";
  const trussMat = o.trussMat || "wood";
  const h = o.height == null ? 2.4 : o.height;
  const make = (n) => {
    const pts = [];
    for (let k = 0; k <= n; k++) {
      const t = k / n;
      const bump = Math.pow(Math.sin(Math.PI * t), 1.35);
      pts.push([R(x0 + (x1 - x0) * t), R(y0 + (y1 - y0) * t + bump * rise)]);
    }
    return pts;
  };
  const pts = fitPath(make, deckMat, trussMat, h);
  return pathLevel({ ...o, points: pts, deckMat, trussMat, height: h, ground: o.ground || [[-40, x0, y0], [x1, 90, y1]] });
}

// Low rock ceiling: a truss that has to fit under a slab.
function caveLevel(o) {
  const h = o.height == null ? 2.2 : o.height;
  return spanLevel({
    ...o,
    height: h,
    topBlocks: false,
    blocks: [[o.x0, h, o.x1, h + 4], ...(o.blocks || [])],
  });
}

// Deck held by diagonals from one or two rock outcrops above the span.
function kingpostLevel(o) {
  const x0 = o.x0, x1 = o.x1;
  const y0 = o.y0 == null ? 0 : o.y0;
  const y1 = o.y1 == null ? 0 : o.y1;
  const deckMat = o.deckMat || "road";
  const stayMat = o.stayMat || "steel";
  const deckMax = materials[deckMat].max * 0.99;
  const stayMax = materials[stayMat].max * 0.97;
  const n = o.segments || Math.max(2, Math.ceil(Math.abs(x1 - x0) / (deckMax * 0.98)));
  const path = [];
  for (let k = 0; k <= n; k++) path.push([R(x0 + ((x1 - x0) * k) / n), R(y0 + ((y1 - y0) * k) / n)]);
  const sol = [];
  for (let k = 0; k < path.length - 1; k++) sol.push([deckMat, path[k][0], path[k][1], path[k + 1][0], path[k + 1][1]]);
  const apexCount = o.apexes || 1;
  const apexes = [];
  const posts = [];
  for (let i = 0; i < apexCount; i++) {
    const t = apexCount === 1 ? 0.5 : (i + 1) / (apexCount + 1);
    const ax = R(x0 + (x1 - x0) * t);
    const ay = R(y0 + (y1 - y0) * t + (o.rise == null ? 2.4 : o.rise));
    apexes.push([ax, ay]);
  }
  // The middle deck joint under every king post.
  const deckUnder = (ax) => {
    let best = path[0];
    for (const p of path) if (Math.abs(p[0] - ax) < Math.abs(best[0] - ax)) best = p;
    return best;
  };
  for (const a of apexes) {
    const under = deckUnder(a[0]);
    sol.push([stayMat, a[0], a[1], under[0], under[1]]);
    for (const p of path) {
      const d = Math.hypot(a[0] - p[0], a[1] - p[1]);
      if (d > 0.1 && d <= stayMax) sol.push([stayMat, a[0], a[1], p[0], p[1]]);
    }
    posts.push([a[0] - 1.1, a[1], a[0] + 1.1, a[1] + 2]);
  }
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip,
    budget: o.budget,
    materials: o.materials || ["road", "wood", "steel"],
    ground: o.ground || [
      [-40, x0, y0],
      [x1, x1 + 40, y1],
    ],
    ramps: o.ramps,
    blocks: posts.concat(o.blocks || []),
    anchors: [[path[0][0], path[0][1]], [path[path.length - 1][0], path[path.length - 1][1]]].concat(apexes, o.extraAnchors || []),
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(x0 - 6) : o.start,
    finish: o.finish == null ? R(x1 + 8) : o.finish,
    water: o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: dedupe(sol).concat(o.extraSolution || []),
  });
}

// Several gaps separated by rock islands. Each span can be trussed above or below.
function islandsLevel(o) {
  // gaps: [{x0, x1}], islands are the ground between consecutive gaps
  const touches = [];
  for (const g of o.gaps) touches.push([g.x0, g.x1]);
  const ground = [[-40, o.gaps[0].x0, o.startY == null ? 0 : o.startY]];
  for (let i = 0; i < o.gaps.length - 1; i++) {
    ground.push([o.gaps[i].x1, o.gaps[i + 1].x0, o.islandY == null ? 0 : o.islandY]);
  }
  ground.push([o.gaps[o.gaps.length - 1].x1, 80, o.endY == null ? 0 : o.endY]);
  const sol = [];
  const anchors = [];
  const blocks = [...(o.blocks || [])];
  const h = o.height == null ? 2.2 : o.height;
  const deckMat = o.deckMat || "road";
  const trussMat = o.trussMat || "wood";
  const maxDeck = materials[deckMat].max * 0.99;
  const bay = o.bay == null ? maxDeck * 0.98 : o.bay;
  o.gaps.forEach((g, gi) => {
    const y = o.islandY == null ? 0 : o.islandY;
    const y0 = gi === 0 ? (o.startY == null ? 0 : o.startY) : y;
    const y1 = gi === o.gaps.length - 1 ? (o.endY == null ? 0 : o.endY) : y;
    const n = Math.max(2, Math.ceil(Math.abs(g.x1 - g.x0) / bay));
    const path = [];
    for (let k = 0; k <= n; k++) path.push([R(g.x0 + ((g.x1 - g.x0) * k) / n), R(y0 + ((y1 - y0) * k) / n)]);
    const t = trussOver(path, {
      deckMat,
      trussMat,
      height: h,
      mode: o.mode || "below",
      verticals: true,
      diagonals: "both",
    });
    sol.push(...t.solution);
    anchors.push(...t.anchors);
    if ((o.mode || "below") !== "below" && o.topBlocks !== false) {
      blocks.push([g.x0 - 5, y0 + h, g.x0, y0 + h + 2]);
      blocks.push([g.x1, y1 + h, g.x1 + 5, y1 + h + 2]);
    }
  });
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip,
    budget: o.budget,
    materials: o.materials || ["road", "wood"],
    ground,
    ramps: o.ramps,
    blocks,
    anchors,
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(o.gaps[0].x0 - 6) : o.start,
    finish: o.finish == null ? R(o.gaps[o.gaps.length - 1].x1 + 8) : o.finish,
    water: o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: dedupe(sol),
  });
}

// A narrow rock pillar in the middle of a wide gap, used as extra anchors.
function pillarLevel(o) {
  const mid = o.mid;
  const half = o.pillarHalf == null ? 0.5 : o.pillarHalf;
  const base = o.pillarBase == null ? -7 : o.pillarBase;
  const y0 = o.y0 == null ? 0 : o.y0;
  const y1 = o.y1 == null ? 0 : o.y1;
  const rightX = o.rightX;
  const deckMat = o.deckMat || "road";
  const trussMat = o.trussMat || "wood";
  const h = o.height == null ? 2.2 : o.height;
  const maxDeck = materials[deckMat].max * 0.99;
  const maxTruss = materials[trussMat].max * 0.99;
  const pathTo = (xa, ya, xb, yb) => {
    let n = 2;
    for (; n < 30; n++) {
      const dx = (xb - xa) / n, dy = (yb - ya) / n;
      if (Math.hypot(dx, dy) <= maxDeck && Math.hypot(dx, h + Math.abs(dy)) <= maxTruss) break;
    }
    const pts = [];
    for (let k = 0; k <= n; k++) pts.push([R(xa + ((xb - xa) * k) / n), R(ya + ((yb - ya) * k) / n)]);
    return pts;
  };
  const lp = pathTo(o.x0, y0, mid, y0);
  const rp = pathTo(mid, y0, rightX, y1);
  const left = trussOver(lp, { deckMat, trussMat, height: h });
  const right = trussOver(rp, { deckMat, trussMat, height: h });
  const sol = left.solution.concat(right.solution);
  const anchors = dedupeAnchors(left.anchors.concat(right.anchors, [[mid, y0]]));
  const blocks = [[mid - half, base, mid + half, y0], ...(o.blocks || [])];
  if (o.topBlocks !== false) {
    blocks.push([o.x0 - 5, y0 + h, o.x0, y0 + h + 2]);
    blocks.push([rightX, y1 + h, rightX + 5, y1 + h + 2]);
  }
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip,
    budget: o.budget,
    materials: o.materials || ["road", "wood"],
    ground: [[-40, o.x0, y0], [rightX, 90, y1]],
    ramps: o.ramps,
    blocks,
    anchors,
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(o.x0 - 6) : o.start,
    finish: o.finish == null ? R(rightX + 8) : o.finish,
    water: o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: dedupe(sol),
  });
}

function dedupeAnchors(list) {
  const seen = new Set();
  const out = [];
  for (const p of list) {
    const k = R(p[0]) + ":" + R(p[1]);
    if (seen.has(k)) continue;
    seen.add(k);
    out.push([R(p[0]), R(p[1])]);
  }
  return out;
}

// Boost strip + ramp jump across a chasm. The solid ramp hangs over the edge like a diving board.
function jumpLevel(o) {
  const rampLen = o.rampLen == null ? 3 : o.rampLen;
  const rampRise = o.rampRise == null ? 1.2 : o.rampRise;
  const edge = o.edge;
  const landing = o.landing;
  const deckY = o.deckY == null ? 0 : o.deckY;
  const landingY = o.landingY == null ? -2 : o.landingY;
  const boostFrom = o.boostFrom == null ? edge - 6 : o.boostFrom;
  const sol = [];
  const anchors = [];
  let x = boostFrom;
  while (x < edge - 0.01) {
    const nx = Math.min(x + 3, edge);
    sol.push(["boost", R(x), deckY, R(nx), deckY]);
    x = nx;
  }
  anchors.push([R(boostFrom), deckY], [R(edge), deckY]);
  if (o.extraSolution) sol.push(...o.extraSolution);
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip || "tip_boost",
    budget: o.budget,
    materials: o.materials || ["road", "wood", "boost"],
    ground: [
      [-40, edge, deckY],
      [landing, 90, landingY],
    ],
    ramps: [
      [edge, R(edge + rampLen), deckY, deckY + rampRise, -40],
      ...(o.noLandingRamp || landingY >= deckY - 0.05 ? [] : [[R(landing - 3), landing, R(landingY - 1.6), landingY, -40]]),
    ],
    blocks: o.blocks || [],
    anchors: dedupeAnchors(anchors),
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(boostFrom - 8) : o.start,
    finish: o.finish == null ? R(landing + 8) : o.finish,
    water: o.water == null ? -7 : o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: dedupe(sol),
  });
}

// Speed up on boost pads and get launched by a bounce pad over a chasm.
function bounceLevel(o) {
  const edge = o.edge;
  const padFrom = o.padFrom == null ? edge - 3 : o.padFrom;
  const boostFrom = o.boostFrom == null ? padFrom - 6 : o.boostFrom;
  const deckY = o.deckY == null ? 0 : o.deckY;
  const landing = o.landing;
  const landingY = o.landingY == null ? -1 : o.landingY;
  const sol = [];
  const anchors = [];
  let x = boostFrom;
  while (x < padFrom - 0.01) {
    const nx = Math.min(x + 3, padFrom);
    sol.push(["boost", R(x), deckY, R(nx), deckY]);
    x = nx;
  }
  if (padFrom < edge) {
    let px = padFrom;
    while (px < edge - 0.01) {
      const nx = Math.min(px + 3, edge);
      sol.push(["bounce", R(px), deckY, R(nx), deckY]);
      px = nx;
    }
  } else {
    sol.push(["bounce", R(padFrom), deckY, R(edge), deckY]);
  }
  anchors.push([R(boostFrom), deckY], [R(padFrom), deckY], [R(edge), deckY]);
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip || "tip_mix",
    budget: o.budget,
    materials: o.materials || ["road", "wood", "boost", "bounce"],
    ground: [
      [-40, edge, deckY],
      [landing, 90, landingY],
    ],
    ramps: o.ramps,
    blocks: o.blocks || [],
    anchors: dedupeAnchors(anchors),
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(boostFrom - 8) : o.start,
    finish: o.finish == null ? R(landing + 8) : o.finish,
    water: o.water == null ? -8 : o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: dedupe(sol),
  });
}

// Portal pair with a wall for the exit. Wraps the proven campaign builder.
function portalLevel(o) {
  const { buildPortalLevel } = require("./gen_campaign_40");
  return buildPortalLevel(o);
}

// Bridge -> entry portal on the low side -> exit portal on a high rock plateau -> finish.
function portalHighLevel(o) {
  const x0 = o.x0 == null ? 0 : o.x0;
  const x1 = o.x1;
  const y0 = o.y0 == null ? 0 : o.y0;
  const p = trussOver(
    (() => {
      const maxDeck = materials[o.deckMat || "road"].max * 0.99;
      const n = Math.max(2, Math.ceil((x1 - x0) / (maxDeck * 0.98)));
      const pts = [];
      for (let k = 0; k <= n; k++) pts.push([R(x0 + ((x1 - x0) * k) / n), y0]);
      return pts;
    })(),
    { deckMat: o.deckMat || "road", trussMat: o.trussMat || "wood", height: o.height == null ? 2.4 : o.height }
  );
  const h = o.height == null ? 2.4 : o.height;
  const highY = o.highY == null ? 6 : o.highY;
  const exitX = o.exitX == null ? x1 + 16 : o.exitX;
  const entryX = o.entryX == null ? x1 + 4 : o.entryX;
  const finish = o.finish == null ? exitX + 12 : o.finish;
  const blocks = [
    [x0 - 5, y0 + h, x0, y0 + h + 2],
    [x1, y0 + h, x1 + 5, y0 + h + 2],
    // portal frame / wall behind the entry
    [entryX + 0.8, y0, entryX + 1.6, y0 + 4],
    ...(o.blocks || []),
  ];
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip || "tip_portal2",
    budget: o.budget,
    materials: o.materials || ["road", "wood", "steel", "cable", "boost", "steel_road"],
    ground: [
      [-40, x0, y0],
      [x1, exitX - 2, y0],
      [exitX - 2, finish + 30, highY],
    ],
    ramps: o.ramps,
    blocks,
    anchors: p.anchors,
    portals: [
      [
        { x: entryX, y: y0 + 1.3, angle: Math.PI },
        { x: exitX, y: highY + 1.4, angle: 0 },
      ],
    ],
    spikes: o.spikes,
    start: o.start == null ? R(x0 - 6) : o.start,
    finish,
    water: o.water == null ? -5 : o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: p.solution,
  });
}


// Hanging deck: towers/rocks above the ends, rope/cable hangers to the deck.
function suspensionLevel(o) {
  const x0 = o.x0, x1 = o.x1;
  const y0 = o.y0 == null ? 0 : o.y0;
  const y1 = o.y1 == null ? 0 : o.y1;
  const deckMat = o.deckMat || "road";
  const cableMat = o.cableMat || "cable";
  const towerY = o.towerY == null ? 8 : o.towerY;
  const segments = o.segments || Math.max(2, Math.ceil((x1 - x0) / 2.7));
  const solu = [];
  const path = [];
  for (let k = 0; k <= segments; k++) {
    path.push([R(x0 + ((x1 - x0) * k) / segments), R(y0 + ((y1 - y0) * k) / segments)]);
  }
  for (let k = 0; k < path.length - 1; k++) {
    solu.push([deckMat, path[k][0], path[k][1], path[k + 1][0], path[k + 1][1]]);
  }
  const tl = [R(x0 + (o.towerInset == null ? 2 : o.towerInset)), R(y0 + towerY)];
  const tr = [R(x1 - (o.towerInset == null ? 2 : o.towerInset)), R(y1 + towerY)];
  const maxCable = materials[cableMat].max * 0.97;
  const cable = (a, b) => {
    if (Math.hypot(a[0] - b[0], a[1] - b[1]) <= maxCable) solu.push([cableMat, a[0], a[1], b[0], b[1]]);
  };
  // vertical hangers, skipping ones that would break the material length limit
  for (let k = 1; k < path.length - 1; k++) {
    const t = path[k];
    if (t[0] > tl[0] && t[0] < tr[0]) {
      cable(tl, t);
      cable(tr, t);
    }
  }
  // anchor cables to the deck ends
  cable(tl, path[0]);
  cable(tr, path[path.length - 1]);
  // long diagonals for stiffness to the middle of the span
  const mid = path[Math.floor(path.length / 2)];
  cable(tl, mid);
  cable(tr, mid);

  const blocks = [
    [x0 - 6, tl[1], tl[0], tl[1] + 2],
    [tr[0], tr[1], x1 + 6, tr[1] + 2],
    ...(o.blocks || []),
  ];
  return assemble({
    id: o.id,
    name: o.name,
    tip: o.tip,
    budget: o.budget,
    materials: o.materials || ["road", "wood", "rope", "cable"],
    ground: o.ground || [
      [-40, x0, y0],
      [x1, x1 + 40, y1],
    ],
    ramps: o.ramps,
    blocks,
    anchors: [
      [path[0][0], path[0][1]],
      [path[path.length - 1][0], path[path.length - 1][1]],
      tl,
      tr,
      ...(o.extraAnchors || []),
    ],
    portals: o.portals,
    spikes: o.spikes,
    start: o.start == null ? R(x0 - 6) : o.start,
    finish: o.finish == null ? R(x1 + 8) : o.finish,
    water: o.water,
    kill_y: o.kill_y,
    area: o.area,
    solution: dedupe(solu).concat(o.extraSolution || []),
  });
}

// Final object + automatic build area.
function assemble(o) {
  const lvl = {
    id: o.id,
    name: o.name,
    budget: o.budget || 99999,
    materials: o.materials,
    assist: o.assist,
    ground: o.ground,
    ramps: o.ramps,
    blocks: o.blocks,
    anchors: o.anchors,
    portals: o.portals,
    spikes: o.spikes,
    start: o.start,
    finish: o.finish,
    water: o.water,
    kill_y: o.kill_y,
    tip: o.tip,
    solution: o.solution,
    area: o.area,
  };
  if (!lvl.area) {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const p of lvl.anchors) {
      minX = Math.min(minX, p[0]);
      maxX = Math.max(maxX, p[0]);
      minY = Math.min(minY, p[1]);
      maxY = Math.max(maxY, p[1]);
    }
    for (const b of lvl.solution) {
      minX = Math.min(minX, b[1], b[3]);
      maxX = Math.max(maxX, b[1], b[3]);
      minY = Math.min(minY, b[2], b[4]);
      maxY = Math.max(maxY, b[2], b[4]);
    }
    lvl.area = [Math.floor(minX) - 1, Math.floor(minY) - 1, Math.ceil(maxX) + 1, Math.ceil(maxY) + 1];
  }
  return lvl;
}

// Increase the budget to a clean value that fits the reference bridge.
function fitBudget(lvl, multiplier) {
  const res = checkLevelInLua(lvl);
  if (!res.ok) return { lvl, res };
  const m = multiplier == null ? 1.18 : multiplier;
  lvl.budget = Math.ceil((res.cost * m) / 50) * 50;
  if (lvl.budget < res.cost) lvl.budget = Math.ceil(res.cost / 50) * 50;
  return { lvl, res };
}

function test(lvl) {
  return checkLevelInLua(lvl);
}

module.exports = {
  R,
  dedupe,
  trussOver,
  spanLevel,
  pathLevel,
  archLevel,
  humpLevel,
  suspensionLevel,
  arcPath,
  caveLevel,
  kingpostLevel,
  islandsLevel,
  pillarLevel,
  jumpLevel,
  bounceLevel,
  portalLevel,
  portalHighLevel,
  assemble,
  fitBudget,
  test,
  materials,
};
