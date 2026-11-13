#!/usr/bin/env node
import {inspectionUrl} from '../inspection_url.mjs';
// One browser/GPU owner at a time. Use TMPDIR on a filesystem with free space.
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
const {chromium} = createRequire(import.meta.url)('playwright');
const base = process.argv[2] ?? 'http://127.0.0.1:8071/';
const out = path.resolve(process.argv[3] ?? '/tmp/native-loot-review');
const clearStoneOnly = process.argv[4] === 'clear-stone';
await mkdir(out,{recursive:true});
const browser = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const evidence=[];
const allErrors=[];
try {
  for (const quality of ['high','low']) {
    const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
    const page=await context.newPage();
    const errors=[];
    page.on('console',message=>{if(message.type()==='error'||/ERROR:|SCRIPT ERROR|INVALID_(OPERATION|VALUE|ENUM)/.test(message.text()))errors.push(message.text());});
    page.on('pageerror',error=>errors.push(error.message));
    const cdp=await context.newCDPSession(page);
    await cdp.send('Log.enable');
    cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error'||/INVALID_(OPERATION|VALUE|ENUM)/.test(entry.text))errors.push(entry.text);});
    const url=inspectionUrl(base);url.searchParams.set('loot_review','1');url.searchParams.set('quality',quality);
    await page.goto(url.href);
    await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,{},{timeout:90000});
    await page.locator('#entry-start').click();
    await page.waitForFunction(()=>window.__sjrpgClassSelectReady&&window.__sjrpgClassButtons,{},{timeout:30000});
    async function tap(key){const p=await page.evaluate(k=>window.__sjrpgClassButtons[k],key);const v=page.viewportSize();await page.mouse.click(p[0]*v.width,p[1]*v.height);}
    await tap('mage');await page.waitForTimeout(250);await tap('start');
    await page.waitForFunction(()=>window.__sjrpg3dReady&&window.__sjrpgLootReviewReady,{},{timeout:60000});
    async function action(command,rotation=0,baseline=false){await page.evaluate(args=>window.__sjrpgLootAction(...args),[command,rotation,baseline]);await page.waitForTimeout(650);}
    async function shot(name){
      const info=await page.evaluate(()=>({review:window.__sjrpgLootReview,world:window.__sjrpg3dProbe}));
      if(!info.world?.native_active||!Number.isFinite(info.world.azimuth)||!Number.isFinite(info.world.elevation)||Math.abs(info.world.azimuth-45)>0.01||Math.abs(info.world.elevation-35.2643897)>0.01||info.world.quality!==quality)throw new Error('Actual native camera/probe is not ready');
      await page.screenshot({path:path.join(out,`${quality}-${name}.png`),timeout:90000});
      evidence.push({quality,name,viewport:page.viewportSize(),...info});
    }
    if(clearStoneOnly){
      if(quality==='low'){
        await action('chest');await shot('clear-chest-closed');
        await action('open');await page.waitForTimeout(700);await shot('clear-chest-real-open');
        await page.setViewportSize({width:844,height:390});await page.waitForTimeout(900);
        await shot('clear-chest-open-landscape');
        await action('cave');await shot('clear-cave-no-forest-props');
        const cave=await page.evaluate(()=>window.__sjrpgLootReview);
        if(cave.realm!=='cave'||cave.visible_models!==0||cave.save_error)throw new Error('Low-quality lifetime/save failed');
        allErrors.push(...errors.map(error=>({quality,error})));
        await context.close();continue;
      }
      await action('site','south');
      await shot('clear-stone-native-portrait');
      await action('stone',180);
      await page.setViewportSize({width:844,height:390});await page.waitForTimeout(900);
      await shot('clear-stone-back-landscape');
      await page.setViewportSize({width:390,height:844});await page.waitForTimeout(700);
      await action('stone');
      await action('ready');await action('hit');await shot('clear-stone-real-hit');
      await action('empty');await shot('clear-stone-source-cooldown');
      const status=await page.evaluate(()=>window.__sjrpgLootReview);
      if(status.status!=='충전까지 2초'||status.save_error)throw new Error('Source cooldown or isolated review session failed');
      await action('chest');await shot('clear-chest-closed');
      await action('open');await page.waitForTimeout(700);await shot('clear-chest-real-open');
      await action('cave');await shot('clear-cave-no-forest-props');
      const cave=await page.evaluate(()=>window.__sjrpgLootReview);
      if(cave.realm!=='cave'||cave.visible_models!==0||cave.save_error)throw new Error('Review source lifetime/save failed');
      await action('chest');await shot('clear-return-consumed-chest');
      allErrors.push(...errors.map(error=>({quality,error})));
      await context.close();continue;
    }
    for(const role of ['stone','chest']){
      await action(role,0,true);await shot(`${role}-before-portrait`);
      await action(role);await shot(`${role}-native-portrait`);
      await action(role,180);await shot(`${role}-back-portrait`);
      await action(role);
      const before=await page.evaluate(()=>window.__sjrpg3dProbe.physics_ticks);
      await page.setViewportSize({width:844,height:390});
      await page.waitForFunction(t=>window.__sjrpg3dProbe.native_width>window.__sjrpg3dProbe.native_height&&window.__sjrpg3dProbe.physics_ticks>t,before,{timeout:15000});
      await page.waitForTimeout(650);await shot(`${role}-native-landscape`);
      await action(role,180);await shot(`${role}-back-landscape`);
      await page.setViewportSize({width:390,height:844});await page.waitForTimeout(650);
    }
    await action('stone');await action('ready');await action('hit');await shot('stone-real-hit');
    await action('empty');await shot('stone-source-cooldown');
    await action('chest');await action('open');await page.waitForTimeout(700);await shot('chest-real-open');
    await action('chest',180);await shot('chest-open-back');
    await action('cave');await shot('cave-no-forest-props');
    const cave=await page.evaluate(()=>window.__sjrpgLootReview);
    if(cave.realm!=='cave'||cave.visible_models!==0)throw new Error('Forest native props leaked into cave');
    await action('chest');await shot('return-consumed-chest');
    allErrors.push(...errors.map(error=>({quality,error})));
    await context.close();
  }
} finally {
  await writeFile(path.join(out,'evidence.json'),JSON.stringify({evidence,errors:allErrors},null,2));
  await browser.close();
}
if(allErrors.length)throw new Error(`Browser/GPU errors: ${JSON.stringify(allErrors.slice(0,5))}`);
console.log(`Captured ${evidence.length} actual native/source comparisons with 0 browser/GPU errors: ${out}`);
