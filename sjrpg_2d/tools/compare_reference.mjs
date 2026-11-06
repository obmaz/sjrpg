#!/usr/bin/env node
// Present the approved reference and an actual game capture without repainting either image.
// Capture with screenshot.mjs --viewport 714x1280 --dpr 1, then:
//   node tools/compare_reference.mjs --actual /tmp/game.png --out /tmp/comparison.png --label '검수 중'
import {createRequire} from 'node:module';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const require = createRequire(import.meta.url);
const {chromium} = require('playwright');
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) =>
    value.startsWith('--') ? [...pairs, [value.slice(2), all[index + 1]]] : pairs, []));
if (!args.actual || !args.out) throw new Error('--actual and --out are required');
const reference = args.before ? resolve(args.before) : fileURLToPath(new URL('../assets/source/style/approved-game-reference.jpg', import.meta.url));
const dataUrl = async path => `data:image/${path.endsWith('.jpg') ? 'jpeg' : 'png'};base64,${(await readFile(path)).toString('base64')}`;
const escape = text => String(text).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const browser = await chromium.launch();
try {
    const page = await browser.newPage({viewport: {width: 1476, height: 1436}, deviceScaleFactor: 1});
    await page.setContent(`<html lang="ko"><meta charset="UTF-8"><style>
        *{box-sizing:border-box}body{margin:0;background:#141b18;color:#eee;font:24px sans-serif;padding:16px}
        .cols{display:grid;grid-template-columns:714px 714px;gap:16px}h2{margin:0 0 7px;font-size:28px}
        p{font-size:20px;color:#d5c5a0;margin:0 0 14px}img{display:block;width:714px;height:1280px;object-fit:contain;background:#050706}
        .foot{font-size:20px;margin:12px 0;color:#d8ccad}
        </style><div class="cols"><div><h2>${args.before ? '변경 전 실제 화면' : '원본 레퍼런스'}</h2><p>${args.before ? '동일 위치 · 원본 비율 유지' : '사용자가 제시한 최종 분위기 기준'}</p><img src="${await dataUrl(reference)}"></div>
        <div><h2>실제 게임 화면</h2><p>${escape(args.label ?? '실제 실행 화면 · 검수 중')}</p><img src="${await dataUrl(resolve(args.actual))}"></div></div>
        <p class="foot">원본 비율 유지 · 생성 컨셉이 아닌 실제 Godot 웹 실행 화면 · 각도 실측은 별도 검증</p></html>`);
    await page.locator('img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
    await page.screenshot({path: resolve(args.out)});
    console.log(`저장: ${resolve(args.out)}`);
} finally {
    await browser.close();
}
