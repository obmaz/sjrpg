// 같은 네 집과 지형을 실제 게임의 세로/가로 화면에서 검수한다.
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=process.argv[2],out=process.argv[3];
await mkdir(out,{recursive:true});
const browser=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
let context,page;
const errors=[],captures=[];
try{
 for(const at of (process.argv[4]?.split(',') ?? ['npc_nw','npc_ne','npc_sw','npc_se','lm0','lm2'])){
  if(context)await context.close();
  context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
  page=await context.newPage();
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))errors.push(m.text());});
  await page.setViewportSize({width:390,height:844});
  const url=new URL(base);for(const [k,v] of Object.entries({at,quality:'high',native_style_review:'1'}))url.searchParams.set(k,v);
  await page.goto(url.href,{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
  await page.locator('#entry-start').click();
  await page.waitForFunction(()=>window.__sjrpgClassButtons?.stage==='class',null,{timeout:30000});
  for(const key of ['mage','start']){
   const p=await page.evaluate(k=>({p:window.__sjrpgClassButtons[k],w:innerWidth,h:innerHeight}),key);
   await page.mouse.click(p.p[0]*p.w,p.p[1]*p.h);await page.waitForTimeout(300);
  }
  await page.waitForFunction(()=>window.__sjrpg3dProbe?.native_active&&window.__sjrpg3dProbe.physics_ticks>3,null,{timeout:90000});
  for(const [orientation,width,height] of [['portrait',390,844],['landscape',844,390]]){
   await page.setViewportSize({width,height});await page.waitForTimeout(900);
   const probe=await page.evaluate(()=>window.__sjrpg3dProbe);
   assert.equal(probe.native_active,true);assert.equal(errors.length,0,JSON.stringify(errors));
   await page.screenshot({path:`${out}/${at}-${orientation}.png`,timeout:90000});
   captures.push({at,orientation,probe});console.log('CAPTURE',at,orientation);
  }
 }
}finally{await writeFile(`${out}/proof.json`,JSON.stringify({base,captures,errors},null,2));await browser.close();}
assert.equal(errors.length,0,JSON.stringify(errors));console.log('SURFACE_REVIEW_PASS',captures.length);
