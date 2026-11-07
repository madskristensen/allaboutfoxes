import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const images = join(root, 'assets', 'images');
const browserPath = process.env.BROWSER_PATH || [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  '/usr/bin/chromium',
  '/usr/bin/google-chrome',
].find(existsSync);
if (!browserPath) throw new Error('Set BROWSER_PATH to an installed Edge or Chromium executable.');

const profile = await mkdtemp(join(tmpdir(), 'fox-artwork-'));
let socket;
let browserError;
const browser = spawn(browserPath, [
  '--headless=new', '--no-first-run', '--no-default-browser-check',
  '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank',
], { stdio: 'ignore' });
browser.on('error', error => { browserError = error; });

try {
  const portFile = join(profile, 'DevToolsActivePort');
  for (let attempt = 0; !existsSync(portFile); attempt++) {
    if (browserError) throw browserError;
    if (attempt === 150) throw new Error('Browser debugging endpoint did not become available.');
    await delay(100);
  }
  const port = (await readFile(portFile, 'utf8')).split('\n')[0].trim();
  const response = await fetch(`http://127.0.0.1:${port}/json/list`);
  if (!response.ok) throw new Error(`Browser target lookup failed: ${response.status}`);
  const target = (await response.json()).find(item => item.type === 'page');
  if (!target) throw new Error('Browser did not provide a page target.');
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let sequence = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    const request = pending.get(message.id);
    if (!request) return;
    clearTimeout(request.timer);
    pending.delete(message.id);
    if (message.error) request.reject(new Error(JSON.stringify(message.error)));
    else request.resolve(message.result);
  });
  const call = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`Browser request timed out: ${method}`));
    }, 15000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params }));
  });
  await call('Page.enable');
  await call('Emulation.setDefaultBackgroundColorOverride', { color: { r: 250, g: 247, b: 239, a: 1 } });
  const exports = [
    ['social-card', 'social-card', 1200, 630],
    ['social-foxes', 'social-foxes', 1200, 630],
    ['social-quiz', 'social-quiz', 1200, 630],
    ['social-trail', 'social-trail', 1200, 630],
    ['app-icon', 'icon-192', 192, 192],
    ['app-icon', 'icon-512', 512, 512],
    ['app-icon', 'apple-touch-icon', 180, 180],
    ['app-icon', 'icon-maskable-512', 512, 512, 'translate(76 75) scale(3.6)'],
    ['fox-mark', 'favicon-32', 32, 32],
  ];
  for (const [source, name, width, height, transform] of exports) {
    await call('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
    const url = pathToFileURL(join(images, `${source}.svg`)).href;
    const navigation = await call('Page.navigate', { url });
    if (navigation.errorText) throw new Error(navigation.errorText);
    for (let attempt = 0; ; attempt++) {
      const state = await call('Runtime.evaluate', { expression: `location.href === ${JSON.stringify(url)} && document.readyState === 'complete'`, returnByValue: true });
      if (state.result.value) break;
      if (attempt === 100) throw new Error(`SVG did not load: ${source}`);
      await delay(50);
    }
    const rendered = await call('Runtime.evaluate', {
      expression: `(() => {
        const svg = document.documentElement;
        if (svg.localName !== 'svg') throw new Error('Expected an SVG document');
        svg.setAttribute('width', '${width}');
        svg.setAttribute('height', '${height}');
        const transform = ${JSON.stringify(transform ?? null)};
        if (transform) svg.querySelector('g').setAttribute('transform', transform);
        return document.fonts.ready.then(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      })()`, awaitPromise: true,
    });
    if (rendered.exceptionDetails) throw new Error(JSON.stringify(rendered.exceptionDetails));
    const screenshot = await call('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width, height, scale: 1 } });
    const png = Buffer.from(screenshot.data, 'base64');
    if (png.readUInt32BE(16) !== width || png.readUInt32BE(20) !== height) throw new Error(`Unexpected export dimensions: ${name}`);
    await writeFile(join(images, `${name}.png`), png);
    console.log(`${name}.png: ${width} x ${height}`);
  }
} finally {
  if (socket?.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify({ id: 1000000, method: 'Browser.close' }));
    socket.close();
  }
  await delay(2000);
  await rm(profile, { recursive: true, maxRetries: 5, retryDelay: 500 });
}
