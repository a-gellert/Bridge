// Procedural 22 kHz mono WAV sound effects (tiny, deterministic).
const fs = require("fs");
const path = require("path");

const RATE = 22050;
let seed = 1337;
const rnd = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
};
const noise = () => rnd() * 2 - 1;

function writeWav(file, samples) {
  const n = samples.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write("WAVE", 8);
  buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(RATE, 24);
  buf.writeUInt32LE(RATE * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write("data", 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32000), 44 + i * 2);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buf);
}

function synth(dur, fn) {
  const n = Math.floor(RATE * dur);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE, p = i / n;
    out[i] = fn(t, p, (f) => {
      phase += (2 * Math.PI * f) / RATE;
      return phase;
    });
  }
  return out;
}

const sq = (x) => (Math.sin(x) >= 0 ? 1 : -1);
const env = (p, a = 0.01, r = 1) => Math.min(1, p / a) * Math.pow(1 - p, r);

// simple one-pole low-pass for noise bursts
function lowpassNoise(k) {
  let y = 0;
  return () => {
    y += (noise() - y) * k;
    return y;
  };
}

const SOUNDS = {
  click: () => synth(0.06, (t, p, ph) => Math.sin(ph(900 - 400 * p)) * env(p, 0.02, 2) * 0.5),
  build: () => {
    const ln = lowpassNoise(0.3);
    return synth(0.12, (t, p, ph) => (Math.sin(ph(320 - 120 * p)) * 0.6 + ln() * 0.5) * env(p, 0.01, 3) * 0.7);
  },
  erase: () => synth(0.14, (t, p, ph) => Math.sin(ph(500 - 350 * p)) * env(p, 0.01, 2) * 0.45),
  error: () => synth(0.18, (t, p, ph) => sq(ph(140)) * env(p, 0.01, 1.5) * 0.25),
  break_wood: () => {
    const ln = lowpassNoise(0.45);
    return synth(0.35, (t, p, ph) => (ln() * 0.9 + Math.sin(ph(180 - 100 * p)) * 0.4) * env(p, 0.005, 3) * 0.8);
  },
  break_steel: () => synth(0.6, (t, p, ph) => {
    const a = Math.sin(ph(620)) * 0.4 + Math.sin(t * 2 * Math.PI * 1490) * 0.25 + Math.sin(t * 2 * Math.PI * 2310) * 0.12;
    return (a + noise() * 0.15 * (1 - p)) * env(p, 0.003, 4) * 0.7;
  }),
  snap: () => synth(0.2, (t, p, ph) => (Math.sin(ph(1200 - 900 * p)) * 0.5 + noise() * 0.3) * env(p, 0.002, 5) * 0.7),
  engine: () => {
    // seamless loop: integer number of cycles of 55 Hz in 1 s
    const n = RATE;
    const out = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const t = i / RATE;
      const base = Math.sin(2 * Math.PI * 55 * t) * 0.5 + Math.sin(2 * Math.PI * 110 * t) * 0.25 + sq(2 * Math.PI * 27.5 * t) * 0.12;
      const flutter = 0.8 + 0.2 * Math.sin(2 * Math.PI * 11 * t);
      out[i] = base * flutter * 0.45;
    }
    return out;
  },
  win: () => synth(0.9, (t, p) => {
    const notes = [523, 659, 784, 1046];
    const k = Math.min(3, Math.floor(p * 5));
    const f = notes[k];
    const lp = (p * 5) % 1;
    return (Math.sin(2 * Math.PI * f * t) * 0.5 + Math.sin(4 * Math.PI * f * t) * 0.15) * env(lp, 0.02, 1.2) * (1 - p * 0.3) * 0.6;
  }),
  fail: () => synth(0.7, (t, p, ph) => (Math.sin(ph(330 - 180 * p)) * 0.5 + sq(ph(165 - 90 * p)) * 0.12) * env(p, 0.01, 1.5) * 0.55),
  portal: () => synth(0.5, (t, p, ph) => Math.sin(ph(200 + 900 * p * p)) * Math.sin(t * 60) * env(p, 0.05, 1.5) * 0.6),
  bounce: () => synth(0.3, (t, p, ph) => Math.sin(ph(160 + 700 * p)) * env(p, 0.005, 2) * 0.6),
  boost: () => {
    const ln = lowpassNoise(0.2);
    return synth(0.45, (t, p, ph) => (ln() * 0.7 + Math.sin(ph(220 + 400 * p)) * 0.3) * env(p, 0.03, 1.5) * 0.6);
  },
  star: () => synth(0.35, (t, p, ph) => (Math.sin(ph(1320 + 400 * p)) * 0.4 + Math.sin(t * 2 * Math.PI * 2640) * 0.15) * env(p, 0.005, 2) * 0.55),
  splash: () => {
    const ln = lowpassNoise(0.15);
    return synth(0.7, (t, p) => ln() * 1.6 * env(p, 0.01, 2) * 0.6);
  },
  whoosh: () => {
    const ln = lowpassNoise(0.08);
    return synth(0.3, (t, p) => ln() * 2.2 * Math.sin(Math.PI * p) * 0.5);
  },
  crash: () => {
    const ln = lowpassNoise(0.5);
    return synth(0.5, (t, p, ph) => (ln() * 0.8 + Math.sin(ph(90)) * 0.5) * env(p, 0.003, 2.5) * 0.85);
  },
};

function generate(root) {
  const names = [];
  for (const [name, fn] of Object.entries(SOUNDS)) {
    writeWav(path.join(root, "assets/sounds", name + ".wav"), fn());
    names.push(name);
  }
  return names;
}

module.exports = { generate, LOOPING: ["engine"] };
