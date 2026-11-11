#!/usr/bin/env node
// 실제 터치로 행 위 드래그→장소 선택→가로 회전을 검사한다. 휠 입력으로 대체하지 않는다.
import {createRequire} from 'node:module';
import {mkdir, writeFile} from 'node:fs/promises';
const {chromium} = createRequire(import.meta.url)('playwright');
const args = Object.fromEntries(process.argv.slice(2).reduce((all, arg, i, source) => arg.startsWith('--') ? [...all, [arg.slice(2), source[i + 1]]] : all, []));
const cave = args.scope === 'cave';
if (args.scope && !['forest', 'cave'].includes(args.scope)) throw Error('--scope must be forest or cave');
const out = args.out ?? 'build/review/map-touch';
await mkdir(out, {recursive: true});
const browser = await chromium.launch({args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']});
const context = await browser.newContext({viewport: {width: 540, height: 960}, deviceScaleFactor: 1, hasTouch: true});
const page = await context.newPage();
const errors = [], proof = {steps: [], errors};
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => {if (message.type() === 'error' || /SCRIPT ERROR|^ERROR:/.test(message.text())) errors.push(message.text());});
const wait = ms => page.waitForTimeout(ms);
const snapshot = () => page.evaluate(() => window.__sjrpgMapPanel);
const point = (state, x, y) => ({x: x * page.viewportSize().width / state.view[0], y: y * page.viewportSize().height / state.view[1]});
const check = (ok, label) => {if (!ok) throw Error(label); console.log('PASS', label);};
const input = await context.newCDPSession(page);
const touch = async (from, to = from) => {
    await input.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{...from, id: 1}]});
    if (from.x !== to.x || from.y !== to.y) {
        for (let step = 1; step <= 15; step++) {
            await input.send('Input.dispatchTouchEvent', {type: 'touchMove', touchPoints: [{x: from.x + (to.x - from.x) * step / 15, y: from.y + (to.y - from.y) * step / 15, id: 1}]});
            await wait(30);
        }
    } else await wait(80);
    await input.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
    await wait(500);
};
const swipe = (state, direction, amount = .6) => {
    const [x, y, width, height] = state.list;
    return touch(point(state, x + width * .5, y + height * (.5 - direction * amount / 2)), point(state, x + width * .5, y + height * (.5 + direction * amount / 2)));
};
try {
    const url = new URL(args.url ?? 'http://localhost:8878/index.html');
    url.searchParams.set('panel', cave ? 'dungeon_map' : 'map'); url.searchParams.set('probe', '1'); url.searchParams.set('quality', 'low');
    await page.goto(String(url));
    await page.locator('#entry-start').click({timeout: 90000});
    await page.waitForFunction(() => window.__sjrpgClassButtons?.stage === 'class', null, {timeout: 90000});
    for (const key of ['mage', 'start']) {
        const at = await page.evaluate(name => window.__sjrpgClassButtons[name], key);
        await page.mouse.click(at[0] * 540, at[1] * 960); await wait(300);
    }
    await page.waitForFunction(() => window.__sjrpgAdventureReady && window.__sjrpgMapPanel?.places?.length, null, {timeout: 180000});
    let state = await snapshot(); proof.steps.push(state);
    // 손가락이 원래 좌표로 돌아와도 한 번 시작한 스크롤은 선택이 되면 안 된다.
    const [lx, ly, lw, lh] = state.list;
    const start = point(state, lx + lw * .5, ly + lh * .65);
    await input.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{...start, id: 1}]});
    for (const direction of [-1, 1]) {
        for (let step = 1; step <= 10; step++) {
            const offset = direction < 0 ? -step * 4 : -40 + step * 4;
            await input.send('Input.dispatchTouchEvent', {type: 'touchMove', touchPoints: [{x: start.x, y: start.y + offset, id: 1}]});
            await wait(30);
        }
    }
    await input.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
    await wait(500);
    state = await snapshot(); proof.steps.push(state);
    check(state.selected === '', 'reversing a real finger scroll never selects a row');
    const initial = state.places[0].row[1];
    await swipe(state, -1);
    state = await snapshot();
    check(state.places[0].row[1] < initial - 50, 'real finger drag scrolls across list rows');
    check(state.selected === '', 'swiping never activates a place');
    if (cave) {
        check(state.places.filter(place => place.category === '장비 보물').length === 3
            && state.places.filter(place => place.category === '보급 보물').length === 2, 'all live cave treasure types share the place list');
    } else check(state.places.filter(place => place.category === '웨이포인트').length === 3, 'all waypoint locations share the place list');
    const colors = new Map(state.places.map(place => [place.category, place.color]));
    check(new Set(colors.values()).size === colors.size, 'types have distinct visible colors and labels');
    const target = cave ? state.places.find(place => place.category === '장비 보물').id : 'sanctuary:cave';
    for (let step = 0; step < 14; step++) {
        state = await snapshot(); const row = state.places.find(place => place.id === target).row;
        if (row[1] >= state.list[1] && row[1] + row[3] <= state.list[1] + state.list[3]) break;
        await swipe(state, row[1] < state.list[1] ? 1 : -1, .25);
    }
    state = await snapshot(); const row = state.places.find(place => place.id === target).row;
    await touch(point(state, row[0] + row[2] / 2, row[1] + row[3] / 2));
    await page.waitForFunction(id => window.__sjrpgMapPanel?.selected === id, target, {timeout: 10000});
    state = await snapshot(); proof.steps.push(state);
    const place = state.places.find(place => place.id === target);
    check(Math.hypot(place.world[0] - state.center[0], place.world[1] - state.center[1]) < .01, 'place tap focuses its actual coordinate');
    await page.screenshot({path: out + '/portrait.png', timeout: 90000});
    await page.setViewportSize({width: 960, height: 540}); await wait(1200);
    state = await snapshot(); proof.steps.push(state);
    const selected = state.places.find(place => place.id === target).row;
    check(state.map[0] + state.map[2] < state.list[0] && selected[1] >= state.list[1] - 1 && selected[1] + selected[3] <= state.list[1] + state.list[3] + 1, 'landscape keeps the selected list row visible beside the map');
    await swipe(state, -1, .3);
    state = await snapshot();
    check(state.selected === target, 'landscape drag preserves the selected place');
    await page.screenshot({path: out + '/landscape.png', timeout: 90000});
    check(errors.length === 0, 'browser has no script or rendering errors');
    console.log('MAP_TOUCH_BROWSER_PASS');
} finally {
    await writeFile(out + '/proof.json', JSON.stringify(proof, null, 2) + '\n');
    await context.close(); await browser.close();
}
