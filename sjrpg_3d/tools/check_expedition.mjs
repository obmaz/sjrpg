#!/usr/bin/env node
// 실제 모바일 입력으로 계약 → 월드 재생성 → 시작 기술 → 룬 → 임무 선택을 검수한다.
import {createRequire} from 'node:module';
import {mkdir, writeFile} from 'node:fs/promises';
const require = createRequire(import.meta.url);
const {chromium} = require('playwright');
const args = Object.fromEntries(process.argv.slice(2).map(value => value.replace(/^--/, '').split('=')));
const url = args.url || 'http://localhost:8882/index.html';
const out = args.out || 'build/expedition/browser';
await mkdir(out, {recursive: true});
const browser = await chromium.launch({headless: true, args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const results = [];
try {
  for (const [name, viewport, cls] of [['portrait',{width:540,height:960},'mage'],['landscape',{width:960,height:540},'warrior']]) {
    const context = await browser.newContext({viewport, deviceScaleFactor:1, isMobile:true, hasTouch:true});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {if (/SCRIPT ERROR|^ERROR:/.test(message.text())) errors.push(message.text());});
    const target = new URL(url);
    target.searchParams.set('panel','expedition');
    target.searchParams.set('expedition_review','1');
    await page.goto(target.toString());
    await page.waitForFunction(() => window.__sjrpgTitleReady && window.__sjrpgEntryReady, null, {timeout:120000});
    await page.locator('#entry-start').click();
    await page.waitForFunction(() => window.__sjrpgClassSelectReady && window.__sjrpgClassButtons, null, {timeout:30000});
    async function entry(key) {
      const point = await page.evaluate(key => window.__sjrpgClassButtons[key], key);
      await page.touchscreen.tap(point[0]*viewport.width, point[1]*viewport.height);
    }
    await entry(cls);
    await page.waitForTimeout(400);
    await entry('start');
    await page.waitForFunction(() => window.__sjrpgExpedition?.buttons.some(button => button.id === 'contract_lore') && !window.__sjrpgExpedition.loading, null, {timeout:120000});
    async function press(id) {
      for (let attempt=0; attempt<35; attempt++) {
        const button = await page.evaluate(id => window.__sjrpgExpedition?.buttons.find(button => button.id === id), id);
        if (button?.visible && !button.disabled) {
          await page.touchscreen.tap(button.point[0]*viewport.width,button.point[1]*viewport.height);
          await page.waitForTimeout(350);
          return;
        }
        await page.mouse.move(viewport.width*0.65,viewport.height*0.65);
        await page.mouse.wheel(0, 350);
        await page.waitForTimeout(250);
      }
      throw new Error(`Cannot reach actual scroll-list control: ${id}`);
    }
    await page.screenshot({path:`${out}/${name}-contracts.png`, timeout:120000});
    await press('contract_lore');
    await page.waitForFunction(() => window.__sjrpgExpedition?.phase === 'starter' && window.__sjrpgExpedition.buttons.filter(button => button.id.startsWith('draft_')).length === 3 && !window.__sjrpgExpedition.loading, null, {timeout:120000});
    const starter = await page.evaluate(() => window.__sjrpgExpedition);
    if (!starter.paused || starter.level !== 1) throw new Error('New world did not open a paused level-one draft');
    await page.screenshot({path:`${out}/${name}-skills.png`, timeout:120000});
    await press(`draft_${starter.offered[0].id}`);
    await page.waitForFunction(() => window.__sjrpgExpedition?.drafts[0] === 'rune' && window.__sjrpgExpedition.offered.length === 3, null, {timeout:30000});
    const rune = await page.evaluate(() => window.__sjrpgExpedition);
    if (rune.offered.some(card => card.kind !== 'rune')) throw new Error('Lore reward must contain support runes');
    await page.screenshot({path:`${out}/${name}-runes.png`, timeout:120000});
    await press(`draft_${rune.offered[0].id}`);
    await page.waitForFunction(() => window.__sjrpgExpedition?.drafts.length === 0 && window.__sjrpgExpedition.buttons.some(button => button.id === 'mission_moon'), null, {timeout:30000});
    await press('mission_moon');
    await page.waitForFunction(() => window.__sjrpgExpedition?.phase === 'mission', null, {timeout:30000});
    const final = await page.evaluate(() => window.__sjrpgExpedition);
    if (!final.ranks[starter.offered[0].id] || Object.values(final.runes).flat().length !== 1) throw new Error('Touch choices did not persist in the actual build');
    await page.screenshot({path:`${out}/${name}-mission.png`, timeout:120000});
    await page.keyboard.press('Escape');
    await page.waitForTimeout(400);
    await page.keyboard.press('KeyT');
    await page.waitForFunction(() => window.__sjrpgExpedition?.panel.endsWith('/run_build_panel.gd'), null, {timeout:30000});
    const skillButton = await page.evaluate(() => window.__sjrpgExpedition.buttons.find(button => button.text !== '×' && button.visible && !button.disabled));
    await press(skillButton.id);
    await page.screenshot({path:`${out}/${name}-build.png`, timeout:120000});
    if (errors.length) throw new Error(errors.join('\n'));
    results.push({name,cls,starter:starter.offered,rune:rune.offered,final,errors});
    await context.close();
  }
  await writeFile(`${out}/report.json`, JSON.stringify(results,null,2));
  console.log('PASS expedition: portrait + landscape real contract, world reload, three choices, support rune and mission input');
} finally {
  await browser.close();
}
