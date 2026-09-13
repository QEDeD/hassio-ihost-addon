'use strict';
// Serve only a synthetic fixture and installed assets on loopback.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
if (process.argv.length !== 4) throw Error('Usage: node serve.cjs INSTALLED_FRONTEND JSQR_JS');
const frontend = path.resolve(process.argv[2]);
const decoder = path.resolve(process.argv[3]);
for (const file of [path.join(frontend, 'res/js/app.js'), decoder]) fs.accessSync(file);
http.createServer((req, res) => {
  const pathname = new URL(req.url, 'http://127.0.0.1').pathname;
  if (pathname === '/get_qrcode') {
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({result: 'successful', eui64: '0000aBcD0000Ef01'}));
    return;
  }
  let file;
  if (pathname === '/' || pathname === '/index.html') file = path.join(__dirname, 'fixture.html');
  else if (pathname === '/res/js/jsQR.js') file = decoder;
  else if (pathname === '/join.dialog.html' || pathname.startsWith('/res/')) {
    file = path.resolve(frontend, '.' + pathname);
    if (!file.startsWith(frontend + path.sep)) { res.writeHead(403); res.end(); return; }
  } else { res.writeHead(404); res.end(); return; }
  fs.readFile(file, (error, data) => {
    if (error) { res.writeHead(404); res.end(); return; }
    const types = {'.js': 'application/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.svg': 'image/svg+xml'};
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    res.end(data);
  });
}).listen(18764, '127.0.0.1', () => console.log('Synthetic QR test server on http://127.0.0.1:18764'));
