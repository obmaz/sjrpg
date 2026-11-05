#!/usr/bin/env node
// Compare browser frame cadence on a fixed route. Software rendering is a comparison tool, not a phone benchmark.
// node tools/benchmark.mjs --quality low --device desktop --renderer software
import { createRequire } from 'node:module';
const { chromium, devices } = createRequire(import.meta.url)('playwright');
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) => value.startsWith('--') ? [...pairs, [value.slice(2), all[index + 1]]] : pairs, []));
const quality = args.quality ?? 'high';
const device = args.device ?? 'desktop';
const hero = args.class ?? 'warrior';
const renderer = args.renderer ?? 'software';
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
    const query = new URLSearchParams({ at: args.at ?? "field", quality, benchmark: "1" });
    await page.goto(`${args.url ?? 'http://localhost:8765/index.html'}?${query}`);
    await page.waitForFunction(() => window.__sjrpgTitleReady === true, null, {timeout: 90000});
    const size = page.viewportSize();
    await tap(size.width / 2, size.height / 2);
    await page.waitForTimeout(4000);
    await page.waitForFunction(() => window.__sjrpgClassSelectReady === true && window.__sjrpgClassButtons);
    for (const key of [hero, 'start']) {
        const point = await page.evaluate((name) => window.__sjrpgClassButtons[name], key);
        await tap(size.width * point[0], size.height * point[1]);
        await page.waitForTimeout(200);
    }
    await page.waitForFunction(() => window.__sjrpgAdventureReady === true, null, { timeout: 30000 });
    await page.waitForFunction((expected) => window.__sjrpgRenderProbe?.quality === expected && window.__sjrpgRenderProbe?.world_draw_calls > 0 && window.__sjrpgRenderProbe?.world_width > 2 && window.__sjrpgRenderProbe?.world_height > 2, quality, { timeout: 30000 }).catch(async (error) => {
        throw new Error(`World rendering was not confirmed: ${JSON.stringify(await page.evaluate(() => window.__sjrpgRenderProbe))}; ${error.message}`);
    });
    await page.waitForTimeout(6000);
    const result = await page.evaluate(() => new Promise((resolve) => {
        const deltas = [];
        let start, previous;
        const frame = (time) => {
            if (start === undefined) { start = time; previous = time; requestAnimationFrame(frame); return; }
            deltas.push(time - previous);
            previous = time;
            if (time - start < 6000) { requestAnimationFrame(frame); return; }
            const sorted = [...deltas].sort((a, b) => a - b);
            resolve({ browser_fps: Math.round(deltas.length * 10000 / (time - start)) / 10, p95_frame_ms: Math.round(sorted[Math.floor(sorted.length * 0.95)]), samples: deltas.length });
        };
        requestAnimationFrame(frame);
    }));
    console.log(JSON.stringify({ device, quality, hero, renderer, ...result, world: await page.evaluate(() => window.__sjrpgRenderProbe), errors }, null, 2));
    if (errors.length) process.exitCode = 1;
    await context.close();
} finally {
    await browser.close();
}
