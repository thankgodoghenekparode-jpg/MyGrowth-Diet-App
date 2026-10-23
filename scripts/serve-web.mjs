/**
 * Static file server for the built Flutter web app.
 *
 * Usage:
 *   node scripts/serve-web.mjs [port] [root]
 *
 * Defaults to port 8080 and the release build in
 * `Frontend/mygrowth_app/build/web`. Flutter's web build needs a server that
 * falls back to `index.html` for unknown paths so client-side routes such as
 * `/diet` and `/admin/daily-diet` resolve on a hard refresh.
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(
  process.argv[3] ?? path.join(here, '..', 'Frontend', 'mygrowth_app', 'build', 'web')
);
const port = Number(process.argv[2] ?? 8080);

if (!fs.existsSync(root)) {
  console.error(`[serve-web] ${root} does not exist — run "flutter build web" first.`);
  process.exit(1);
}

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.bin': 'application/octet-stream',
  '.symbols': 'application/octet-stream',
};

function send(res, status, body, type) {
  res.writeHead(status, {
    'Content-Type': type,
    'Cache-Control': 'no-cache',
    // The Flutter loader and service worker need cross-origin isolation for
    // SharedArrayBuffer-backed builds; harmless for the standard build.
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'credentialless',
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const relative = decodeURIComponent(url.pathname).replace(/^\/+/, '');
  let file = path.join(root, relative);

  // Never serve anything outside the build directory.
  if (!file.startsWith(root)) {
    send(res, 403, 'Forbidden', 'text/plain; charset=utf-8');
    return;
  }

  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    const indexCandidate = path.join(file, 'index.html');
    if (fs.existsSync(indexCandidate)) {
      file = indexCandidate;
    } else {
      // Client-side route fallback.
      file = path.join(root, 'index.html');
      if (!fs.existsSync(file)) {
        send(res, 404, 'Not found', 'text/plain; charset=utf-8');
        return;
      }
    }
  }

  const type = TYPES[path.extname(file).toLowerCase()] ?? 'application/octet-stream';
  send(res, 200, fs.readFileSync(file), type);
});

server.listen(port, () => {
  console.log(`[serve-web] ${root} -> http://localhost:${port}`);
});
