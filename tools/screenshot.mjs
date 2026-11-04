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
    town: '',
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
    lm1: 'at=lm1&zoom=0.5',
    lm2: 'at=lm2&zoom=0.5',
    waterfall: 'at=lm3&zoom=0.6',
    map: 'panel=map',
    travel: 'panel=travel',
    dungeon: 'panel=dungeon',
    dungeon_map: 'panel=dungeon_map',
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
const cls = args.class ?? 'warrior';
const base = args.url ?? 'http://localhost:8765/index.html';
const out = args.out ?? `shot-${scene}-${device}.png`;

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const ctx = await browser.newContext(device === 'phone' ? { ...devices['Pixel 7'] } : device === 'phone-landscape' ? { ...devices['Pixel 7 landscape'] } : { viewport: { width: 1280, height: 720 } });
const page = await ctx.newPage();
const logs = [];
page.on('console', (m) => logs.push(`${m.type()}: ${m.text()}`));
page.on('pageerror', (e) => logs.push(`pageerror: ${e.message}`));
const quality = args.quality ? `&quality=${args.quality}` : "";
await page.goto(`${base}?${SCENES[scene]}${quality}`);
await page.waitForTimeout(12000);
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
await tap(vp.width / 2, vp.height / 2); // 타이틀
await page.waitForTimeout(4000);
// 직업 선택: 카드 안의 "시작" 버튼 위치 (가로/세로 레이아웃별)
const start = args.start ? args.start.split(',').map(Number) : device === 'phone' ? (cls === 'mage' ? [205, 627] : [205, 382]) : device === 'phone-landscape' ? [vp.width * (cls === 'mage' ? 0.624 : 0.381), vp.height * 0.70] : cls === 'mage' ? [844, 499] : [436, 521];
await tap(...start);
await page.waitForFunction(() => window.__sjrpgAdventureReady === true, null, { timeout: 30000 });
if (scene === 'background') await page.evaluate(() => document.querySelector('canvas').blur());
await page.waitForTimeout(9000);
await page.screenshot({ path: out });
const errors = logs.filter((l) => /error/i.test(l));
console.log(`저장: ${out}${errors.length ? `\n콘솔 오류 ${errors.length}건:\n${errors.slice(0, 5).join('\n')}` : ''}`);
await browser.close();
process.exit(errors.length ? 1 : 0);
