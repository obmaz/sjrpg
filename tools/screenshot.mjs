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
    hud_danger: 'hud_preview=danger',
    stone: 'encounter_preview=ready',
    stone_cast: 'encounter_preview=ready',
    stone_active: 'encounter_preview=active',
    stone_empty: 'encounter_preview=empty',
    plaza: 'at=portal',
    warp: 'at=portal&panel=warp',
    warp_trip: 'warp_preview=1',
    juice: 'at=field&combat_preview=1',
    fx_slash: 'at=field&fx_preview=cleave',
    fx_spin: 'at=field&fx_preview=whirlwind',
    fx_slam: 'at=field&fx_preview=leapAttack',
    fx_bolt: 'at=field&fx_preview=iceBolt&zoom=0.8',
    fx_frost: 'at=field&fx_preview=frostNova',
    fx_meteor: 'at=field&fx_preview=meteor',
    gate_closed0: 'gate_preview=0',
    gate_closed1: 'gate_preview=1',
    gate_closed2: 'gate_preview=2',
    gate_closed3: 'gate_preview=3',
    npc_nw: 'at=npc_nw',
    npc_ne: 'at=npc_ne',
    npc_sw: 'at=npc_sw',
    npc_se: 'at=npc_se',
    npc_courtyard: 'at=npc_courtyard&zoom=0.65',
    pc_controls: 'at=field',
    dodge: 'at=field',
    corpses: 'corpse_preview=1',
    corpses_bridge: 'corpse_preview=bridge&zoom=1.2',
    corpses_terrace: 'corpse_preview=terrace&zoom=1.1',
    rewards: 'reward_preview=1',
    levelup: 'reward_preview=levelup',
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
    chapel_reference: 'at=chapel_reference&zoom=1',
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
const settle = Number(args.settle ?? 9000);
if (!Number.isFinite(settle) || settle < 500 || settle > 30000) throw new Error('--settle must be 500–30000 ms');

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const profile = device === 'phone' ? { ...devices['Pixel 7'] } : device === 'phone-landscape' ? { ...devices['Pixel 7 landscape'] } : { viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 };
if (args.viewport) {
    const match = /^(\d+)x(\d+)$/.exec(args.viewport);
    if (!match || match.slice(1).some(value => Number(value) < 300 || Number(value) > 4000)) throw new Error('Viewport must be WIDTHxHEIGHT, 300–4000 pixels per side');
    profile.viewport = {width: Number(match[1]), height: Number(match[2])};
}
if (args.dpr) profile.deviceScaleFactor = Number(args.dpr);
const ctx = await browser.newContext(profile);
const page = await ctx.newPage();
const logs = [];
page.on('console', (m) => logs.push(`${m.type()}: ${m.text()}`));
page.on('pageerror', (e) => logs.push(`pageerror: ${e.message}`));
const diagnosticLog = await ctx.newCDPSession(page);
await diagnosticLog.send('Log.enable');
diagnosticLog.on('Log.entryAdded', ({entry}) => {
    // Browser GPU errors need not be console API events; capture their first cause too.
    if (entry.level === 'error' || /INVALID_(OPERATION|VALUE|ENUM|FRAMEBUFFER_OPERATION)/.test(entry.text)) {
        logs.push(`error: ${entry.source}: ${entry.text}`);
    }
});
const launchURL = new URL(base);
for (const [key, value] of new URLSearchParams(SCENES[scene])) launchURL.searchParams.set(key, value);
for (const key of ['quality', 'zoom', 'lighting', 'at']) {
    if (args[key]) launchURL.searchParams.set(key, args[key]);
}
let releaseDownload;
let loadingHeader;
let packArrived;
const packHeld = new Promise(resolve => { packArrived = resolve; });
if (scene === 'title' && args['entry-flow'] === '1') {
    await page.route('**/index.pck', route => {
        releaseDownload = () => route.continue();
        packArrived();
    });
}
await page.goto(launchURL.toString());
if (scene === 'title' && args['entry-flow'] === '1') {
    let timeout;
    try {
        await Promise.race([packHeld, new Promise((_, reject) => { timeout = setTimeout(() => reject(new Error('Pack download did not start')), 60000); })]);
        await page.waitForTimeout(300);
        loadingHeader = await page.locator('h1').boundingBox();
        await page.screenshot({path: out.replace(/\.png$/, '-loading.png')});
    } finally { clearTimeout(timeout); }
    await releaseDownload();
}
await page.waitForFunction(() => window.__sjrpgTitleReady === true, null, {timeout: 90000});
await page.waitForFunction(() => !window.__sjrpgEntry || window.__sjrpgEntryReady === true, null, {timeout: 30000});
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
    if (args['entry-flow'] === '1') {
        if (JSON.stringify(await page.locator('h1').boundingBox()) !== JSON.stringify(loadingHeader)) throw new Error('Loading/title header moved');
        await page.locator('#entry-start').click();
        await page.waitForFunction(() => window.__sjrpgClassSelectReady === true, null, {timeout: 30000});
        const back = await page.evaluate(() => window.__sjrpgClassButtons.back);
        await tap(vp.width * back[0], vp.height * back[1]);
        await page.waitForFunction(() => window.__sjrpgTitleReady && window.__sjrpgEntryReady, null, {timeout: 30000});
        await page.screenshot({path: out.replace(/\.png$/, '-returned.png')});
        await page.locator('#entry-start').click();
        await page.waitForFunction(() => window.__sjrpgClassSelectReady === true, null, {timeout: 30000});
        console.log('Entry flow: real loading → stable title → selection → back → start passed');
    }
    await browser.close();
    const errors = logs.filter((line) => /error/i.test(line));
    console.log(`저장: ${out}; 콘솔 오류 ${errors.length}건`);
    process.exit(errors.length ? 1 : 0);
}
if (await page.locator('#entry-start').isVisible()) {
    await page.locator('#entry-start').click();
} else {
    await tap(vp.width / 2, vp.height / 2); // native-title fallback
}
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
if (scene.startsWith('gate_closed')) {
    await page.waitForFunction(() => window.__sjrpgGateReview?.closed === true, null, {timeout: 60000});
    console.log('Actual threat closed the gate:', await page.evaluate(() => window.__sjrpgGateReview));
} else if (scene.startsWith('fx_')) {
    await page.waitForFunction(() => window.__sjrpgFxReview?.actual_cast === true, null, {timeout: 60000}).catch(async error => {
        await page.screenshot({path: out.replace(/\.png$/, '-failed.png')});
        const status = await page.evaluate(() => window.__sjrpgFxReviewStatus ?? null);
        throw new Error(`FX inspection failed: ${JSON.stringify(status)}; ${logs.filter(line => /error/i.test(line)).join('\n')}; ${error.message}`);
    });
    console.log('Actual cast, paused for visual inspection:', await page.evaluate(() => window.__sjrpgFxReview));
} else if (scene.startsWith('stone')) {
    await page.waitForFunction(() => window.__sjrpgEncounterPreviewReady === true, null, {timeout: 30000});
    if (scene === 'stone_cast') {
        await page.keyboard.down('Space');
        await page.waitForTimeout(260);
        await page.keyboard.up('Space');
        await page.waitForFunction(() => window.__sjrpgEncounterAudit.charges === 2 && window.__sjrpgEncounterAudit.living > 0, null, {timeout: 15000});
        console.log('Encounter actual attack consumed one charge and summoned', await page.evaluate(() => window.__sjrpgEncounterAudit.living));
    }
} else if (scene.startsWith('hud')) {
    await page.waitForFunction(() => window.__sjrpgHudPreviewReady === true, null, {timeout: 30000});
    await page.waitForTimeout(300);
} else if (scene.startsWith('cave_')) {
    await page.waitForFunction(() => window.__sjrpgDungeonPreviewReady === true, null, {timeout: 30000});
    await page.waitForTimeout(300);
} else if (scene === 'rewards' || scene === 'levelup') {
    await page.waitForFunction(() => window.__sjrpgRewardPreviewReady === true, null, {timeout: 30000});
} else if (scene === 'warp_trip') {
    await page.waitForFunction(() => Array.isArray(window.__sjrpgWarpPreviewButton), null, {timeout: 30000});
} else if (scene.startsWith('corpses')) {
    await page.waitForFunction(() => window.__sjrpgCorpsePreviewReady === true, null, {timeout: 30000});
    await page.waitForTimeout(1500);
} else await page.waitForTimeout(settle);
if (args.taps) {
    for (const item of args.taps.split(',')) {
        const point = /^(\d+):(\d+)$/.exec(item);
        if (!point || Number(point[1]) >= vp.width || Number(point[2]) >= vp.height) throw new Error('--taps expects in-viewport x:y,x:y');
        await tap(Number(point[1]), Number(point[2]));
        await page.waitForTimeout(450);
    }
}
if (args.walk) {
    // Optional real keyboard route for inspecting service buildings without teleporting the scene.
    for (const step of args.walk.split(',')) {
        const match = /^([wasd](?:\+[wasd])*):(\d+)$/.exec(step);
        if (!match || Number(match[2]) > 10000) throw new Error('--walk expects a:1200,w+d:500 (up to 10000 ms per step)');
        const keys = match[1].split('+');
        for (const key of keys) await page.keyboard.down(key);
        await page.waitForTimeout(Number(match[2]));
        for (const key of keys) await page.keyboard.up(key);
    }
    await page.waitForTimeout(500);
}
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
if (scene === 'hud_danger') {
    await page.waitForTimeout(450);
    await page.screenshot({path: out.replace(/\.png$/, '-pulse.png')});
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
