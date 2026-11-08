#!/usr/bin/env node
// Real trusted fullscreen with controlled Screen Orientation API success/denial.
// Desktop CI cannot prove physical Android sensor rotation.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {chromium} = createRequire(import.meta.url)('playwright');
const source = await readFile(new URL('./fullscreen.js', import.meta.url), 'utf8');
const server = createServer((request, response) => {
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  response.end('<!doctype html><html><body><canvas id="canvas" style="width:100%;height:200px"></canvas>' +
    '<button id="landscape">가로</button><button id="portrait">세로</button><button id="auto">자동</button>' +
    '<script>' + source + '</script><script>for(const choice of ["auto","landscape","portrait"]) ' +
    'document.getElementById(choice).onclick=()=>window.SjrpgOrientation.choose(choice);</script></body></html>');
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({headless:true,args:['--no-sandbox','--disable-gpu']});
const base = 'http://127.0.0.1:' + server.address().port;
const errors = [];
async function fixture(kind='supported') {
  const page = await browser.newPage();
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(kind => {
    window.orientationCalls = [];
    window.orientationReject = false;
    const api = {
      lock(choice) {
        window.orientationCalls.push({choice,fullscreen:Boolean(document.fullscreenElement)});
        if (window.orientationReject) return Promise.reject(new DOMException('denied','NotAllowedError'));
        return Promise.resolve();
      },
      unlock() {window.orientationCalls.push({choice:'auto'});}
    };
    if(kind==='unsupported') { api.lock=undefined; api.unlock=undefined; }
    Object.defineProperty(window.screen,'orientation',{configurable:true,value:api});
    if(kind==='installed') {
      const match = window.matchMedia.bind(window);
      window.matchMedia = query => query==='(display-mode: standalone)' ?
        {matches:true,addEventListener(){},removeEventListener(){}} : match(query);
    }
  },kind);
  await page.goto(base);
  return page;
}
try {
  const page = await fixture();
  await page.evaluate(()=>window.SjrpgOrientation.restore('landscape'));
  assert.equal(await page.evaluate(()=>document.fullscreenElement),null,'startup never requests fullscreen');
  assert.equal(await page.evaluate(()=>window.orientationCalls.length),0,'saved browser lock waits for an eligible gesture');
  await page.click('#landscape');
  await page.waitForFunction(()=>!window.SjrpgOrientation.state().pending);
  assert.deepEqual(await page.evaluate(()=>window.orientationCalls),[{choice:'landscape',fullscreen:true}],
    'trusted click enters real document fullscreen before invoking lock');
  assert.equal(await page.evaluate(()=>window.SjrpgOrientation.state().locked),true);
  assert.equal(await page.evaluate(()=>window.SjrpgFullscreen.state().active),true);
  assert.deepEqual(await page.evaluate(()=>['html','body','#canvas'].map(s=>getComputedStyle(document.querySelector(s)).transform)),
    ['none','none','none'],'rotation never transforms CSS or input coordinates');
  await page.click('#portrait');
  await page.waitForFunction(()=>!window.SjrpgOrientation.state().pending);
  assert.equal(await page.evaluate(()=>window.orientationCalls.at(-1).choice),'portrait');
  await page.click('#auto');
  assert.equal(await page.evaluate(()=>window.orientationCalls.at(-1).choice),'auto');
  assert.equal(await page.evaluate(()=>window.SjrpgOrientation.state().locked),false);
  assert.equal(await page.evaluate(()=>Boolean(document.fullscreenElement)),true,'automatic rotation preserves chosen fullscreen');
  await page.evaluate(()=>window.orientationReject=true);
  await page.click('#landscape');
  await page.waitForFunction(()=>!window.SjrpgOrientation.state().pending);
  assert.equal(await page.evaluate(()=>window.SjrpgOrientation.state().locked),false,'denial never claims a lock');
  assert.match(await page.evaluate(()=>window.SjrpgOrientation.state().detail),/고정하지 못했습니다/);
  await page.evaluate(()=>window.orientationReject=false);
  await page.click('#landscape');
  await page.waitForFunction(()=>!window.SjrpgOrientation.state().pending);
  assert.equal(await page.evaluate(()=>window.SjrpgOrientation.state().locked),true,'same choice can be retried after denial');
  await page.evaluate(()=>document.exitFullscreen());
  await page.waitForFunction(()=>!window.SjrpgOrientation.state().locked);
  assert.match(await page.evaluate(()=>window.SjrpgOrientation.state().detail),/종료/);
  await page.close();

  const deniedFullscreen = await fixture();
  await deniedFullscreen.evaluate(()=> {
    document.documentElement.requestFullscreen=()=>Promise.reject(new DOMException('blocked','NotAllowedError'));
  });
  await deniedFullscreen.click('#portrait');
  await deniedFullscreen.waitForFunction(()=>!window.SjrpgOrientation.state().pending);
  assert.equal(await deniedFullscreen.evaluate(()=>window.orientationCalls.length),0,'fullscreen denial prevents a misleading orientation lock call');
  assert.match(await deniedFullscreen.evaluate(()=>window.SjrpgOrientation.state().detail),/고정하지 못했습니다/);
  await deniedFullscreen.close();

  const unsupported = await fixture('unsupported');
  await unsupported.click('#portrait');
  assert.equal(await unsupported.evaluate(()=>document.fullscreenElement),null,'unsupported orientation does not request fullscreen');
  assert.equal(await unsupported.evaluate(()=>window.SjrpgOrientation.state().supported),false);
  assert.match(await unsupported.evaluate(()=>window.SjrpgOrientation.state().detail),/지원하지 않습니다/);
  await unsupported.close();

  const installed = await fixture('installed');
  await installed.click('#portrait');
  await installed.waitForFunction(()=>!window.SjrpgOrientation.state().pending && !window.SjrpgFullscreen.state().pending);
  assert.deepEqual(await installed.evaluate(()=>window.orientationCalls),[{choice:'portrait',fullscreen:true}],
    'installed first-gesture fullscreen and orientation share the same transition');
  await installed.close();

  const actual = await browser.newPage();
  actual.on('pageerror', error=>errors.push(error.message));
  await actual.goto(base);
  await actual.click('#portrait');
  await actual.waitForFunction(()=>!window.SjrpgOrientation.state().pending);
  const result = await actual.evaluate(()=>window.SjrpgOrientation.state());
  assert.equal(typeof result.detail,'string');
  assert.equal(result.pending,false,'actual browser API completes or reports its platform limitation');
  assert.equal(await actual.evaluate(()=>getComputedStyle(document.querySelector('#canvas')).transform),'none');
  await actual.close();
  assert.deepEqual(errors,[]);
  console.log('ORIENTATION_BROWSER_PASS trusted real fullscreen ordering, installed gesture sharing, unlock, startup, denial, retry, unsupported state and CSS/input preservation; physical sensor rotation requires device verification');
} finally {
  await browser.close();
  await new Promise(resolve=>server.close(resolve));
}
