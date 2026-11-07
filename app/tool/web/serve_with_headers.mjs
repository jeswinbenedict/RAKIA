// SPDX-License-Identifier: Apache-2.0
//
// Serves a built web app (default: build/web) on localhost with the response
// headers from its _headers file applied, the way Cloudflare Pages does, so
// the Content-Security-Policy and isolation headers can be checked before
// deploying. Development tool only; not part of the app.
//
// Usage (from app/): node tool/web/serve_with_headers.mjs [dir] [port]
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';

const root = resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? 5000);

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.symbols': 'text/plain',
  '.bin': 'application/octet-stream',
  '.frag': 'application/octet-stream',
};

// _headers: a path pattern line, then indented "Name: value" lines. Only
// the "/*" pattern is used by RAKIA, so that is all this supports.
async function loadHeaders() {
  const text = await readFile(join(root, '_headers'), 'utf8');
  const headers = {};
  let inAll = false;
  for (const line of text.split(/\r?\n/)) {
    if (line.startsWith('#') || line.trim() === '') continue;
    if (!line.startsWith(' ')) {
      inAll = line.trim() === '/*';
      continue;
    }
    if (!inAll) continue;
    const i = line.indexOf(':');
    headers[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return headers;
}

const headers = await loadHeaders();

createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  let path = normalize(join(root, decodeURIComponent(url.pathname)));
  if (path !== root && !path.startsWith(root + sep)) {
    res.writeHead(403).end();
    return;
  }
  try {
    if ((await stat(path)).isDirectory()) path = join(path, 'index.html');
  } catch {
    // Single-page app: unknown paths get index.html, as on Pages.
    path = join(root, 'index.html');
  }
  try {
    const body = await readFile(path);
    res.writeHead(200, {
      ...headers,
      'Content-Type': types[extname(path)] ?? 'application/octet-stream',
    });
    res.end(body);
  } catch {
    res.writeHead(404, headers).end();
  }
}).listen(port, '127.0.0.1', () => {
  console.log(`Serving ${root} on http://127.0.0.1:${port} with ${Object.keys(headers).length} headers`);
});
