// SPDX-License-Identifier: Apache-2.0
//
// Loads a served web build in headless Chrome (over the DevTools protocol,
// no extra packages) and fails if:
//   - the app does not render (the splash screen is still there);
//   - any Content-Security-Policy violation, console error or uncaught
//     exception occurs;
//   - any request leaves the page's own origin (the build must be
//     self-contained: offline-first, and no third-party tracking);
//   - the page is not cross-origin isolated, or the local database did not
//     open on the Origin Private File System.
//
// Usage (from app/, with the build served by serve_with_headers.mjs):
//   node tool/web/check_web_build.mjs http://127.0.0.1:5000/
// CHROME selects the browser binary (default: the platform's usual path).
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const url = process.argv[2] ?? 'http://127.0.0.1:5000/';
const origin = new URL(url).origin;
// A build made with --dart-define=RAKIA_API_URL calls that API; pass the
// same URL in RAKIA_API_URL so requests to it are not reported as external.
const apiOrigin = process.env.RAKIA_API_URL ? new URL(process.env.RAKIA_API_URL).origin : null;
const chrome =
  process.env.CHROME ??
  (process.platform === 'win32'
    ? 'C:/Program Files/Google/Chrome/Application/chrome.exe'
    : process.platform === 'darwin'
      ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
      : 'google-chrome');
const port = 9300 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(join(tmpdir(), 'rakia-web-check-'));
const proc = spawn(chrome, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--window-size=1440,1000',
  'about:blank',
]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let ws;
for (let i = 0; i < 100 && !ws; i++) {
  try {
    const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    const page = list.find((t) => t.type === 'page');
    if (page) ws = new WebSocket(page.webSocketDebuggerUrl);
  } catch {
    await sleep(200);
  }
}
if (!ws) {
  console.error('Could not start or reach Chrome at', chrome);
  process.exit(2);
}
await new Promise((r) => ws.addEventListener('open', r));

let nextId = 0;
const pending = new Map();
const events = [];
ws.addEventListener('message', (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  } else {
    events.push(msg);
  }
});
const send = (method, params = {}) =>
  new Promise((r) => {
    const id = ++nextId;
    pending.set(id, r);
    ws.send(JSON.stringify({ id, method, params }));
  });
const evaluate = async (expression) =>
  (await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }))
    .result?.result?.value;

for (const domain of ['Runtime', 'Log', 'Network', 'Page']) await send(`${domain}.enable`);
await send('Page.navigate', { url });

// Wait for the first frame (the splash is removed then), up to 60 s.
let rendered = false;
for (let i = 0; i < 120 && !rendered; i++) {
  await sleep(500);
  rendered = await evaluate(
    "!!document.querySelector('flutter-view, flt-glass-pane') && !document.getElementById('splash')",
  );
}
await sleep(3000); // let start-up work (database open, core load) finish

const isolated = await evaluate('self.crossOriginIsolated');
const opfs = await evaluate(`(async () => {
  const names = [];
  const dir = await navigator.storage.getDirectory();
  for await (const [name] of dir.entries()) names.push(name);
  return names;
})()`);

const problems = [];
for (const e of events) {
  if (e.method === 'Log.entryAdded') {
    const { text, level } = e.params.entry;
    if (/Content Security Policy|Refused to/i.test(text)) problems.push(`CSP: ${text}`);
    else if (level === 'error') problems.push(`console: ${text}`);
  } else if (e.method === 'Runtime.consoleAPICalled' && e.params.type === 'error') {
    problems.push(`console: ${e.params.args.map((a) => a.value ?? a.description).join(' ')}`);
  } else if (e.method === 'Runtime.exceptionThrown') {
    const d = e.params.exceptionDetails;
    problems.push(`exception: ${d.exception?.description ?? d.text}`);
  } else if (e.method === 'Network.loadingFailed' && !e.params.canceled) {
    problems.push(`request failed: ${e.params.errorText} ${e.params.blockedReason ?? ''}`);
  } else if (e.method === 'Network.requestWillBeSent') {
    const u = e.params.request.url;
    const allowed = u.startsWith(origin) || (apiOrigin && u.startsWith(apiOrigin));
    if (!allowed && !/^(data|blob):/.test(u)) problems.push(`external request: ${u}`);
  }
}
if (!rendered) problems.push('the app did not render within 60 s');
if (isolated !== true) problems.push('the page is not cross-origin isolated (COOP/COEP headers)');
if (!Array.isArray(opfs) || opfs.length === 0) {
  problems.push(`the local database is not on the Origin Private File System (${JSON.stringify(opfs)})`);
}

ws.close();
proc.kill();
await sleep(500);
try {
  rmSync(profile, { recursive: true, force: true });
} catch {
  // Chrome may still hold the profile briefly; it is in the temp folder.
}

if (problems.length) {
  console.error(`Web build check failed (${problems.length}):`);
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}
console.log(`Web build check passed: rendered, cross-origin isolated, OPFS (${opfs.join(', ')}), no CSP violations, errors or external requests.`);
