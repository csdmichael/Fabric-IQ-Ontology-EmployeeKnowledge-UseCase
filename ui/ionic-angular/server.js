const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || '8080', 10);
const PUBLIC = path.join(__dirname, 'public');

const MIME = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

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

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  let filePath = path.join(PUBLIC, url.pathname === '/' ? 'index.html' : url.pathname);
  serve(res, filePath);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Fabric IQ UI listening on http://0.0.0.0:${PORT}`);
});
