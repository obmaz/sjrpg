#!/usr/bin/env node
// Test install state handling with explicit synthetic native events, plus a real SW/manifest.
// These checks do not install an app or establish installation on the user's device.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
const { chromium } = createRequire(import.meta.url)('playwright');
const server = createServer(async (request, response) => {
  const url = new URL(request.url, 'http://localhost');
  const file = url.pathname.replace(/^\/sjrpg2\//, '');
  if (!file) {
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    response.end(`<!doctype html><html lang="ko"><head>${url.searchParams.has('manifest') ? '<link rel="manifest" href="manifest.webmanifest">' : ''}</head><body><button id="install">설치</button><script src="install.js"></script><script>document.getElementById('install').onclick=()=>window.SjrpgInstall.request();</script></body></html>`);
    return;
  }
  const types = { js: 'text/javascript', webmanifest: 'application/manifest+json', png: 'image/png' };
  try {
    if (!/^(install(?:-sw)?\.js|manifest\.webmanifest|install-(?:180|192|512)\.png)$/.test(file)) throw new Error('missing');
    response.setHeader('Content-Type', types[file.split('.').at(-1)]);
    response.end(await readFile(new URL(file, import.meta.url)));
  } catch (_) { response.writeHead(404); response.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}/sjrpg2/`;
const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
try {
  const page = await browser.newPage();
  await page.goto(base);
  assert.equal(await page.evaluate(() => window.SjrpgInstall.state().status), 'manual');
  const offer = async (mode = 'choice') => page.evaluate(mode => {
    const event = new Event('beforeinstallprompt', { cancelable: true });
    event.prompt = () => {
      window.promptCalls = (window.promptCalls || 0) + 1;
      if (mode === 'throws') throw new Error('native prompt unavailable');
      return Promise.resolve();
    };
    event.userChoice = new Promise(resolve => { window.resolveChoice = resolve; });
    window.dispatchEvent(event);
    return event.defaultPrevented;
  }, mode);
  assert.equal(await offer(), true);
  assert.equal(await page.evaluate(() => window.SjrpgInstall.state().status), 'available');
  await page.evaluate(() => {
    // Playwright evaluations themselves carry CDP userGesture; explicitly exercise inactivity.
    Object.defineProperty(navigator, 'userActivation', { configurable: true, value: { isActive: false } });
    window.SjrpgInstall.request();
    delete navigator.userActivation;
  });
  assert.equal(await page.evaluate(() => window.promptCalls || 0), 0, 'a programmatic call must preserve a gesture-bound offer');
  await page.click('#install');
  assert.equal(await page.evaluate(() => window.SjrpgInstall.state().status), 'prompting');
  await page.click('#install');
  assert.equal(await page.evaluate(() => window.promptCalls), 1, 'a pending prompt cannot be invoked twice');
  await page.evaluate(() => window.resolveChoice({ outcome: 'dismissed' }));
  await page.waitForFunction(() => window.SjrpgInstall.state().status === 'manual');
  assert.match(await page.evaluate(() => window.SjrpgInstall.state().detail), /취소/);
  await offer('throws');
  await page.click('#install');
  assert.equal(await page.evaluate(() => window.SjrpgInstall.state().status), 'manual');
  assert.match(await page.evaluate(() => window.SjrpgInstall.state().detail), /열지 못/);
  await offer();
  await page.click('#install');
  await page.evaluate(() => window.resolveChoice({ outcome: 'accepted' }));
  await page.waitForFunction(() => window.SjrpgInstall.state().status !== 'prompting');
  assert.equal(await page.evaluate(() => window.SjrpgInstall.state().status), 'manual', 'native acceptance alone is not proof of installation');
  assert.match(await page.evaluate(() => window.SjrpgInstall.state().detail), /요청했습니다/);
  await page.evaluate(() => window.dispatchEvent(new Event('appinstalled')));
  assert.equal(await page.evaluate(() => window.SjrpgInstall.state().status), 'installed', 'explicit synthetic installation event exercises state handling only');
  await page.close();
  const ios = await browser.newPage({ userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1' });
  await ios.goto(base);
  assert.match(await ios.evaluate(() => window.SjrpgInstall.state().detail), /Safari.*홈 화면에 추가/);
  await ios.close();
  const context = await browser.newContext();
  const live = await context.newPage();
  await live.goto(base + '?manifest=1');
  await live.evaluate(() => navigator.serviceWorker.ready);
  await live.waitForFunction(() => navigator.serviceWorker.controller !== null);
  const cdp = await context.newCDPSession(live);
  const manifest = await cdp.send('Page.getAppManifest');
  assert.equal(manifest.errors.length, 0);
  const data = JSON.parse(manifest.data);
  assert.equal(data.display, 'standalone');
  assert.equal(data.scope, './');
  for (const icon of data.icons) assert.equal((await live.request.get(new URL(icon.src, base).href)).status(), 200);
  const eligibility = await cdp.send('Page.getInstallabilityErrors');
  assert.equal(eligibility.installabilityErrors.length, 0, JSON.stringify(eligibility.installabilityErrors));
  assert.equal(await live.evaluate(async () => (await navigator.serviceWorker.getRegistration()).scope), base);
  await context.setOffline(true);
  await live.reload();
  assert.match(await live.locator('main').textContent(), /인터넷 연결이 필요/);
  await context.setOffline(false);
  await live.click('button');
  await live.locator('#install').waitFor();
  await context.close();
  console.log('install: synthetic state/gesture/cancel/error/acceptance checks + iOS guide + real manifest/worker/offline navigation passed; no actual app installation performed');
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
