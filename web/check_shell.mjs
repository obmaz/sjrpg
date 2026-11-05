#!/usr/bin/env node
// Browser checks for the pre-engine shell; no Godot process or export is required.
// Actual exported-engine startup is also checked by the normal web smoke run.
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const template = await readFile(new URL('./shell.html', import.meta.url), 'utf8');
const art = await readFile(new URL('./loading-bg.webp', import.meta.url));
const installer = await readFile(new URL('./install.js', import.meta.url), 'utf8');
const html = template.replaceAll('$GODOT_PROJECT_NAME', '자연의 수호자')
  .replaceAll('$GODOT_HEAD_INCLUDE', '').replaceAll('$GODOT_URL', 'engine.js')
  .replaceAll('$GODOT_CONFIG', '{}').replaceAll('$GODOT_THREADS_ENABLED', 'false');
const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
let checks = 0;
try {
  for (const viewport of [{ width: 412, height: 839 }, { width: 915, height: 412 }, { width: 568, height: 320 }]) {
    const page = await browser.newPage({ viewport, reducedMotion: 'reduce' });
    await page.route('https://loader.test/**', async route => {
      const name = new URL(route.request().url()).pathname;
      if (name === '/install.js') return route.fulfill({ contentType: 'text/javascript', body: installer });
      if (name === '/loading-bg.webp') return route.fulfill({ contentType: 'image/webp', body: art });
      if (name === '/engine.js') return route.fulfill({ contentType: 'text/javascript', body: `
        window.Engine = class {
          static getMissingFeatures() { return []; }
          startGame(options) {
            window.report = options.onProgress;
            return new Promise((resolve, reject) => { window.finish = resolve; window.fail = reject; });
          }
        };` });
      return route.fulfill({ contentType: 'text/html', body: html });
    });
    await page.goto('https://loader.test/');
    assert.equal(await page.locator('#amount').textContent(), '');
    assert.equal(await page.locator('#progress').getAttribute('value'), null);
    await page.evaluate(() => window.report(37 * 1048576, 100 * 1048576));
    assert.equal(await page.locator('#amount').textContent(), '37%');
    assert.equal(await page.locator('#progress').getAttribute('value'), String(37 * 1048576));
    const panel = await page.locator('.loading-panel').boundingBox();
    assert(panel.x >= 0 && panel.y >= 0 && panel.x + panel.width <= viewport.width && panel.y + panel.height <= viewport.height);
    assert.equal(await page.locator('.mote').first().evaluate(el => getComputedStyle(el).animationName), 'none');
    await page.screenshot({ path: `/tmp/loading-${viewport.width}x${viewport.height}.png` });
    await page.evaluate(() => window.report(100, 100));
    assert.equal(await page.locator('#amount').textContent(), '100%');
    assert.match(await page.locator('#phase').textContent(), /다운로드 완료/);
    assert.equal(await page.locator('#loading').count(), 1, '100% download must not dismiss the initializing engine');
    await page.evaluate(() => window.report(0, 0));
    assert.equal(await page.locator('#amount').textContent(), '');
    await page.evaluate(() => window.finish());
    await page.locator('#loading').waitFor({ state: 'detached' });
    await page.reload();
    await page.evaluate(() => window.fail(new Error('<script>unsafe</script>')));
    await page.locator('#retry').waitFor();
    assert.equal(await page.locator('#error-detail').textContent(), '<script>unsafe</script>');
    assert.equal(await page.locator('#error-detail script').count(), 0);
    assert.equal(await page.locator('#progress').isVisible(), false);
    const retry = await page.locator('#retry').boundingBox();
    assert(retry.height >= 56 && retry.x >= 0 && retry.x + retry.width <= viewport.width);
    await page.locator('#retry').click();
    await page.locator('#progress').waitFor({ state: 'visible' });
    assert.equal(await page.locator('#failure').isVisible(), false);
    await page.close();
    checks += 1;
  }
  for (const scenario of ['missing', 'script-failed', 'constructor-failed']) {
    const page = await browser.newPage({ viewport: { width: 412, height: 839 } });
    await page.route('https://loader.test/**', async route => {
      const name = new URL(route.request().url()).pathname;
      if (name === '/install.js') return route.fulfill({ contentType: 'text/javascript', body: installer });
      if (name === '/loading-bg.webp') return route.fulfill({ contentType: 'image/webp', body: art });
      if (name === '/engine.js') {
        if (scenario === 'script-failed') return route.abort('failed');
        return route.fulfill({ contentType: 'text/javascript', body: scenario === 'missing'
          ? 'window.Engine = class { static getMissingFeatures() { return ["WebAssembly"]; } };'
          : 'window.Engine = class { constructor() { throw new Error("unavailable"); } };' });
      }
      return route.fulfill({ contentType: 'text/html', body: html });
    });
    await page.goto('https://loader.test/');
    await page.locator('#retry').waitFor();
    assert.equal(await page.locator('#progress').isVisible(), false);
    if (scenario === 'missing') assert.match(await page.locator('#error-message').textContent(), /이 브라우저/);
    await page.close();
    checks += 1;
  }
  console.log(`loading shell: ${checks} browser scenarios passed`);
} finally { await browser.close(); }
