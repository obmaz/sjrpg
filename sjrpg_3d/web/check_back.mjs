#!/usr/bin/env node
// Exercise real same-document history and trusted fullscreen; Android OS notifications
// are covered by the actual Adventure3D headless case, not simulated by this fixture.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {chromium} = createRequire(import.meta.url)('playwright');
const source = await readFile(new URL('./fullscreen.js', import.meta.url), 'utf8');
const server = createServer((request, response) => {
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  if (request.url.startsWith('/portal')) {
    response.end('<!doctype html><title>Version selection</title><a href="/game?edition=3d#forest">Enter</a>');
    return;
  }
  response.end('<!doctype html><title>Back fixture</title><canvas id="canvas"></canvas>' +
    '<button id="fullscreen">Fullscreen</button><script>' + source + '</script>' +
    '<script>document.getElementById("fullscreen").onclick=()=>window.SjrpgFullscreen.toggle();</script>');
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({headless:true,args:['--no-sandbox','--disable-gpu']});
const base = 'http://127.0.0.1:' + server.address().port;
const gameURL = base + '/game?edition=3d#forest';
const errors = [], dialogs = [];
async function fixture() {
  const page = await browser.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('dialog', async dialog => {dialogs.push(dialog.type() + ': ' + dialog.message()); await dialog.dismiss();});
  await page.goto(base + '/portal');
  await page.goto(gameURL);
  await page.evaluate(() => {
    window.backEvents = [];
    window.hero = {class:'mage',level:7,hp:45,gold:317,quest:'forest'};
    window.SjrpgBack.attach(() => window.backEvents.push(location.href));
  });
  return page;
}
async function back(page, count) {
  await page.goBack();
  await page.waitForFunction(n => window.backEvents.length === n, count);
  assert.equal(page.url(),gameURL,'active Back stays on the same query and hash without reloading');
  assert.deepEqual(await page.evaluate(()=>window.hero),{class:'mage',level:7,hp:45,gold:317,quest:'forest'});
}
try {
  const inactive = await fixture();
  const initialLength = await inactive.evaluate(()=>history.length);
  await inactive.evaluate(()=>window.SjrpgBack.setActive(false));
  assert.equal(await inactive.evaluate(()=>history.length),initialLength,'inactive title/selection adds no history guard');
  await inactive.goBack();
  assert.equal(inactive.url(),base + '/portal','inactive Back retains ordinary document navigation');
  await inactive.close();

  const page = await fixture();
  const originalLength = await page.evaluate(()=>history.length);
  await page.evaluate(() => {
    history.replaceState({route:'forest',payload:{slot:2}},'',location.href);
    window.SjrpgBack.setActive(true);
  });
  const guardedLength = originalLength + 1;
  assert.equal(await page.evaluate(()=>history.length),guardedLength,'one live adventure adds one guard');
  assert.deepEqual(await page.evaluate(()=>({route:history.state.route,payload:history.state.payload})),
    {route:'forest',payload:{slot:2}},'arming preserves existing application history state');
  await page.evaluate(()=> {
    for(let repeat=0;repeat<6;repeat++) {
      window.SjrpgBack.setActive(true);
      window.SjrpgBack.setActive(false);
      window.SjrpgBack.setActive(true);
    }
  });
  assert.equal(await page.evaluate(()=>history.length),guardedLength,'repeated activation and scene cycles do not stack guards');
  for(let press=1;press<=8;press++) {
    await back(page,press);
    assert.equal(await page.evaluate(()=>history.length),guardedLength,'re-arming replaces the forward guard instead of growing history');
  }
  await page.evaluate(()=>window.SjrpgBack.setActive(false));
  await page.goBack(); // Consume the existing same-document guard with interception disabled.
  assert.equal(await page.evaluate(()=>window.backEvents.length),8,'inactive history traversal never calls the adventure callback');
  assert.equal(page.url(),gameURL);
  await page.evaluate(()=>window.SjrpgBack.setActive(true));
  await back(page,9);
  await page.evaluate(()=>{
    window.SjrpgBack.attach(()=>{window.backEvents.push('replacement');});
  });
  await page.goBack();
  await page.waitForFunction(()=>window.backEvents.length===10);
  assert.equal(await page.evaluate(()=>window.backEvents.at(-1)),'replacement','attach replaces rather than accumulating callbacks');
  await page.evaluate(()=>window.SjrpgBack.detach());
  await page.goBack();
  assert.equal(await page.evaluate(()=>window.backEvents.length),10,'detach deactivates the retained callback');
  await page.goBack();
  assert.equal(page.url(),base + '/portal','detached bridge leaves the document through ordinary history');
  await page.close();

  const fullscreen = await fixture();
  await fullscreen.evaluate(()=>window.SjrpgBack.setActive(true));
  const fullscreenHistory = await fullscreen.evaluate(()=>history.length);
  await fullscreen.click('#fullscreen');
  await fullscreen.waitForFunction(()=>Boolean(document.fullscreenElement));
  await fullscreen.evaluate(()=>document.exitFullscreen());
  await fullscreen.waitForFunction(()=>window.backEvents.length===1);
  assert.equal(fullscreen.url(),gameURL,'Back-style DOM fullscreen exit keeps the adventure URL');
  assert.equal(await fullscreen.evaluate(()=>history.length),fullscreenHistory,'fullscreen exit does not add another guard');
  await back(fullscreen,2);
  await fullscreen.evaluate(()=>window.SjrpgBack.setActive(false));
  await fullscreen.click('#fullscreen');
  await fullscreen.waitForFunction(()=>Boolean(document.fullscreenElement));
  await fullscreen.evaluate(()=>document.exitFullscreen());
  await fullscreen.waitForFunction(()=>!document.fullscreenElement);
  assert.equal(await fullscreen.evaluate(()=>window.backEvents.length),2,'inactive fullscreen exit never opens adventure settings');
  await fullscreen.close();

  assert.deepEqual(errors,[],'bridge produces no uncaught browser errors');
  assert.deepEqual(dialogs,[],'Back does not use an exit confirmation or beforeunload prompt');
  console.log('BACK_BROWSER_PASS real history, repeated Back, stable URL/progress, one guard, inactive navigation, callback replacement/detach and trusted fullscreen exit');
} finally {
  await browser.close();
  await new Promise(resolve=>server.close(resolve));
}
