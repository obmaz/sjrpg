#!/usr/bin/env node
// Compare browser frame cadence on a fixed route. Software rendering is a comparison tool, not a phone benchmark.
// node tools/benchmark.mjs --quality low --device desktop --renderer software
import { createRequire } from 'node:module';
const { chromium, devices } = createRequire(import.meta.url)('playwright');
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) => value.startsWith('--') ? [...pairs, [value.slice(2), all[index + 1]]] : pairs, []));
const quality = args.quality ?? 'high';
const device = args.device ?? 'desktop';
const hero = args.class ?? (args.preview3d === '1' ? 'mage' : 'warrior');
const renderer = args.renderer ?? 'software';
const warmup = Number(args.warmup ?? 6000);
const preview3d = args.preview3d === '1';
if (!Number.isFinite(warmup) || warmup < 0 || warmup > 30000) throw new Error('warmup must be 0–30000 ms');
if (!['low', 'high'].includes(quality) || !['phone', 'phone-landscape', 'desktop'].includes(device) || !['warrior', 'mage'].includes(hero) || !['software', 'default'].includes(renderer)) {
    throw new Error('quality=low|high, device=phone|phone-landscape|desktop, class=warrior|mage, renderer=software|default');
}
const browser = await chromium.launch({ args: renderer === 'software' ? ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : [] });
try {
    const context = await browser.newContext(device === 'phone' ? { ...devices['Pixel 7'] } : device === 'phone-landscape' ? { ...devices['Pixel 7 landscape'] } : { viewport: { width: 1280, height: 720 } });
    const page = await context.newPage();
    const errors = [];
    page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
    page.on('pageerror', (error) => errors.push(error.message));
    const tap = async (x, y) => device.startsWith('phone') ? page.touchscreen.tap(x, y) : page.mouse.click(x, y);
    const location = args.at ?? (preview3d ? 'chapel_reference' : 'field');
    const query = new URLSearchParams({ inspection: "1", at: location, quality, benchmark: "1" });
    if (args.combat === '1') query.set('combat_preview', '1');
    if (args.lighting) query.set('lighting', args.lighting);
    if (args.atmosphere) query.set('atmosphere', args.atmosphere);
    if (preview3d) query.set('preview3d', '1');
    await page.goto(`${args.url ?? 'http://localhost:8765/index.html'}?${query}`);
    await page.waitForFunction(() => window.__sjrpgTitleReady === true, null, {timeout: 90000});
    await page.waitForFunction(() => !window.__sjrpgEntry || window.__sjrpgEntryReady === true, null, {timeout: 30000});
    const size = page.viewportSize();
    if (await page.locator('#entry-start').isVisible()) await page.locator('#entry-start').click();
    else await tap(size.width / 2, size.height / 2);
    await page.waitForTimeout(4000);
    await page.waitForFunction(() => window.__sjrpgClassSelectReady === true && window.__sjrpgClassButtons);
    for (const key of [hero, 'start']) {
        const point = await page.evaluate((name) => window.__sjrpgClassButtons[name], key);
        await tap(size.width * point[0], size.height * point[1]);
        await page.waitForTimeout(200);
    }
    await page.waitForFunction(() => window.__sjrpgAdventureReady === true, null, { timeout: 30000 });
    await page.waitForFunction(({expected, native}) => {
        const probe = native ? window.__sjrpg3dProbe : window.__sjrpgRenderProbe;
        return probe?.quality === expected && (native ? probe.ready && probe.native_active && probe.spatial_draw_calls > 0 && probe.shadow_primitives > 0 && probe.batch_corner_error_m < 0.0001 && probe.native_width > 2 && probe.native_height > 2 : probe.world_draw_calls > 0 && probe.world_width > 2 && probe.world_height > 2);
    }, {expected: quality, native: preview3d}, { timeout: 60000 }).catch(async (error) => {
        throw new Error(`World rendering was not confirmed: ${JSON.stringify(await page.evaluate((native) => native ? window.__sjrpg3dProbe : window.__sjrpgRenderProbe, preview3d))}; ${error.message}`);
    });
    await page.waitForTimeout(warmup);
    const result = await page.evaluate(() => new Promise((resolve) => {
        const deltas = [];
        let start, previous;
        const frame = (time) => {
            if (start === undefined) { start = time; previous = time; requestAnimationFrame(frame); return; }
            deltas.push(time - previous);
            previous = time;
            if (time - start < 6000) { requestAnimationFrame(frame); return; }
            const sorted = [...deltas].sort((a, b) => a - b);
            resolve({ browser_fps: Math.round(deltas.length * 10000 / (time - start)) / 10, p95_frame_ms: Math.round(sorted[Math.floor(sorted.length * 0.95)]), max_frame_ms: Math.round(sorted.at(-1)), samples: deltas.length });
        };
        requestAnimationFrame(frame);
    }));
    const browserSurface = await page.evaluate(() => {
        const canvas = document.querySelector('canvas');
        return { dpr: window.devicePixelRatio, inner_width: innerWidth, inner_height: innerHeight, css_width: canvas.clientWidth, css_height: canvas.clientHeight, canvas_width: canvas.width, canvas_height: canvas.height };
    });
    console.log(JSON.stringify({ device, quality, hero, renderer, preview3d, lighting: args.lighting ?? 'on', combat: args.combat === '1', warmup_ms: warmup, at: location, ...result, world: await page.evaluate((native) => native ? window.__sjrpg3dProbe : window.__sjrpgRenderProbe, preview3d), surface: browserSurface, errors }, null, 2));
    if (errors.length) process.exitCode = 1;
    await context.close();
} finally {
    await browser.close();
}
