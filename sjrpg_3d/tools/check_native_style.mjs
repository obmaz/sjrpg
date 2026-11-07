#!/usr/bin/env node
// Actual exported NativeAdventure, real pointer/keyboard input, fresh profiles only.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const baseline=process.env.SJRPG_STYLE_BASELINE==='1';
const base=new URL(process.argv[2]||'http://127.0.0.1:8781/');
const out=path.resolve(process.argv[3]||'build/native-style-review');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const errors=[],captures=[],checks=[];let page,context,failure=null;
const css=(s,r)=>({x:r[0]*s.window[0]/s.ui.viewport[0],y:r[1]*s.window[1]/s.ui.viewport[1],w:r[2]*s.window[0]/s.ui.viewport[0],h:r[3]*s.window[1]/s.ui.viewport[1]});
const inside=(a,b,e=1)=>b.x>=a.x-e&&b.y>=a.y-e&&b.x+b.w<=a.x+a.w+e&&b.y+b.h<=a.y+a.h+e;
const overlap=(a,b)=>Math.min(a.x+a.w,b.x+b.w)-Math.max(a.x,b.x)>1&&Math.min(a.y+a.h,b.y+b.h)-Math.max(a.y,b.y)>1;
const read=()=>page.evaluate(()=>({ui:window.__sjrpgNativeStyleReview,native:window.__sjrpg3dProbe,tone:window.__sjrpgUiTone,window:[innerWidth,innerHeight],dpr:devicePixelRatio}));
async function wait(fn,label,timeout=90000){const end=Date.now()+timeout;while(Date.now()<end){assert.equal(errors.length,0,JSON.stringify(errors));const s=await read();if(fn(s))return s;await page.waitForTimeout(150);}throw Error('Timeout '+label+' '+JSON.stringify(await read()));}
async function tapRect(r){await page.mouse.click(r.x+r.w/2,r.y+r.h/2);await page.waitForTimeout(450);}
async function tapHud(key){const s=await read();assert(s.ui.buttons[key],key+' missing');await tapRect(css(s,s.ui.buttons[key]));}
async function capture(name,inline=false){const s=await read();await page.screenshot({path:path.join(out,name+'.png'),timeout:90000});captures.push({name,...s});if(inline){const data=(await page.screenshot({type:'jpeg',quality:78,timeout:90000})).toString('base64');console.log('SJ_NATIVE_STYLE_IMAGE_BEGIN '+name+' image/jpeg '+data.length);for(let i=0;i<data.length;i+=16384)console.log('SJ_NATIVE_STYLE_IMAGE_CHUNK '+name+' '+data.slice(i,i+16384));console.log('SJ_NATIVE_STYLE_IMAGE_END '+name);}}
function hudGeometry(s,label){
 assert(s.ui.native&&s.native?.native_active&&s.native?.simulation==='3d',label+' actual native world');
 if(!baseline){assert.deepEqual(s.ui.coverage.actor_cards,[],label+' no resident/enemy camera-facing object cards');const env=s.ui.coverage.environment;assert(env&&env.remaining_sources,label+' explicit retained source inventory');}
 const bounds={x:0,y:0,w:s.window[0],h:s.window[1]};
 const keys=['potion_hp','potion_mp','bar_bag','bar_skills','bar_quests','bar_gear'];
 for(const key of keys){const r=css(s,s.ui.buttons[key]);assert(inside(bounds,r),label+' bounds '+key);if(!baseline)assert(r.w>=43.5&&r.h>=43.5,label+' 44 CSS target '+key+' '+JSON.stringify(r));}
 if(!baseline)for(let i=0;i<keys.length;i++)for(let j=i+1;j<keys.length;j++)assert(!overlap(css(s,s.ui.buttons[keys[i]]),css(s,s.ui.buttons[keys[j]])),label+' separate hitboxes '+keys[i]+'/'+keys[j]);
 assert(inside(bounds,css(s,s.ui.avatar)),label+' avatar frame');
 assert(inside(bounds,css(s,s.ui.level_badge)),label+' avatar level badge');
 assert(inside(bounds,css(s,s.ui.hp))&&inside(bounds,css(s,s.ui.mp)),label+' status gauge bounds');
 assert(!s.ui.paused,label+' live HUD');
 checks.push(label);
}
async function closePanel(){const s=await read();const button=s.ui.panel.buttons.find(b=>b.text==='×'||b.text==='모험 계속하기');assert(button,'real close action missing');await tapRect(css(s,button.rect));await wait(s=>!s.ui.paused&&!s.ui.panel.rect,'panel closed');}

function panelGeometry(s,label){
 const p=s.ui.panel,bounds={x:0,y:0,w:s.window[0],h:s.window[1]};
 assert(s.ui.paused&&p.rect,label+' actual paused panel');
 assert(inside(bounds,css(s,p.rect))&&inside(css(s,p.rect),css(s,p.title)),label+' frame/title bounds');
 if(p.subtitle_visible&&p.subtitle_text)assert(css(s,p.title).y+css(s,p.title).h<=css(s,p.subtitle).y+1,label+' title/subtitle spacing');
 assert(inside(css(s,p.rect),css(s,p.body)),label+' body bounds');
}
async function menuPanel(key,label){
 await tapHud(key);let s=await wait(s=>s.ui?.paused&&s.ui?.panel?.rect,'real menu '+key);panelGeometry(s,label);
 await capture(label);
 checks.push(label+' real menu click');
 if(key==='bar_gear'){
  const seen=[];
  for(const amount of[.5,1,1.5]){
   let found;
   for(let attempt=0;attempt<20;attempt++){
    s=await read();found=s.ui.panel.buttons.find(b=>Math.abs(b.world_zoom-amount)<.001);assert(found,'actual zoom '+amount);
    const r=css(s,found.rect),clip=css(s,s.ui.panel.body_clip);
    if(inside(clip,r)){if(!baseline)assert(r.w>=43.5&&r.h>=43.5,'zoom 44 CSS target '+amount);await tapRect(r);break;}
    await page.mouse.move(clip.x+clip.w*.5,clip.y+clip.h*.5);await page.mouse.wheel(0,r.y<clip.y?-280:280);await page.waitForTimeout(250);
    if(attempt===19)throw Error('Actual settings scroll cannot expose zoom '+amount);
   }
   s=await wait(s=>Math.abs(s.ui.world_zoom-amount)<.001,'actual zoom changed');
   seen.push(s.ui.zoom);await capture(label+'-zoom-'+amount);
  }
  assert(new Set(seen.map(x=>x.toFixed(4))).size===3,'three actual camera zoom values');checks.push(label+' real zoom settings');
 }
 await closePanel();
}

async function skillTree(label){

 await tapHud('bar_skills');let s=await wait(s=>s.ui?.panel?.nodes?.length>0&&s.ui.paused,'real skill tree');
 const p=s.ui.panel,bounds={x:0,y:0,w:s.window[0],h:s.window[1]};assert(inside(bounds,css(s,p.rect)),label+' panel bounds');
 assert(css(s,p.title).y+css(s,p.title).h<=css(s,p.subtitle).y+1,label+' subtitle spacing');
 const clip=css(s,p.tree_clip);assert(clip.w>40&&clip.h>40,label+' tree scroll viewport');
 const nodes=p.nodes.filter(n=>inside(clip,css(s,n.rect)));
 assert(nodes.length>0,label+' visible skill nodes');for(const node of nodes){const hit=css(s,node.hit_rect);if(!baseline)assert(hit.w>=43.5&&hit.h>=43.5,label+' 44 CSS skill target '+node.id);}
 const n=nodes.find(n=>n.rank>0)||nodes[0];await tapRect(css(s,n.rect));
 s=await wait(s=>s.ui.panel.selected===n.id,'actual node selection');
 await capture(label+'-skills',true);
 await page.mouse.move(clip.x+clip.w*.5,clip.y+clip.h*.5);await page.mouse.wheel(0,520);await page.waitForTimeout(500);
 const moved=await read();assert(moved.ui.panel.nodes.some((n,i)=>Math.abs(n.rect[1]-p.nodes[i].rect[1])>1),label+' actual tree scroll');
 await capture(label+'-skills-scrolled');
 checks.push(label+' real skill selection and scroll');
 await closePanel();
}
async function boot(cls,params={},dpr=1){
 if(context)await context.close();
 context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:dpr});page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))errors.push(m.text());});
 const cdp=await context.newCDPSession(page);await cdp.send('Log.enable');cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error')errors.push(entry.text);});
 const url=new URL(base);url.searchParams.set('native_style_review','1');url.searchParams.set('quality','low');
 for(const[k,v]of Object.entries(params))url.searchParams.set(k,v);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassButtons?.stage==='class',null,{timeout:30000});
 for(const key of[cls,'start']){const data=await page.evaluate(key=>({p:window.__sjrpgClassButtons[key],w:innerWidth,h:innerHeight}),key);await page.mouse.click(data.p[0]*data.w,data.p[1]*data.h);await page.waitForTimeout(300);}
 await wait(s=>s.ui?.native&&s.native?.native_active&&s.native?.physics_ticks>0,'actual native adventure');
}
try{
 for(const cls of['warrior','mage']){
  await boot(cls,{at:'npc_courtyard'});
  for(const [rotation,[w,h]]of[[390,844],[320,640],[568,320],[390,844]].entries()){
   await page.setViewportSize({width:w,height:h});await wait(s=>s.window[0]===w&&s.window[1]===h&&((s.ui.viewport[0]>s.ui.viewport[1])===(w>h)),'rotation');await page.waitForTimeout(600);
   const label=cls+'-'+w+'x'+h+(rotation===3?'-returned':'');hudGeometry(await read(),label);await capture(label+'-hud',rotation!==3&&(w===390||w===568));
   if(rotation!==3)await skillTree(label);
   if(rotation===0)for(const key of['bar_bag','bar_quests','bar_gear'])await menuPanel(key,label+'-'+key);
  }
  const before=(await read()).ui.player;let distance=0;
  for(const key of ['d','a','w','s']){await page.keyboard.down(key);await page.waitForTimeout(350);await page.keyboard.up(key);await page.waitForTimeout(100);const p=(await read()).ui.player;distance=Math.hypot(p[0]-before[0],p[1]-before[1]);if(distance>1)break;}
  await capture(cls+'-walking-native');
  assert(distance>1,'real WASD movement');checks.push(cls+' actual movement');
 }
 for(const [name,params]of[['bridge',{at:'bridge'}],['landmark0',{at:'lm0'}],['landmark1',{at:'lm1'}],['landmark2',{at:'lm2'}],['landmark3',{at:'lm3'}],['cave',{dungeon_preview:'entry'}],['enemy',{at:'field',encounter_preview:'active'}]]){
  await boot('mage',params);await page.waitForTimeout(800);hudGeometry(await read(),name);await capture(name+'-native',true);
 }
 await boot('mage',{at:'npc_courtyard'},2);hudGeometry(await read(),'mage DPR2 portrait');await capture('mage-dpr2-portrait',true);
 if(!baseline){
  await boot('mage',{at:'npc_courtyard'});
  await page.setViewportSize({width:1280,height:1280});await page.waitForTimeout(700);
  assert((await read()).ui.gallery_available,'actual native model gallery resource');
  for(let face=0;face<4;face++){
   await page.evaluate(face=>window.__sjrpgNativeStyleAction('gallery',face),face);
   const g=await wait(s=>s.ui.gallery&&s.ui.gallery.face===face,'actual all-face model gallery');
   await page.waitForTimeout(400);await capture('native-gallery-face-'+face,true);checks.push('actual native model face '+face);
  }
  await page.evaluate(()=>window.__sjrpgNativeStyleAction('gallery',-1));
 }
 assert.equal(errors.length,0);console.log((baseline?'NATIVE_STYLE_BASELINE_CAPTURED ':'NATIVE_STYLE_PASS ')+JSON.stringify({checks:checks.length,captures:captures.length,errors:0}));
}catch(e){failure=String(e);console.error('NATIVE_STYLE_FAIL '+failure);try{await capture('failure',true);}catch{}process.exitCode=1;}
finally{await writeFile(path.join(out,'proof.json'),JSON.stringify({baseline,checks,captures,errors,failure,passed:!failure&&!errors.length},null,2));await browser.close();}
