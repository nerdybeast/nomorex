#!/usr/bin/env node
//
// Screenshots a route of the built web app in headless Chromium, for Claude
// Code on the web where claude-in-chrome isn't available.
//
// Usage:
//   flutter build web --debug --dart-define-from-file=.env.local.json
//   node scripts/web-shot.mjs [route] [out.png] [--flow scripts/web-flows/x.mjs]
//   node scripts/web-shot.mjs /shell/home /tmp/home.png
//   node scripts/web-shot.mjs /shell/prs /tmp/prs.png --flow scripts/web-flows/add-pr.mjs
//
// Signs in as the seeded a@a.com / 123456 user (the local Supabase stack must
// be up and seeded), optionally runs a flow, then screenshots the route.
//
// Flutter paints to a canvas, so there are no DOM elements to select. Drive it
// with page.mouse.click(x, y) + page.keyboard.type(...): in headless Chromium
// that works for buttons, text fields, autocomplete options and steppers
// (unlike claude-in-chrome). Screenshot first to read off the coordinates.
// A flow is an ES module whose default export is `async (page, { base, shot })`
// that runs after sign-in; `shot(name)` saves a screenshot next to out.png.
// Navigate inside a flow with `page.goto(`${base}/#/route`)`.

import { createServer } from 'node:http';
import { execSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { dirname, extname, join, normalize, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// Playwright is installed globally in cloud sessions, and ES module imports
// ignore NODE_PATH, so fall back to the global root when a bare import fails.
async function loadPlaywright() {
  try {
    return await import('playwright');
  } catch {
    const globalRoot = execSync('npm root -g').toString().trim();
    return await import(pathToFileURL(join(globalRoot, 'playwright', 'index.mjs')));
  }
}
const { chromium } = await loadPlaywright();

const args = process.argv.slice(2);
const flowIdx = args.indexOf('--flow');
const flowPath = flowIdx >= 0 ? args.splice(flowIdx, 2)[1] : null;
const route = args[0] ?? '/shell/home';
const out = args[1] ?? 'web-shot.png';
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

  // The app opens on the landing page; the login form lives at /login. Its
  // fields are canvas-drawn (a DOM input only exists while focused), so click
  // at the centre column: email, password, then the submit button.
  const { width } = page.viewportSize();
  const x = width / 2;
  await page.goto(`${base}/#/login`);
  await page.waitForTimeout(8_000);
  await page.mouse.click(x, 128);
  await page.keyboard.type('a@a.com');
  await page.mouse.click(x, 196);
  await page.keyboard.type('123456');
  await page.mouse.click(x, 262);
  await page.waitForTimeout(4_000);

  const shot = async (name) => {
    const file = join(dirname(resolve(out)), `${name}.png`);
    await page.screenshot({ path: file });
    console.log(`wrote ${file}`);
  };
  if (flowPath) {
    const flow = (await import(pathToFileURL(resolve(flowPath)))).default;
    await flow(page, { base, shot });
  }

  await page.goto(`${base}/#${route}`);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: out });
  console.log(`wrote ${out} (${route})`);
} finally {
  await browser.close();
  server.close();
}
