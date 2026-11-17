// Tiny Chrome DevTools Protocol client (Node 22+, no dependencies) for live-testing the web
// build in a real Chrome with a real GPU.
//   node tools/cdp.mjs shot <file.png>
//   node tools/cdp.mjs click <x> <y>
//   node tools/cdp.mjs key <Code> <down|up|tap> [holdMs]     e.g. key KeyD down ... key KeyD up
//   node tools/cdp.mjs eval "<js expression>"
//   node tools/cdp.mjs goto <url>
// Chrome must already be running with --remote-debugging-port=9333.
import { writeFileSync } from 'node:fs';

const KEYS = {
  KeyD: ['d', 68], KeyA: ['a', 65], KeyS: ['s', 83], KeyW: ['w', 87], KeyR: ['r', 82],
  Space: [' ', 32], ShiftLeft: ['Shift', 16], Escape: ['Escape', 27], Tab: ['Tab', 9],
  Enter: ['Enter', 13], ArrowDown: ['ArrowDown', 40], ArrowUp: ['ArrowUp', 38],
};

const list = await (await fetch('http://127.0.0.1:9333/json')).json();
const page = list.find((t) => t.type === 'page');
if (!page) { console.error('no page target'); process.exit(2); }
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  if (d.id && pending.has(d.id)) { pending.get(d.id)(d); pending.delete(d.id); }
};
const send = (method, params = {}) => new Promise((res) => {
  const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params }));
});

const [cmd, ...a] = process.argv.slice(2);
if (cmd === 'shot') {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(a[0], Buffer.from(r.result.data, 'base64'));
  console.log('saved', a[0]);
} else if (cmd === 'click') {
  const x = Number(a[0]), y = Number(a[1]);
  await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  console.log('clicked', x, y);
} else if (cmd === 'key') {
  const code = a[0]; const mode = a[1] || 'tap'; const hold = Number(a[2] || 80);
  const [key, vk] = KEYS[code] || [code, 0];
  const ev = (type) => send('Input.dispatchKeyEvent', {
    type, key, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk,
    text: type === 'keyDown' && key.length === 1 ? key : undefined,
  });
  if (mode === 'down') await ev('keyDown');
  else if (mode === 'up') await ev('keyUp');
  else { await ev('keyDown'); await new Promise((r) => setTimeout(r, hold)); await ev('keyUp'); }
  console.log('key', code, mode);
} else if (cmd === 'eval') {
  const r = await send('Runtime.evaluate', { expression: a[0], awaitPromise: true, returnByValue: true });
  console.log(JSON.stringify(r.result?.result?.value ?? r.result));
} else if (cmd === 'front') {
  await send('Page.bringToFront');
  await send('Emulation.setFocusEmulationEnabled', { enabled: true });
  console.log('fronted');
} else if (cmd === 'goto') {
  await send('Page.navigate', { url: a[0] });
  console.log('navigated');
}
ws.close();
process.exit(0);
