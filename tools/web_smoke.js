// Browser smoke test: serves a web bundle, mocks the Poki SDK, drives headless Edge/Chrome over CDP.
// Usage:
//   node tools/web_smoke.js <bundle_dir> <out_dir> [--size=1280x720] [--secs=8] [--touch=1] [--cfg=key=value,...]
//        [--steps="wait:6;click:640,360;drag:100,300,160,300;key:Space;hold:KeyD,1.5;shot:after"]
// Steps: wait:<s> | shot:<name> | move:x,y | click:x,y | rclick:x,y | drag:x1,y1,x2,y2 | wheel:x,y,dy
//        touchtap:x,y | touchdrag:x1,y1,x2,y2 | key:<code> | hold:<code>,<s>
// Key codes are DOM codes (Space, Enter, Escape, KeyZ, KeyD, ArrowRight, Digit1...).
// Without --steps it waits --secs and saves boot_<WxH>.png. Lua/JS errors in the console are counted
// and the process exits with code 1 when there are any.
const fs = require('fs');
const path = require('path');
const http = require('http');
const { spawn } = require('child_process');

const [, , BUNDLE, OUT, ...rest] = process.argv;
if (!BUNDLE || !OUT) {
  console.error('usage: node tools/web_smoke.js <bundle_dir> <out_dir> [--size=WxH] [--steps=...]');
  process.exit(2);
}
const opt = { size: '1280x720', secs: '8', steps: '', touch: '0' };
for (const a of rest) {
  const m = a.match(/^--(\w+)=(.*)$/);
  if (m) opt[m[1]] = m[2];
}
const [VW, VH] = opt.size.split('x').map(Number);
const PORT = 8760 + Math.floor(Math.random() * 400);
const DBG_PORT = 9360 + Math.floor(Math.random() * 400);
const BROWSER = (process.env.BROWSER_PATH && fs.existsSync(process.env.BROWSER_PATH) ? process.env.BROWSER_PATH : null) || [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
].find(p => p && fs.existsSync(p));

if (!BROWSER) { console.error('No Edge/Chrome found (set BROWSER_PATH)'); process.exit(1); }
fs.mkdirSync(OUT, { recursive: true });

const POKI_MOCK = `<script>
window.PokiSDK = {
  init: () => Promise.resolve(),
  gameLoadingProgress() {}, gameLoadingFinished() { console.log('[poki] loaded'); },
  gameplayStart() { console.log('[poki] gameplayStart'); },
  gameplayStop() { console.log('[poki] gameplayStop'); },
  commercialBreak(cb) { console.log('[poki] commercialBreak'); if (cb) cb(); return Promise.resolve(); },
  rewardedBreak() { console.log('[poki] rewardedBreak'); return Promise.resolve(true); },
  measure(a, b, c) { console.log('[poki] measure', a, b, c); },
  setDebug() {}, captureError(e) { console.log('[poki] err', e); },
  getURLParam() { return null; }, getDeviceInfo() { return { category: 'desktop' }; }, movePill() {},
  getLanguage() { return 'en'; },
};
window.addEventListener('load', () => setTimeout(() => { if (window.poki_sdk_loaded) poki_sdk_loaded(); }, 40));
</script>`;

function patchedIndex() {
  let html = fs.readFileSync(path.join(BUNDLE, 'index.html'), 'utf8');
  html = html.replace(/<script[^>]*poki-sdk\.js[^>]*><\/script>/, POKI_MOCK);
  if (opt.cfg) {
    const args = opt.cfg.split(',').map(kv => `--config=${kv}`);
    html = html.replace(/(<script id=["']engine-setup["'][^>]*>)/,
      `$1\nCUSTOM_PARAMETERS["engine_arguments"] = ${JSON.stringify(args)};`);
  }
  return html;
}

const MIME = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png', '.json': 'application/json', '.wav': 'audio/wav' };
const srv = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/' || url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(patchedIndex());
    return;
  }
  const fp = path.join(BUNDLE, url);
  if (fs.existsSync(fp) && fs.statSync(fp).isFile()) {
    res.writeHead(200, { 'Content-Type': MIME[path.extname(fp)] || 'application/octet-stream' });
    fs.createReadStream(fp).pipe(res);
  } else { res.writeHead(404); res.end(); }
});

const KEY_TEXT = { Space: ' ', Enter: '\r' };
function keyInfo(code) {
  const m = code.match(/^(Key|Digit)(.)$/);
  const key = m ? m[2].toLowerCase() : (code === 'Space' ? ' ' : code);
  const vk = m ? m[2].toUpperCase().charCodeAt(0)
    : ({ Space: 32, Enter: 13, Escape: 27, Backspace: 8, ArrowLeft: 37, ArrowUp: 38, ArrowRight: 39, ArrowDown: 40, Equal: 187, Minus: 189 })[code] || 0;
  return { code, key, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk, text: KEY_TEXT[code] || (m ? key : undefined) };
}

srv.listen(PORT, '127.0.0.1', async () => {
  const userData = path.resolve(OUT, '_prof_' + PORT);
  const proc = spawn(BROWSER, [
    '--headless=new', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required',
    `--remote-debugging-port=${DBG_PORT}`, `--window-size=${VW},${VH}`, `--user-data-dir=${userData}`,
    '--no-first-run', '--no-default-browser-check', `http://127.0.0.1:${PORT}/`,
  ], { stdio: 'ignore' });

  const sleep = ms => new Promise(r => setTimeout(r, ms));
  let ws;
  for (let i = 0; i < 40; i++) {
    await sleep(250);
    try {
      const list = await (await fetch(`http://127.0.0.1:${DBG_PORT}/json`)).json();
      const page = list.find(t => t.type === 'page');
      if (page) { ws = new WebSocket(page.webSocketDebuggerUrl); break; }
    } catch {}
  }
  if (!ws) { proc.kill(); srv.close(); console.error('CDP connect failed'); process.exit(1); }

  let msgId = 0;
  let errors = 0;
  const cdp = (method, params = {}) => new Promise(res => {
    const id = ++msgId;
    const onMsg = ev => {
      const d = JSON.parse(ev.data);
      if (d.id === id) { ws.removeEventListener('message', onMsg); res(d.result); }
    };
    ws.addEventListener('message', onMsg);
    ws.send(JSON.stringify({ id, method, params }));
  });
  ws.addEventListener('message', ev => {
    const d = JSON.parse(ev.data);
    if (d.method === 'Runtime.consoleAPICalled') {
      const line = d.params.args.map(a => a.value || a.description).join(' ');
      if (/ERROR|WARNING:SCRIPT|stack traceback/.test(line)) { errors++; console.log('[console]', line); }
      else if (process.env.SMOKE_VERBOSE || /\[poki\]/.test(line)) console.log('[console]', line.trim());
    } else if (d.method === 'Runtime.exceptionThrown') {
      errors++;
      const ex = d.params.exceptionDetails;
      console.error('[js-err]', ex.text, ex.exception && ex.exception.description);
    }
  });

  await new Promise(r => ws.addEventListener('open', r));
  await cdp('Runtime.enable');
  await cdp('Emulation.setDeviceMetricsOverride', { width: VW, height: VH, deviceScaleFactor: 1, mobile: opt.touch === '1' });
  if (opt.touch === '1') await cdp('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });

  const shot = async name => {
    const s = await cdp('Page.captureScreenshot', { format: 'png' });
    const p = path.join(OUT, `${name}_${VW}x${VH}.png`);
    fs.writeFileSync(p, Buffer.from(s.data, 'base64'));
    console.log('Saved screenshot:', p);
  };
  const mouse = (type, x, y, button = 'left', extra = {}) =>
    cdp('Input.dispatchMouseEvent', { type, x, y, button, clickCount: 1, ...extra });
  const touch = (type, touchPoints) => cdp('Input.dispatchTouchEvent', { type, touchPoints });
  const key = (type, code) => cdp('Input.dispatchKeyEvent', { type, ...keyInfo(code) });

  if (!opt.steps) {
    await sleep(Number(opt.secs) * 1000);
    await shot('boot');
  } else {
    for (const step of opt.steps.split(';').filter(Boolean)) {
      const i = step.indexOf(':');
      const cmd = i < 0 ? step : step.slice(0, i);
      const arg = i < 0 ? '' : step.slice(i + 1);
      const n = arg.split(',').map(Number);
      if (cmd === 'wait') await sleep(n[0] * 1000);
      else if (cmd === 'shot') await shot(arg || 'step');
      else if (cmd === 'move') { await mouse('mouseMoved', n[0], n[1], 'none'); await sleep(100); }
      else if (cmd === 'click' || cmd === 'rclick') {
        const b = cmd === 'rclick' ? 'right' : 'left';
        await mouse('mouseMoved', n[0], n[1], 'none');
        await mouse('mousePressed', n[0], n[1], b);
        await sleep(80);
        await mouse('mouseReleased', n[0], n[1], b);
        await sleep(150);
      } else if (cmd === 'drag') {
        await mouse('mouseMoved', n[0], n[1], 'none');
        await mouse('mousePressed', n[0], n[1]);
        for (let k = 1; k <= 8; k++) {
          await sleep(30);
          await mouse('mouseMoved', n[0] + (n[2] - n[0]) * k / 8, n[1] + (n[3] - n[1]) * k / 8, 'left', { buttons: 1 });
        }
        await mouse('mouseReleased', n[2], n[3]);
        await sleep(150);
      } else if (cmd === 'wheel') {
        await cdp('Input.dispatchMouseEvent', { type: 'mouseWheel', x: n[0], y: n[1], deltaX: 0, deltaY: n[2] });
        await sleep(120);
      } else if (cmd === 'touchtap') {
        await touch('touchStart', [{ x: n[0], y: n[1], id: 0 }]);
        await sleep(80);
        await touch('touchEnd', []);
        await sleep(150);
      } else if (cmd === 'touchdrag') {
        await touch('touchStart', [{ x: n[0], y: n[1], id: 0 }]);
        for (let k = 1; k <= 8; k++) {
          await sleep(30);
          await touch('touchMove', [{ x: n[0] + (n[2] - n[0]) * k / 8, y: n[1] + (n[3] - n[1]) * k / 8, id: 0 }]);
        }
        await touch('touchEnd', []);
        await sleep(150);
      } else if (cmd === 'key') {
        await key('keyDown', arg);
        await sleep(60);
        await key('keyUp', arg);
        await sleep(100);
      } else if (cmd === 'hold') {
        const [code, secs] = arg.split(',');
        await key('keyDown', code);
        await sleep(Number(secs) * 1000);
        await key('keyUp', code);
      }
    }
  }
  console.log(`Lua/JS errors: ${errors}`);
  ws.close();
  proc.kill();
  srv.close();
  try { fs.rmSync(userData, { recursive: true, force: true }); } catch {}
  process.exitCode = errors > 0 ? 1 : 0;
});
