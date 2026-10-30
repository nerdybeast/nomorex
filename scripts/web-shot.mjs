#!/usr/bin/env node
//
// Screenshots a route of the built web app in headless Chromium, for Claude
// Code on the web where claude-in-chrome isn't available.
//
// Usage:
//   flutter build web --debug --dart-define-from-file=.env.local.json
//   node scripts/web-shot.mjs [route] [out.png]
//   node scripts/web-shot.mjs /shell/home /tmp/home.png
//
// Verifies RENDERING only. Flutter paints to a canvas, so list-tile taps are
// unreliable here; cover tap-driven behaviour with widget tests instead. Signs
// in through the DOM login inputs as the seeded a@a.com / 123456 user, so the
// local Supabase stack must be up and seeded.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { chromium } from 'playwright';

const route = process.argv[2] ?? '/shell/home';
const out = process.argv[3] ?? 'web-shot.png';
const root = join(process.cwd(), 'build', 'web');

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
};

const server = createServer(async (req, res) => {
  const path = normalize(new URL(req.url, 'http://x').pathname);
  const file = join(root, path === '/' ? 'index.html' : path);
  if (!file.startsWith(root)) { res.writeHead(403).end(); return; }
  try {
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 420, height: 900 } });
  await page.goto(base);

  // Flutter's login fields are DOM-backed inputs once semantics are enabled.
  await page.getByRole('textbox').first().waitFor({ timeout: 60_000 }).catch(() => {});
  const boxes = page.getByRole('textbox');
  if ((await boxes.count()) >= 2) {
    await boxes.nth(0).fill('a@a.com');
    await boxes.nth(1).fill('123456');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);
  }

  await page.goto(`${base}/#${route}`);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: out });
  console.log(`wrote ${out} (${route})`);
} finally {
  await browser.close();
  server.close();
}
