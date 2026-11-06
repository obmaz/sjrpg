#!/usr/bin/env node
// Real DOM fullscreen enter/exit with trusted browser input. Installed display
// modes are explicit fixtures, not a claim of installing an app on this machine.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
const { chromium } = createRequire(import.meta.url)('playwright');
const template = await readFile(new URL('./shell.html', import.meta.url), 'utf8');
assert.match(template, /mobile-web-app-capable" content="yes/);
assert.match(template, /apple-mobile-web-app-capable" content="yes/);
assert.match(template, /#canvas\s*\{ position:fixed; inset:0; display:block; width:100%; height:100%; max-width:100%; max-height:100%/);
const server = createServer(async (request, response) => {
  const url = new URL(request.url, 'http://localhost');
  const file = url.pathname.replace(/^\/sjrpg\/3d\//, '');
  if (!file) {
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    response.end(`<!doctype html><html><head><link rel="manifest" href="manifest.webmanifest"></head><body>
      <canvas id="canvas" width="720" height="1280" style="position:fixed;inset:0;width:100%;height:100%;z-index:-1"></canvas>
      <section id="entry-overlay"><button id="start">모험 시작</button></section><button id="fullscreen">전체화면</button>
      <script src="fullscreen.js"></script><script src="install.js"></script>
      <script>window.starts=0;document.getElementById('start').onclick=()=>window.starts++;document.getElementById('fullscreen').onclick=()=>window.SjrpgFullscreen.toggle();</script>
      </body></html>`);
    return;
  }
  try {
    if (!/^(fullscreen\.js|install(?:-sw)?\.js|manifest\.webmanifest|install-(?:180|192|512)\.png)$/.test(file)) throw Error('missing');
    response.setHeader('Content-Type', file.endsWith('.js') ? 'text/javascript' : file.endsWith('.webmanifest') ? 'application/manifest+json' : 'image/png');
    response.end(await readFile(new URL(file, import.meta.url)));
  } catch (_) { response.writeHead(404); response.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}/sjrpg/3d/`;
const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-gpu'] });
try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(base);
  assert.equal(await page.evaluate(() => window.SjrpgFullscreen.state().active), false);
  await page.click('#start');
  assert.equal(await page.evaluate(() => document.fullscreenElement !== null), false, 'ordinary browser launch never forces fullscreen');
  await page.click('#fullscreen');
  await page.waitForFunction(() => document.fullscreenElement === document.documentElement);
  assert.equal(await page.evaluate(() => window.SjrpgFullscreen.state().active), true);
  assert.notEqual(await page.evaluate(() => window.SjrpgInstall.state().status), 'installed', 'DOM fullscreen is not installation');
  assert.equal(await page.evaluate(() => window.SjrpgFullscreen.state().installed), false);
  await page.waitForFunction(() => !window.SjrpgFullscreen.state().pending);
  await page.click('#fullscreen');
  await page.waitForFunction(() => document.fullscreenElement === null);
  assert.equal(await page.evaluate(() => window.SjrpgFullscreen.state().active), false);
  await page.evaluate(() => {
    Element.prototype.requestFullscreen = () => Promise.reject(new DOMException('blocked', 'NotAllowedError'));
  });
  await page.click('#fullscreen');
  await page.waitForFunction(() => !window.SjrpgFullscreen.state().pending && window.SjrpgFullscreen.state().detail.includes('전환하지 못했습니다'));
  assert.equal(await page.evaluate(() => window.SjrpgFullscreen.state().active), false, 'a rejected API call must not claim fullscreen');
  assert.deepEqual(errors, []);
  await page.close();

  const installedPage = async (mode, noAPI = false) => {
    const next = await browser.newPage();
    await next.addInitScript(({ mode, noAPI }) => {
      const original = window.matchMedia.bind(window);
      window.matchMedia = query => query === `(display-mode: ${mode})` ? { matches: true, addEventListener() {}, removeEventListener() {} } : original(query);
      if (mode === 'ios') Object.defineProperty(navigator, 'standalone', { configurable: true, value: true });
      if (noAPI) {
        Element.prototype.requestFullscreen = undefined;
        Element.prototype.webkitRequestFullscreen = undefined;
      }
    }, { mode, noAPI });
    await next.goto(base);
    return next;
  };
  const manifestApp = await installedPage('fullscreen');
  assert.equal(await manifestApp.evaluate(() => window.SjrpgInstall.state().status), 'installed');
  assert.deepEqual(await manifestApp.evaluate(() => {
    const s = window.SjrpgFullscreen.state();
    return [s.active, s.supported, s.title];
  }), [true, false, '전체화면 사용 중'], 'manifest fullscreen must not advertise an impossible programmatic exit');
  await manifestApp.close();

  const standalone = await installedPage('standalone');
  assert.equal(await standalone.evaluate(() => window.SjrpgInstall.state().status), 'installed');
  assert.equal(await standalone.evaluate(() => document.fullscreenElement === null), true);
  await standalone.evaluate(() => document.dispatchEvent(new MouseEvent('click', { bubbles: true })));
  assert.equal(await standalone.evaluate(() => document.fullscreenElement === null), true, 'synthetic events cannot trigger installed startup fullscreen');
  await standalone.click('#start');
  await standalone.waitForFunction(() => document.fullscreenElement === document.documentElement);
  assert.equal(await standalone.evaluate(() => window.starts), 1, 'installed fullscreen fallback preserves the initiating Start action exactly once');
  assert.equal(await standalone.locator('#entry-overlay').isVisible(), true, 'the DOM entry/title sibling stays visible because the whole document is fullscreen');
  await standalone.waitForFunction(() => !window.SjrpgFullscreen.state().pending);
  await standalone.click('#fullscreen');
  await standalone.waitForFunction(() => document.fullscreenElement === null);
  await standalone.click('#start');
  assert.equal(await standalone.evaluate(() => document.fullscreenElement === null), true, 'the fallback respects later manual exits');
  assert.equal(await standalone.evaluate(() => window.SjrpgInstall.state().status), 'installed');
  await standalone.close();

  const limitedApp = await installedPage('ios', true);
  const limited = await limitedApp.evaluate(() => window.SjrpgFullscreen.state());
  assert.equal(limited.installed, true);
  assert.equal(limited.active, false);
  assert.equal(limited.supported, false);
  assert.match(limited.detail, /별도 전체화면 전환은 지원하지 않습니다/);
  await limitedApp.click('#start');
  assert.equal(await limitedApp.evaluate(() => document.fullscreenElement === null), true);
  await limitedApp.close();
  console.log('fullscreen: real trusted enter/exit, normal-tab install isolation, installed manifest/standalone defaults, gesture fallback, manual exit and platform limits passed (no WebGL/app installation)');
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
