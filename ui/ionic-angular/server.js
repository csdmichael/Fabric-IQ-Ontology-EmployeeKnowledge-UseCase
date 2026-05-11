const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || '8080', 10);
const PUBLIC = path.join(__dirname, 'public');
const API_BASE_URL = process.env.API_BASE_URL || 'https://fabric-iq-emp-knowledge-api.azurewebsites.net';
// Repo root is two directories above this file (ui/ionic-angular/ -> repo root)
const REPO_ROOT = path.resolve(__dirname, '..', '..');

// Static data directories served from the repo root.
// URL prefix -> absolute filesystem base directory.
const REPO_STATIC = [
  { prefix: '/data/',   dir: path.join(REPO_ROOT, 'data') },
  { prefix: '/fabric/', dir: path.join(REPO_ROOT, 'fabric') },
  { prefix: '/config/', dir: path.join(REPO_ROOT, 'config') },
];

const MIME = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

/**
 * Resolve the filesystem path for a URL pathname.
 * Returns null if no mapping matches.
 */
function resolveRepoPath(pathname) {
  for (const { prefix, dir } of REPO_STATIC) {
    if (pathname.startsWith(prefix) || pathname === prefix.slice(0, -1)) {
      const relative = pathname.slice(prefix.length);
      // Prevent path-traversal attacks
      const resolved = path.resolve(dir, relative);
      if (!resolved.startsWith(dir + path.sep) && resolved !== dir) return null;
      return resolved;
    }
  }
  return null;
}

function serve(res, filePath) {
  const ext = path.extname(filePath);
  fs.readFile(filePath, (err, data) => {
    if (err) {
      // SPA fallback – serve index.html for unknown routes
      fs.readFile(path.join(PUBLIC, 'index.html'), (e2, html) => {
        if (e2) { res.writeHead(500); res.end('Internal error'); return; }
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(html);
      });
      return;
    }
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  });
}

function proxyApi(req, res, pathname, search) {
  const targetBase = new URL(API_BASE_URL);
  const targetPath = `${pathname}${search || ''}`;
  const client = targetBase.protocol === 'http:' ? http : https;

  const proxyReq = client.request(
    {
      protocol: targetBase.protocol,
      hostname: targetBase.hostname,
      port: targetBase.port || (targetBase.protocol === 'https:' ? 443 : 80),
      method: req.method,
      path: targetPath,
      headers: {
        ...req.headers,
        host: targetBase.host,
      },
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode || 502, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on('error', (error) => {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'API proxy failed', details: String(error) }));
  });

  req.pipe(proxyReq);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;

  // Dynamic API proxy: route /api/* through the backend App Service.
  if (pathname === '/api' || pathname.startsWith('/api/')) {
    proxyApi(req, res, pathname, url.search);
    return;
  }

  // Try repo-root data directories first
  const repoPath = resolveRepoPath(pathname);
  if (repoPath) {
    serve(res, repoPath);
    return;
  }

  // Fall back to public/ (SPA)
  const filePath = path.join(PUBLIC, pathname === '/' ? 'index.html' : pathname);
  serve(res, filePath);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Fabric IQ UI listening on http://0.0.0.0:${PORT}`);
});
