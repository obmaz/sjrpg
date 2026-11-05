#!/usr/bin/env node
// 웹 빌드를 실제 브라우저(Playwright/Chromium)로 열어 장면을 캡처합니다.
//   node tools/screenshot.mjs --scene town --device phone --out shot.png
//   node tools/screenshot.mjs --scene bag --class mage --device desktop
// 필요: `npm i -D playwright` 또는 전역 playwright, 그리고 tools/serve.sh 로 띄운 build/web.
// 장면은 게임의 디버그 쿼리(README의 "디버그 쿼리")로 열립니다.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium, devices } = require('playwright');

const SCENES = {
    title: '',
    select: '',
    town: '',
    hud: 'hud_preview=full',
    hud_low: 'hud_preview=low',
    hud_nearfull: 'hud_preview=nearfull',
    hud_large: 'hud_preview=large',
    plaza: 'at=portal',
    warp: 'at=portal&panel=warp',
    warp_trip: 'warp_preview=1',
    juice: 'at=field&combat_preview=1',
    pc_controls: 'at=field',
    dodge: 'at=field',
    corpses: 'corpse_preview=1',
    corpses_bridge: 'corpse_preview=bridge&zoom=1.2',
    corpses_terrace: 'corpse_preview=terrace&zoom=1.1',
    rewards: 'reward_preview=1',
    cooldowns: '',
    background: '',
    wide: 'zoom=0.45',
    bridge: 'at=bridge&zoom=0.7',
    bank: 'at=bank&zoom=0.45',
    field: 'at=field',
    gate0: 'at=gate0&zoom=1.5',
    gate1: 'at=gate1&zoom=1.5',
    gate2: 'at=gate2&zoom=1.5',
    gate3: 'at=gate3&zoom=1.5',
    chapel: 'at=chapel&zoom=0.8',
    occlusion: 'at=occlusion&zoom=1.3',
    chapelwide: 'at=chapel&zoom=0.4',
    lm0: 'at=lm0&zoom=0.5',
    hill: 'at=lm2&zoom=0.85',
    garden: 'at=lm1&zoom=0.85',
    wallcorner: 'at=corner0&zoom=0.8',
    wallcorner1: 'at=corner1&zoom=0.8',
    wallcorner2: 'at=corner2&zoom=0.8',
    wallcorner3: 'at=corner3&zoom=0.8',
    lm1: 'at=lm1&zoom=0.5',
    lm2: 'at=lm2&zoom=0.5',
    waterfall: 'at=lm3&zoom=0.6',
    map: 'panel=map',
    travel: 'panel=travel',
    dungeon: 'panel=dungeon',
    dungeon_map: 'panel=dungeon_map',
    cave_entry: 'dungeon_preview=entry',
    cave_room: 'dungeon_preview=room',
    cave_branch: 'dungeon_preview=branch',
    cave_exit: 'dungeon_preview=exit',
    elin: 'at=elin&zoom=0.8',
    rowen: 'at=rowen&zoom=0.8',
    bag: 'panel=bag&chests=1&gold=300',
    shop: 'panel=shop&gold=300',
    skills: 'panel=skills',
    settings: 'panel=settings',
    smith: 'panel=smith&chests=1',
    boss: 'at=boss&panel=boss',
    journal: 'panel=journal',
    mira: 'panel=mira',
    mira_approach: 'at=mira',
    victory: 'panel=victory',
};

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, all) => (a.startsWith('--') ? [...acc, [a.slice(2), all[i + 1]]] : acc), []));
const scene = args.scene ?? 'town';
if (!(scene in SCENES)) {
    console.error(`알 수 없는 장면 '${scene}'. 선택: ${Object.keys(SCENES).join(', ')}`);
    process.exit(2);
}
const device = args.device ?? 'desktop';
const cls = args.class ?? (scene === 'cooldowns' ? 'mage' : 'warrior');
const base = args.url ?? 'http://localhost:8765/index.html';
const out = args.out ?? `shot-${scene}-${device}.png`;

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const ctx = await browser.newContext(device === 'phone' ? { ...devices['Pixel 7'] } : device === 'phone-landscape' ? { ...devices['Pixel 7 landscape'] } : { viewport: { width: 1280, height: 720 }, deviceScaleFactor: Number(args.dpr ?? 1) });
const page = await ctx.newPage();
const logs = [];
page.on('console', (m) => logs.push(`${m.type()}: ${m.text()}`));
page.on('pageerror', (e) => logs.push(`pageerror: ${e.message}`));
const quality = (args.quality ? `&quality=${args.quality}` : '') + (args.zoom ? `&zoom=${args.zoom}` : '');
await page.goto(`${base}?${SCENES[scene]}${quality}`);
await page.waitForFunction(() => window.__sjrpgTitleReady === true, null, {timeout: 90000});
await page.waitForTimeout(500);
const vp = page.viewportSize();
const tap = async (x, y) => {
    if (device.startsWith('phone')) {
        const cdp = await ctx.newCDPSession(page);
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y, id: 1 }] });
        await page.waitForTimeout(80);
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    } else {
        await page.mouse.click(x, y);
    }
};
if (scene === 'title') {
    await page.screenshot({path: out});
    await browser.close();
    const errors = logs.filter((line) => /error/i.test(line));
    console.log(`저장: ${out}; 콘솔 오류 ${errors.length}건`);
    process.exit(errors.length ? 1 : 0);
}
await tap(vp.width / 2, vp.height / 2); // 타이틀
await page.waitForTimeout(4000);
// Use real responsive controls for both classes, independent of viewport or orientation.
await page.waitForFunction(() => window.__sjrpgClassSelectReady === true && window.__sjrpgClassButtons, null, {timeout: 30000});
const tapEntry = async (key) => {
    const point = await page.evaluate((name) => window.__sjrpgClassButtons[name], key);
    const viewport = page.viewportSize();
    await tap(viewport.width * point[0], viewport.height * point[1]);
};
await tapEntry(cls);
await page.waitForTimeout(300);
if (scene === 'select') {
    await page.screenshot({path: out});
    if (args.rotate === '1') {
        await page.setViewportSize({width: vp.height, height: vp.width});
        await page.waitForTimeout(700);
        await page.screenshot({path: out.replace(/\.png$/, '-rotated.png')});
    }
    const errors = logs.filter((line) => /error/i.test(line));
    console.log(`저장: ${out}; 콘솔 오류 ${errors.length}건`);
    await browser.close();
    process.exit(errors.length ? 1 : 0);
}
if (args.start) await tap(...args.start.split(',').map(Number));
else await tapEntry('start');
await page.waitForFunction(() => window.__sjrpgAdventureReady === true, null, { timeout: 30000 });
if (scene === 'background') await page.evaluate(() => document.querySelector('canvas').blur());
if (scene.startsWith('hud')) {
    await page.waitForFunction(() => window.__sjrpgHudPreviewReady === true, null, {timeout: 30000});
    await page.waitForTimeout(300);
} else if (scene.startsWith('cave_')) {
    await page.waitForFunction(() => window.__sjrpgDungeonPreviewReady === true, null, {timeout: 30000});
    await page.waitForTimeout(300);
} else if (scene === 'rewards') {
    await page.waitForFunction(() => window.__sjrpgRewardPreviewReady === true, null, {timeout: 30000});
} else if (scene === 'warp_trip') {
    await page.waitForFunction(() => Array.isArray(window.__sjrpgWarpPreviewButton), null, {timeout: 30000});
} else if (scene.startsWith('corpses')) {
    await page.waitForFunction(() => window.__sjrpgCorpsePreviewReady === true, null, {timeout: 30000});
    await page.waitForTimeout(1500);
} else await page.waitForTimeout(9000);
if (scene === 'dodge') {
    await page.keyboard.down('Shift');
    await page.waitForTimeout(70);
    await page.keyboard.up('Shift');
}
if (scene === 'cooldowns') {
    // Exercise a real held cast; no fabricated cooldown or frozen gameplay state.
    await page.keyboard.down('Space');
    await page.waitForTimeout(250);
}
await page.screenshot({ path: out });
if (scene === 'dodge') {
    await page.waitForTimeout(500);
    await page.screenshot({path: out.replace(/\.png$/, '-settled.png')});
}
if (scene.startsWith('corpses') && args.lifecycle === '1') {
    await page.waitForFunction(() => window.__sjrpgCorpsePreviewExpired === true, null, {timeout: 120000});
    await page.waitForTimeout(200);
    await page.screenshot({path: out.replace(/\.png$/, '-expired.png')});
    console.log('시체 수명 종료: 게임 시간 30초 후 실제 제거 확인');
}
if (scene === 'cooldowns') {
    await page.keyboard.up('Space');
    await page.waitForTimeout(150);
    await page.screenshot({path: out.replace(/\.png$/, '-remaining.png')});
    await page.waitForTimeout(2200);
    await page.screenshot({path: out.replace(/\.png$/, '-ready.png')});
}
if (scene === 'warp_trip') {
    const target = await page.evaluate(() => window.__sjrpgWarpPreviewButton);
    await tap(vp.width * target[0], vp.height * target[1]);
    await page.waitForFunction(() => window.__sjrpgWarpPreviewArrived === true, null, {timeout: 15000});
    await page.waitForTimeout(1200);
    await page.screenshot({path: out.replace(/\.png$/, '-arrived.png')});
    console.log('워프게이트 버튼으로 실제 이동·안전 도착 확인');
}
if (scene === 'plaza') {
    for (let frame = 1; frame <= 2; frame++) {
        await page.waitForTimeout(320);
        await page.screenshot({path: out.replace(/\.png$/, `-${frame}.png`)});
    }
}
if (scene === 'juice') {
    for (let frame=1; frame<=6; frame++) {
        await page.waitForTimeout(110);
        await page.screenshot({path: out.replace(/\.png$/, `-${frame}.png`)});
    }
}
if (scene === 'pc_controls') {
    // Real desktop events: inspect these captures alongside the input-state regression case.
    if (device.startsWith('phone')) throw new Error('pc_controls requires --device desktop');
    await page.mouse.move(vp.width * 0.56, vp.height * 0.42);
    await page.mouse.down({button: 'left'});
    await page.waitForTimeout(180);
    await page.screenshot({path: out.replace(/\.png$/, '-attack.png')});
    await page.mouse.up({button: 'left'});
    await page.mouse.click(vp.width * 0.61, vp.height * 0.49, {button: 'right'});
    await page.waitForTimeout(650);
    await page.screenshot({path: out.replace(/\.png$/, '-move.png')});
    for (const key of ['w', 'a', 's', 'd']) {
        await page.keyboard.down(key);
        await page.waitForTimeout(140);
        await page.keyboard.up(key);
    }
    for (const key of ['1', '2', '3', '4']) {
        await page.keyboard.press(key);
        await page.waitForTimeout(180);
    }
    await page.screenshot({path: out.replace(/\.png$/, '-keys.png')});
    await page.keyboard.press('b');
    await page.mouse.click(vp.width * 0.5, vp.height * 0.4, {button: 'right'});
    await page.screenshot({path: out.replace(/\.png$/, '-panel.png')});
    console.log('PC actual-event captures: left attack, right move, WASD, 1–4, modal right-click');
}
const errors = logs.filter((l) => /error/i.test(l));
console.log(`저장: ${out}${errors.length ? `\n콘솔 오류 ${errors.length}건:\n${errors.slice(0, 5).join('\n')}` : ''}`);
await browser.close();
process.exit(errors.length ? 1 : 0);
