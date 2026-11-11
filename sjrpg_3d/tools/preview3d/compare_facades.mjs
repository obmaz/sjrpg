// 실제 Godot 렌더를 나란히 배치한다. 비교 이미지의 색·기하·조명은 보정하지 않는다.
import {createRequire} from 'node:module';
import {writeFile} from 'node:fs/promises';
import {fileURLToPath, pathToFileURL} from 'node:url';
import path from 'node:path';

const require = createRequire(import.meta.url);
const {chromium} = require('playwright');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../build/review/facades');
const assets = {shop: '상점', smith: '대장간', stable: '마구간', home: '주택', chapel: '예배당'};
const html = `<!doctype html><html lang="ko"><meta charset="utf-8">
<title>건물 벽면 적용 전후</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#151c1a;color:#eee;font:20px sans-serif}
header{height:70px;display:flex;align-items:center;justify-content:space-around;gap:16px}
select{font:inherit;background:#24332b;color:#eee;border:1px solid #748673;padding:4px}
main{display:grid;grid-template-columns:1fr 1fr}figure{margin:0;position:relative}
img{display:block;width:100%;height:auto}figcaption{position:absolute;top:12px;left:14px;background:#15201bdd;padding:8px 14px;border-radius:4px}
</style><header>
<label>건물 <select id="asset">${Object.entries(assets).map(([id,label])=>`<option value="${id}">${label}</option>`).join('')}</select></label>
<span>동일 카메라 · 동일 조명 · 벽 원화 변경</span>
<label>방향 <select id="angle">${[0,90,180,270].map(angle=>`<option value="${angle}">${angle}°</option>`).join('')}</select></label>
</header><main><figure><img id="before"><figcaption>적용 전</figcaption></figure>
<figure><img id="after"><figcaption>적용 후</figcaption></figure></main>
<script>
function update(){for(const phase of ['before','after'])document.getElementById(phase).src=phase+'/'+document.getElementById('asset').value+'-'+document.getElementById('angle').value+'.png'}
document.getElementById('asset').onchange=update;document.getElementById('angle').onchange=update;update();
</script></html>`;
await writeFile(path.join(root,'comparison.html'),html);
const browser = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
try {
    const page = await browser.newPage({viewport:{width:1280,height:710},deviceScaleFactor:1});
    await page.goto(pathToFileURL(path.join(root,'comparison.html')).href);
    for(const id of Object.keys(assets)) {
        await page.selectOption('#asset',id);
        await page.waitForFunction(()=>[...document.images].every(image=>image.complete&&image.naturalWidth===640),null,{timeout:15000});
        await page.screenshot({path:path.join(root,id+'-comparison.png')});
    }
    console.log('FACADE_COMPARISON_PASS assets=5');
} finally {
    await browser.close();
}
