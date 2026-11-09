#!/usr/bin/env node
// Targeted actual-game before/after sizing review; isolated fresh profiles only.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const baseline=process.env.SJRPG_SCALE_BASELINE==='1';
const base=new URL(process.argv[2]||'http://127.0.0.1:8784/');
const out=path.resolve(process.argv[3]||'build/native-scale-review');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const errors=[],captures=[],checks=[];let context,page,failure=null;
const keys=['potion_hp','potion_mp','bar_bag','bar_skills','bar_quests','bar_gear'];
const targets={goblin:1.69,wolf:1.469,boar:1.586,skeleton:2.21,golem:3.705};
const radii={goblin:32.5,wolf:46.8,boar:49.4,skeleton:32.5,golem:57.2};
const css=(s,r)=>({x:r[0]*s.window[0]/s.ui.viewport[0],y:r[1]*s.window[1]/s.ui.viewport[1],w:r[2]*s.window[0]/s.ui.viewport[0],h:r[3]*s.window[1]/s.ui.viewport[1]});
const inside=(a,b,e=1)=>b.x>=a.x-e&&b.y>=a.y-e&&b.x+b.w<=a.x+a.w+e&&b.y+b.h<=a.y+a.h+e;
const near=(a,b,label,tol=.015)=>assert(Math.abs(a-b)<=tol,label+' actual='+a+' expected='+b);
const read=()=>page.evaluate(()=>({ui:window.__sjrpgNativeStyleReview,scale:window.__sjrpgScaleReview,native:window.__sjrpg3dProbe,pack:window.__sjrpgBuild,window:[innerWidth,innerHeight],dpr:devicePixelRatio}));
async function wait(fn,label,timeout=20000){const end=Date.now()+timeout;while(Date.now()<end){assert.equal(errors.length,0,JSON.stringify(errors));const s=await read();if(fn(s))return s;await page.waitForTimeout(150);}throw Error('Timeout '+label+' '+JSON.stringify(await read()));}
async function settle(){const frame=(await read()).scale.frame;await wait(s=>s.scale.frame>=frame+3,'real frame settlement');}
async function capture(name,inline=true){const s=await read();await page.screenshot({path:path.join(out,name+'.png'),timeout:90000});captures.push({name,...s});console.log('NATIVE_SCALE_MEASURE '+JSON.stringify({name,scale:s.scale,pack:s.pack}));if(inline){const data=(await page.screenshot({type:'jpeg',quality:78,timeout:90000})).toString('base64');console.log('SJ_NATIVE_STYLE_IMAGE_BEGIN '+name+' image/jpeg '+data.length);for(let i=0;i<data.length;i+=16384)console.log('SJ_NATIVE_STYLE_IMAGE_CHUNK '+name+' '+data.slice(i,i+16384));console.log('SJ_NATIVE_STYLE_IMAGE_END '+name);}}
function hud(s,label){assert(s.ui.native&&s.native.native_active&&s.native.simulation==='3d',label+' actual native world');const bounds={x:0,y:0,w:s.window[0],h:s.window[1]};for(const k of keys){const r=css(s,s.ui.buttons[k]);assert(inside(bounds,r),label+' bounds '+k);assert(r.w>=43.5&&r.h>=43.5,label+' 44 CSS '+k);}checks.push(label+' actual HUD');}
function hudRects(s){return {buttons:Object.fromEntries(keys.map(k=>[k,s.ui.buttons[k]])),avatar:s.ui.avatar,hp:s.ui.hp,mp:s.ui.mp,level:s.ui.level_badge,minimap:s.scale.minimap};}
function effective(s){const z=Math.max(.5,Math.min(1.6,Math.min(...s.scale.logical_view)/720));return s.scale.legacy_zoom/(1.6*z*s.scale.debug_zoom);}
async function tap(r,button='left'){const s=await read();assert(inside({x:0,y:0,w:s.window[0],h:s.window[1]},r),'actual click inside game');await page.mouse.click(r.x+r.w/2,r.y+r.h/2,{button});await settle();}
async function closePanel(){const s=await read();const b=s.ui.panel.buttons.find(b=>b.text==='×'||b.text==='모험 계속하기');assert(b,'actual close button');await tap(css(s,b.rect));await wait(s=>!s.ui.paused&&!s.ui.panel.rect,'real panel close');}
async function selectZoom(amount){
 let s=await read();await tap(css(s,s.ui.buttons.bar_gear));await wait(s=>s.ui.paused&&s.ui.panel.rect,'actual settings');
 for(let i=0;i<20;i++){
  s=await read();const b=s.ui.panel.buttons.find(b=>Math.abs(b.world_zoom-amount)<.001);assert(b,'actual zoom option '+amount);
  const r=css(s,b.rect),clip=css(s,s.ui.panel.body_clip);
  if(inside(clip,r)){assert(r.w>=43.5&&r.h>=43.5,'44 CSS actual zoom target');await tap(r);break;}
  await page.mouse.move(clip.x+clip.w*.5,clip.y+clip.h*.5);await page.mouse.wheel(0,r.y<clip.y?-280:280);await settle();
  if(i===19)throw Error('actual settings cannot expose '+amount);
 }
 await wait(s=>Math.abs(s.scale.world_zoom-amount)<.001,'real zoom setting applied');
 await closePanel();await settle();
}
async function boot(scene,matched=false,dpr=1,chestIndex=0){
 if(context)await context.close();context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:dpr});page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))errors.push(m.text());});
 const cdp=await context.newCDPSession(page);await cdp.send('Log.enable');cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error')errors.push(entry.text);});
 const url=new URL(base);for(const[k,v]of Object.entries({native_style_review:1,scale_review:1,scale_scene:scene,scale_chest:chestIndex,quality:'low',at:'npc_courtyard'}))url.searchParams.set(k,v);
 if(baseline&&matched)url.searchParams.set('zoom','0.75');
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassButtons?.stage==='class',null,{timeout:30000});
 for(const key of['warrior','start']){const d=await page.evaluate(k=>({p:window.__sjrpgClassButtons[k],w:innerWidth,h:innerHeight}),key);await page.mouse.click(d.p[0]*d.w,d.p[1]*d.h);await page.waitForTimeout(300);}
 await wait(s=>s.scale?.phase==='live'&&s.ui?.native&&s.native?.native_active&&s.scale.physics_ticks>0,'actual scale review '+scene,90000);await settle();
}
function chestChecks(s){assert.equal(s.scale.chests.length,9,'all nine real native chests owned');for(const c of s.scale.chests){assert(c.model.meshes>=2,'actual base/lid geometry '+c.index);c.model.scale.forEach(x=>near(x,1,'baked chest root scale',.0001));near(c.collision.radius_px,baseline?24:30,'actual chest radius '+c.index,.01);assert(c.model.world_size_m.every(x=>x>0),'volumetric actual chest '+c.index);}checks.push('nine actual native chest owners/colliders');}
function actorChecks(s){assert.equal(s.scale.actors.length,5,'five actual Enemy.setup instances synced');assert.deepEqual(s.scale.actors.map(a=>a.kind).sort(),Object.keys(targets).sort());for(const a of s.scale.actors){assert(a.model.meshes>0&&a.collision.layer>0,'actual model and capsule '+a.kind);near(a.collision.radius_px,baseline?20:radii[a.kind],'actual enemy radius '+a.kind,.01);if(!baseline){near(a.model.world_size_m[1],targets[a.kind],'actual standing mesh height '+a.kind,.035);near(a.collision.height_m,targets[a.kind],'actual capsule height '+a.kind,.035);}}checks.push('five actual enemy scale/capsule measurements');}
try{
 await boot('town');let s=await read();hud(s,'fresh default');near(s.scale.world_zoom,1,'GUI default one',.0001);near(effective(s),baseline?1:.75,'fresh actual base zoom',.001);await capture('default-town');
 await boot('town',true);s=await read();const rects=hudRects(s);const cameraSizes=[];
 for(const amount of[.5,1,1.5]){
  await selectZoom(amount);s=await read();hud(s,'GUI zoom '+amount);assert.deepEqual(hudRects(s),rects,'HUD and minimap geometry unchanged at real zoom '+amount);
  near(effective(s)*s.scale.debug_zoom,.75*amount,'actual effective camera zoom '+amount,.001);cameraSizes.push(s.scale.native_camera_size*amount);await capture('matched-town-zoom-'+amount,amount===1);
 }
 cameraSizes.forEach(x=>near(x,cameraSizes[0],'native orthographic inverse zoom ratio',.01));checks.push('actual GUI three zoom options/camera ratios/HUD invariance');
 await boot('town',true,2);const retinaRects=hudRects(await read());for(const amount of[.5,1,1.5]){await selectZoom(amount);s=await read();hud(s,'DPR2 zoom '+amount);assert.deepEqual(hudRects(s),retinaRects,'DPR2 HUD unchanged');}await selectZoom(1);await capture('matched-town-dpr2',false);
 await boot('actors',true);s=await read();actorChecks(s);const alive=Object.fromEntries(s.scale.actors.map(a=>[a.kind,a]));
 for(const [i,angle]of[0,Math.PI*.5,Math.PI,Math.PI*1.5].entries()){await page.evaluate(angle=>window.__sjrpgScaleAction('face',angle),angle);await settle();await capture('matched-actors-face-'+i,i===0||i===1);}
 await page.evaluate(()=>window.__sjrpgScaleAction('corpses'));s=await wait(s=>s.scale.phase==='corpse_photo'&&s.scale.corpses.length===5,'actual five deaths and native corpse sync',90000);
 assert(s.scale.paused,'explicit corpse photograph freezes only review clock');
 for(const c of s.scale.corpses){assert(alive[c.kind]&&c.time>0,'actual lifetime retained '+c.kind);c.model.scale.forEach((x,i)=>near(x,alive[c.kind].model.scale[i],'same living/corpse native scale '+c.kind,.002));assert(c.model.meshes>0,'actual corpse geometry');}
 await capture('matched-corpses');checks.push('real deaths retain all five model scales');
 await boot('chest',true);s=await read();chestChecks(s);let chest=s.scale.chests.find(c=>c.selected);assert(chest&&!chest.opened,'actual selected closed chest');const gold=s.scale.gold,initialDistance=chest.collision.player_distance_m;await capture('matched-chest-closed');
 const point=css(s,[...chest.screen_foot,0,0]);await page.mouse.click(point.x,point.y,{button:'right'});await settle();
 s=await wait(s=>{const c=s.scale.chests.find(c=>c.selected);return !s.scale.player_moving&&c.collision.player_distance_m<initialDistance-.05;},'actual right-click approach stops at chest collider',30000);
 chest=s.scale.chests.find(c=>c.selected);assert(chest.collision.player_distance_m>=chest.collision.contact_min_m-.04,'real closed chest prevents capsule penetration');await capture('matched-chest-contact',false);
 const hit=css(s,chest.model.projected);await page.mouse.click(hit.x+hit.w*.5,hit.y+hit.h*.65);
 s=await wait(s=>s.scale.chests.find(c=>c.selected)?.opened,'actual left-click attack opens chest',30000);await settle();s=await read();chest=s.scale.chests.find(c=>c.selected);
 assert(chest.lid_angle!==0&&chest.splinters_visible,'actual native opened lid/splinters');assert.equal(chest.collision.layer,0,'consumed chest collider disabled');assert(s.scale.opened_chests.includes(chest.index)&&s.scale.gold>=gold,'actual consumed/reward path');
 await capture('matched-chest-open');checks.push('actual approach/collision/left attack/open/reward');
 await boot('chest',true,1,7);s=await read();chestChecks(s);assert.equal(s.scale.chests.find(c=>c.selected)?.index,7,'actual relocated chest seven');await capture('matched-chest7-closed');checks.push('actual chest seven wall seam witness');
 assert.equal(errors.length,0);console.log('NATIVE_SCALE_PASS '+JSON.stringify({baseline,checks:checks.length,captures:captures.length,errors:0}));
}catch(e){failure=String(e);console.error('NATIVE_SCALE_FAIL '+failure);try{await capture('failure');}catch{}process.exitCode=1;}
finally{await writeFile(path.join(out,'proof.json'),JSON.stringify({url:base.href,baseline,checks,captures,errors,failure,passed:!failure&&!errors.length},null,2));await browser.close();}
