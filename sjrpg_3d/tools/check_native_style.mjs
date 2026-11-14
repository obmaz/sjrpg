#!/usr/bin/env node
import {inspectionUrl} from './review/inspection_url.mjs';
// Actual exported Adventure3D, real pointer/keyboard input, fresh profiles only.
import assert from 'node:assert/strict';
import {assertImportedMerchantAsset} from './review/diagnostic_contracts.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const baseline=process.env.SJRPG_STYLE_BASELINE==='1';
const smoke=process.env.SJRPG_STYLE_SMOKE==='1';
const modelsOnly=process.env.SJRPG_STYLE_MODELS_ONLY==='1';
const merchantOnly=process.env.SJRPG_STYLE_MERCHANT_ONLY==='1';
const merchantPhotoOnly=process.env.SJRPG_MERCHANT_PHOTO_ONLY==='1';
const worldOnly=process.env.SJRPG_STYLE_WORLD_ONLY==='1';
const base=inspectionUrl(process.argv[2]||'http://127.0.0.1:8781/');
const out=path.resolve(process.argv[3]||'build/native-style-review');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const errors=[],captures=[],checks=[],baselineViolations=[],baselineBlockedActions=[],merchantIdleSamples=[];let page,context,failure=null,proportionsLogged=false;
const css=(s,r)=>({x:r[0]*s.window[0]/s.ui.viewport[0],y:r[1]*s.window[1]/s.ui.viewport[1],w:r[2]*s.window[0]/s.ui.viewport[0],h:r[3]*s.window[1]/s.ui.viewport[1]});
const inside=(a,b,e=1)=>b.x>=a.x-e&&b.y>=a.y-e&&b.x+b.w<=a.x+a.w+e&&b.y+b.h<=a.y+a.h+e;
const overlap=(a,b)=>Math.min(a.x+a.w,b.x+b.w)-Math.max(a.x,b.x)>1&&Math.min(a.y+a.h,b.y+b.h)-Math.max(a.y,b.y)>1;
const read=()=>page.evaluate(()=>({ui:window.__sjrpgNativeStyleReview,native:window.__sjrpg3dProbe,tone:window.__sjrpgUiTone,window:[innerWidth,innerHeight],dpr:devicePixelRatio,cavePreviewReady:window.__sjrpgDungeonPreviewReady===true}));
async function wait(fn,label,timeout=15000){const end=Date.now()+timeout;while(Date.now()<end){assert.equal(errors.length,0,JSON.stringify(errors));const s=await read();if(fn(s))return s;await page.waitForTimeout(150);}throw Error('Timeout '+label+' '+JSON.stringify(await read()));}
async function settled(frames=3){const n=(await read()).ui.frame;await wait(s=>s.ui.frame>=n+frames,'actual UI frame settlement');}
function verify(fn,label){if(!baseline)return fn();try{return fn();}catch(e){baselineViolations.push({label,error:String(e)});}}
async function baselineAction(label,fn){if(!baseline)return fn();try{return await fn();}catch(e){baselineBlockedActions.push({label,error:String(e)});if((await read()).ui.panel.rect){await page.keyboard.press('Escape');await settled();}}}
async function tapRect(r){const s=await read();assert(inside({x:0,y:0,w:s.window[0],h:s.window[1]},r),'real target outside viewport '+JSON.stringify(r));await page.mouse.click(r.x+r.w/2,r.y+r.h/2);await settled();}
async function tapHud(key){const s=await read();assert(s.ui.buttons[key],key+' missing');await tapRect(css(s,s.ui.buttons[key]));}
async function capture(name,inline=false){const s=await read();if(!proportionsLogged&&s.ui.coverage?.actor_proportions){console.log('NATIVE_ACTOR_PROPORTIONS '+JSON.stringify(s.ui.coverage.actor_proportions));proportionsLogged=true;}await page.screenshot({path:path.join(out,name+'.png'),timeout:90000});captures.push({name,...s});if(inline){const data=(await page.screenshot({type:'jpeg',quality:78,timeout:90000})).toString('base64');console.log('SJ_NATIVE_STYLE_IMAGE_BEGIN '+name+' image/jpeg '+data.length);for(let i=0;i<data.length;i+=16384)console.log('SJ_NATIVE_STYLE_IMAGE_CHUNK '+name+' '+data.slice(i,i+16384));console.log('SJ_NATIVE_STYLE_IMAGE_END '+name);}}
function hudGeometry(s,label,expectedPaused=false){return verify(()=>strictHudGeometry(s,label,expectedPaused),label);}
function strictHudGeometry(s,label,expectedPaused=false){
 assert(s.ui.native&&s.native?.native_active&&s.native?.simulation==='3d',label+' actual native world');
 if(!baseline){assert.deepEqual(s.ui.coverage.actor_cards,[],label+' no resident/enemy camera-facing object cards');const env=s.ui.coverage.environment;assert(env&&env.remaining_sources,label+' explicit retained source inventory');for(const scope of['forest','cave'])assert.deepEqual(env.remaining_sources[scope],[],label+' no retained physical '+scope+' source cards');for(const key of['forest_sprites','forest_groups','cave_sprites','cave_groups'])assert.equal(Number(env[key]),0,label+' no physical fallback batches '+key);}
 const bounds={x:0,y:0,w:s.window[0],h:s.window[1]};
 const keys=['potion_hp','potion_mp','bar_bag','bar_skills','bar_quests','bar_gear'];
 for(const key of keys){const r=css(s,s.ui.buttons[key]);assert(inside(bounds,r),label+' bounds '+key);if(!baseline)assert(r.w>=43.5&&r.h>=43.5,label+' 44 CSS target '+key+' '+JSON.stringify(r));}
 if(!baseline)for(let i=0;i<keys.length;i++)for(let j=i+1;j<keys.length;j++)assert(!overlap(css(s,s.ui.buttons[keys[i]]),css(s,s.ui.buttons[keys[j]])),label+' separate hitboxes '+keys[i]+'/'+keys[j]);
 assert(inside(bounds,css(s,s.ui.avatar)),label+' avatar frame');
 assert(inside(bounds,css(s,s.ui.level_badge)),label+' avatar level badge');
 assert(inside(bounds,css(s,s.ui.hp))&&inside(bounds,css(s,s.ui.mp)),label+' status gauge bounds');
 assert.equal(s.ui.paused,expectedPaused,label+' expected preview/live pause state');
 if(expectedPaused)assert(s.cavePreviewReady&&s.ui.dungeon_active&&!s.ui.panel.rect,label+' explicit frozen cave photograph, not a gameplay menu');
 checks.push(label);
}
async function closePanel(){const s=await read();const button=s.ui.panel.buttons.find(b=>b.text==='×'||b.text==='모험 계속하기');assert(button,'real close action missing');await tapRect(css(s,button.rect));await wait(s=>!s.ui.paused&&!s.ui.panel.rect,'panel closed');}

function panelGeometry(s,label){return verify(()=>strictPanelGeometry(s,label),label);}
function strictPanelGeometry(s,label){
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
  const seen=[],nativeSizes=[];
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
   seen.push(s.ui.zoom);nativeSizes.push(s.ui.native_camera_size);await capture(label+'-zoom-'+amount);
  }
  assert(new Set(seen.map(x=>x.toFixed(4))).size===3,'three actual camera zoom values');assert(new Set(nativeSizes.map(x=>x.toFixed(4))).size===3,'three actual native orthographic camera sizes');checks.push(label+' real zoom settings');
 }
 await closePanel();
}

async function skillTree(label){

 await tapHud('bar_skills');let s=await wait(s=>s.ui?.panel?.nodes?.length>0&&s.ui.paused,'real skill tree');
 await capture(label+'-skills',true);
 const p=s.ui.panel,bounds={x:0,y:0,w:s.window[0],h:s.window[1]};verify(()=>assert(inside(bounds,css(s,p.rect)),label+' panel bounds'),label);
 if(p.subtitle_visible&&p.subtitle_text)verify(()=>assert(css(s,p.title).y+css(s,p.title).h<=css(s,p.subtitle).y+1,label+' subtitle spacing'),label);
 const clip=css(s,p.tree_clip);assert(clip.w>40&&clip.h>40,label+' tree scroll viewport');
 const nodes=p.nodes.filter(n=>inside(clip,css(s,n.rect)));
 assert(nodes.length>0,label+' visible skill nodes');for(const node of nodes){const hit=css(s,node.hit_rect);if(!baseline)assert(hit.w>=43.5&&hit.h>=43.5,label+' 44 CSS skill target '+node.id);}
 let n=p.nodes.find(n=>n.id!==p.selected&&n.reason==='')||p.nodes.find(n=>n.id!==p.selected);
 assert(n,label+' needs another actual skill to inspect');
 for(let attempt=0;attempt<16;attempt++){
  s=await read();n=s.ui.panel.nodes.find(node=>node.id===n.id);const actualClip=css(s,s.ui.panel.tree_clip),box=css(s,n.rect);
  if(inside(actualClip,box))break;
  await page.mouse.move(actualClip.x+actualClip.w*.5,actualClip.y+actualClip.h*.5);await page.mouse.wheel(0,box.y<actualClip.y?-220:220);await settled();
  if(attempt===15)throw Error('Actual skill scroll cannot expose another skill '+n.id);
 }
 await tapRect(css(s,n.rect));
 s=await wait(s=>s.ui.panel.selected===n.id,'actual node selection');
 const beforeWheel=await read(),currentClip=css(beforeWheel,beforeWheel.ui.panel.tree_clip);
 const beforeScroll=beforeWheel.ui.panel.tree_scroll_value,maxScroll=beforeWheel.ui.panel.tree_scroll_max;
 assert(Number.isFinite(beforeScroll)&&Number.isFinite(maxScroll),label+' actual native scroll metrics');
 if(maxScroll>1){
  const direction=beforeScroll>=maxScroll-1?-1:1;
  const frame=beforeWheel.ui.frame;
  await page.mouse.move(currentClip.x+currentClip.w*.5,currentClip.y+currentClip.h*.5);
  await page.mouse.wheel(0,direction*520);
  const moved=await wait(s=>s.ui.frame>=frame+3&&Math.abs(s.ui.panel.tree_scroll_value-beforeScroll)>1,label+' actual tree scroll');
  checks.push(label+' scroll '+beforeScroll+' -> '+moved.ui.panel.tree_scroll_value+' max '+maxScroll);
 }else{
  assert(beforeWheel.ui.panel.nodes.every(n=>inside(currentClip,css(beforeWheel,n.rect))),label+' all nodes must fit when no scroll range exists');
  checks.push(label+' all actual nodes fit without scrolling');
 }
 await capture(label+'-skills-scrolled');
 checks.push(label+' real skill selection and scroll');
 await closePanel();
}
async function boot(cls,params={},dpr=1){
 if(context)await context.close();
 context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:dpr});page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))errors.push(m.text());});
 const cdp=await context.newCDPSession(page);await cdp.send('Log.enable');cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error')errors.push(entry.text);});
 const url=inspectionUrl(base);url.searchParams.set('native_style_review','1');url.searchParams.set('quality','low');
 for(const[k,v]of Object.entries(params))url.searchParams.set(k,v);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 const titleStart=await page.evaluate(()=>window.__sjrpgTitleButtons?.new_game);
 if(titleStart){const size=page.viewportSize();await page.mouse.click(titleStart[0]*size.width,titleStart[1]*size.height);}
 else await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassButtons?.stage==='class',null,{timeout:30000});
 for(const key of[cls,'start']){const data=await page.evaluate(key=>({p:window.__sjrpgClassButtons[key],w:innerWidth,h:innerHeight}),key);await page.mouse.click(data.p[0]*data.w,data.p[1]*data.h);await page.waitForTimeout(300);}
 await wait(s=>s.ui?.native&&s.native?.native_active&&s.native?.physics_ticks>0,'actual native adventure',90000);
 if(params.dungeon_preview)await page.waitForFunction(()=>window.__sjrpgDungeonPreviewReady===true,null,{timeout:90000});
 if(params.encounter_preview)await page.waitForFunction(()=>window.__sjrpgEncounterPreviewReady===true,null,{timeout:90000});
 if(params.corpse_preview)await page.waitForFunction(()=>window.__sjrpgCorpsePreviewReady===true,null,{timeout:90000});
 await settled();
}
async function modelGallery(){
  await boot('mage',{at:'npc_courtyard'});
  await page.setViewportSize({width:1280,height:1280});await page.waitForTimeout(700);
  assert((await read()).ui.gallery_available,'actual native model gallery resource');
  for(let face=0;face<4;face++){
   await page.evaluate(face=>window.__sjrpgNativeStyleAction('gallery',face),face);
   const g=await wait(s=>s.ui.gallery&&s.ui.gallery.face===face&&s.ui.gallery.current_frame>=s.ui.gallery.requested_frame+3,'actual all-face model gallery',90000);
   assert.equal(g.ui.gallery.count,14,'all actual actor archetypes in gallery');
   assert.equal(g.ui.gallery.projection,'orthographic');
   if(g.ui.merchant?.source==='cc0_import'){const merchant=g.ui.gallery.models.find(m=>m.identity==='merchant');assert(merchant?.skeletons>0&&merchant.skinned_meshes>0,'full gallery uses actual imported merchant factory');assertImportedMerchantAsset(merchant,'full gallery');}
   for(const model of g.ui.gallery.models){assert(model.triangles>0&&model.surfaces>0,'actual mesh '+model.identity);assert(model.bounds_max.every((v,i)=>v>model.bounds_min[i]),'three-dimensional envelope '+model.identity);}
   await capture('native-gallery-face-'+face,true);checks.push('actual native model face '+face);
  }
  await page.evaluate(()=>window.__sjrpgNativeStyleAction('gallery',-1));
}
async function worldScenes(){
 // at=lmN retains the original village array identity; authored roles are [2,1,0,3].
 const worldFailures=[];
 for(const [name,params]of[['bridge',{at:'bridge'}],['landmark0-overview',{at:'lm0',zoom:'0.5'}],['landmark1-overview',{at:'lm1',zoom:'0.5'}],['landmark2-overview',{at:'lm2',zoom:'0.5'}],['landmark3',{at:'lm3'}],['cave-outside',{at:'rowen',zoom:'0.8'}],['cave',{dungeon_preview:'entry'}],['enemy',{at:'field',encounter_preview:'active'}],['corpses-bridge',{corpse_preview:'bridge'}]]){
  try{
  await boot('mage',params);
  const landmark=/^landmark([0-3])-overview$/.exec(name);
  await page.waitForTimeout(800);const state=await read();hudGeometry(state,name,Boolean(params.dungeon_preview));if(landmark&&!baseline){
   const role=[2,1,0,3][Number(landmark[1])],witness=state.ui.coverage.landmark_views?.find(v=>v.role===role);
   assert(witness&&witness.meshes>0,name+' actual authored mesh projection witness');
   assert.equal(witness.center_behind_camera,false,name+' actual landmark in front of camera');
   const box=css(state,witness.projected);
   assert(witness.visible_area_ratio>=.55&&box.h>=100&&box.w>=100,name+' majority of actual authored mesh envelope must be visible '+JSON.stringify(witness));
   checks.push(name+' actual '+witness.meshes+' meshes visible area '+witness.visible_area_ratio);
  }if(name==='cave-outside'){assert.equal(state.ui.dungeon_active,false,'actual exterior remains forest');assert(state.ui.entry_distance<180,'actual exterior camera is at the real cave entrance');assert.equal(state.native.scope,'forest');}if(name==='corpses-bridge'){assert(state.ui.coverage.corpse_count>0,'actual corpse models exist');if(!baseline)assert.deepEqual(state.ui.coverage.corpse_cards,[],'no image-card corpse fallback');}await capture(name+'-native',true);
  }catch(error){worldFailures.push({name,error:String(error)});console.error('NATIVE_STYLE_WORLD_CASE_FAIL '+JSON.stringify(worldFailures.at(-1)));try{await capture(name+'-failed',true);}catch{}if(errors.length)throw error;}
 }
 assert.deepEqual(worldFailures,[],'all actual world cases must pass');
}

function poseDelta(a,b){
 if(!a?.length||a.length!==b?.length)return 0;
 return Math.max(...a.flat().map((v,i)=>Math.abs(v-b.flat()[i])));
}
function merchantGeometry(s,label){
 const m=s.ui.merchant;assert(m?.identity==='merchant',label+' actual runtime merchant source');
 assert.equal(m.near_name,'상인',label+' actual nearby resident');
 assert(m.circle?.radius>0&&m.meshes>0,label+' actual resident geometry/collision owner');
 if(!baseline){assert.equal(m.source,'cc0_import',label+' actual runtime imported factory');assertImportedMerchantAsset(m,label);assert(m.bone_count>=20&&m.skinned_meshes>0,label+' real skeleton-bound meshes');assert(m.clip.toLowerCase().includes('idle'),label+' actual idle clip');m.model_position.forEach((v,i)=>assert(Math.abs(v-m.native_foot[i])<.01,label+' actual model follows physical NPC foot'));}
 const box=css(s,s.ui.buttons.near_shop),bounds={x:0,y:0,w:s.window[0],h:s.window[1]};assert(inside(bounds,box),label+' actual interaction target inside viewport');
 verify(()=>assert(box.w>=43.5&&box.h>=43.5,label+' 44 CSS interaction target'),label);
 if(!baseline){
  for(const key of['bar_bag','bar_skills','bar_quests','bar_gear','potion_hp','potion_mp','slot0','slot1','slot2','slot3','slot4','roll']){
   const r=css(s,s.ui.buttons[key]),cx=r.x+r.w/2,cy=r.y+r.h/2;
   const dx=cx-Math.max(box.x,Math.min(cx,box.x+box.w)),dy=cy-Math.max(box.y,Math.min(cy,box.y+box.h));
   assert(dx*dx+dy*dy>=Math.pow(r.w/2-1,2),label+' actual rect/circle hit areas separate '+key);
  }
 }
 checks.push(label+' actual merchant factory and physical interaction target');
}
async function merchantPilot(){
 const shots=[];
 const views=merchantPhotoOnly?[['portrait',390,844,1]]:[['portrait',390,844,1],['landscape',844,390,1],['retina',390,844,2]];
 for(const [label,w,h,dpr]of views){
  await boot('mage',{at:'npc_nw'},dpr);
  if(w!==390||h!==844){await page.setViewportSize({width:w,height:h});await wait(s=>s.window[0]===w&&s.window[1]===h&&s.ui.viewport[0]>s.ui.viewport[1],'real merchant orientation');await settled();}
  let s=await wait(s=>s.ui.merchant?.identity==='merchant'&&s.ui.merchant.near_name==='상인','actual nearby merchant');
  const approach=s.ui.merchant.review_approaches.find(p=>p.legal&&Math.abs(p.point[0]-s.ui.merchant.source_position[0])>=120);
  assert(approach,label+' actual legal lateral photography point');
  const click=css(s,[...approach.projected,0,0]);
  await page.mouse.click(click.x,click.y,{button:'right'});
  s=await wait(s=>Math.hypot(s.ui.player[0]-approach.point[0],s.ui.player[1]-approach.point[1])<=3.01&&s.ui.merchant.near_name==='상인',label+' real right-click walk to legal lateral point',30000);
  await settled(6);s=await read();
  assert(Math.abs(s.ui.player[0]-s.ui.merchant.source_position[0])>=105,label+' actual hero and NPC have lateral separation');
  hudGeometry(s,'merchant '+label);merchantGeometry(s,'merchant '+label);
  const quests=JSON.stringify(s.ui.merchant.quests),start=s.ui.merchant,frame=s.ui.frame;
  if(!baseline){await wait(s=>s.ui.frame>=frame+3&&s.ui.merchant.source_time>start.source_time+.04&&Math.abs(s.ui.merchant.sample_time-start.sample_time)>.01&&poseDelta(start.bone_poses,s.ui.merchant.bone_poses)>1e-6,'real imported idle advances actual bone poses');checks.push(label+' actual source-clock skeletal idle');}
  await capture('merchant-'+label+'-town',true);
  if(merchantPhotoOnly){checks.push(label+' actual unoccluded town photography via real movement');continue;}
  await tapHud('near_shop');s=await wait(s=>s.ui.paused&&s.ui.panel.shopping===true&&s.ui.panel.title_text==='상점','real merchant interaction opens shop');
  assert.equal(JSON.stringify(s.ui.merchant.quests),quests,'merchant interaction leaves quests unchanged');
  const paused=s.ui.merchant;await page.waitForTimeout(650);await settled();s=await read();
  merchantIdleSamples.push({label,imported:!baseline,live_start_source:start.source_time,live_start_sample:start.sample_time,paused_source:paused.source_time,paused_sample:paused.sample_time,live_pose_delta:poseDelta(start.bone_poses,paused.bone_poses),paused_pose_delta:poseDelta(paused.bone_poses,s.ui.merchant.bone_poses),paused_after_source:s.ui.merchant.source_time,paused_after_sample:s.ui.merchant.sample_time});
  console.log('NATIVE_MERCHANT_IDLE '+JSON.stringify(merchantIdleSamples.at(-1)));
  assert.equal(s.ui.merchant.source_time,paused.source_time,'real shop pause freezes source clock');
  assert.equal(s.ui.merchant.sample_time,paused.sample_time,'real shop pause freezes sampled idle');
  assert.equal(poseDelta(paused.bone_poses,s.ui.merchant.bone_poses),0,'real shop pause freezes bone poses');
  await capture('merchant-'+label+'-shop',label==='portrait');await closePanel();
  if(!baseline){await wait(s=>s.ui.merchant.source_time>paused.source_time+.04&&poseDelta(paused.bone_poses,s.ui.merchant.bone_poses)>1e-6,'real idle resumes after closing shop');}
  assert.equal(JSON.stringify((await read()).ui.merchant.quests),quests,'close merchant shop leaves quests unchanged');
  checks.push(label+' real shop click, paused skeleton and resume');shots.push(label);
 }
 if(merchantPhotoOnly)return;
 await boot('mage',{at:'npc_nw'});await page.setViewportSize({width:768,height:768});await settled();
 for(let face=0;face<4;face++){
  await page.evaluate(face=>window.__sjrpgNativeStyleAction('merchant_gallery',face),face);
  const s=await wait(s=>s.ui.gallery?.merchant_only&&s.ui.gallery.face===face&&s.ui.gallery.current_frame>=s.ui.gallery.requested_frame+3,'actual factory merchant gallery',90000);
  assert.equal(s.ui.gallery.count,1);assert.deepEqual(s.ui.gallery.mapped,['merchant']);assert.equal(s.ui.gallery.projection,'orthographic');
  const model=s.ui.gallery.models[0];assert(model.triangles>0&&model.surfaces>0,'actual merchant mesh');
  if(!baseline){assert(model.skeletons>0&&model.skinned_meshes>0,'gallery uses actual imported runtime factory');assertImportedMerchantAsset(model,'merchant gallery');assert(model.sample.clip.toLowerCase().includes('idle'),'gallery samples actual runtime idle');assert(Math.abs((model.bounds_max[1]-model.bounds_min[1])-1.78)<.035,'gallery actual normalized adult height');}
  await capture('merchant-gallery-face-'+face,true);checks.push('actual imported merchant factory camera face '+face);
 }
 await page.evaluate(()=>window.__sjrpgNativeStyleAction('merchant_gallery',-1));
}

try{
 if(modelsOnly){await modelGallery();}
 else if(merchantOnly){await merchantPilot();}
 else if(worldOnly){await worldScenes();}
 else if(smoke){
  await boot('mage',{at:'npc_courtyard'});hudGeometry(await read(),'public mage portrait');await capture('public-mage-hud',true);
  await tapHud('bar_skills');await wait(s=>s.ui?.panel?.nodes?.length>0&&s.ui.paused,'public real skill panel');panelGeometry(await read(),'public skill panel');await capture('public-mage-skills',true);await closePanel();checks.push('public actual skill panel open/close');
  await boot('mage',{at:'npc_courtyard'},2);hudGeometry(await read(),'public mage DPR2 portrait');await capture('public-mage-dpr2-hud',true);
 }else{
 for(const cls of['warrior','mage']){
  await boot(cls,{at:'npc_courtyard'});
  for(const [rotation,[w,h]]of[[390,844],[320,640],[568,320],[390,844]].entries()){
   await page.setViewportSize({width:w,height:h});await wait(s=>s.window[0]===w&&s.window[1]===h&&((s.ui.viewport[0]>s.ui.viewport[1])===(w>h)),'rotation');await settled();
   const label=cls+'-'+w+'x'+h+(rotation===3?'-returned':'');hudGeometry(await read(),label);await capture(label+'-hud',rotation!==3&&(w===390||w===568));
   if(rotation!==3)await baselineAction(label+' skill tree',()=>skillTree(label));
   if(rotation===0)for(const key of['bar_bag','bar_quests','bar_gear'])await baselineAction(label+' '+key,()=>menuPanel(key,label+'-'+key));
  }
  const before=(await read()).ui.player;let distance=0;
  for(const key of ['d','a','w','s']){await page.keyboard.down(key);await page.waitForTimeout(350);await page.keyboard.up(key);await page.waitForTimeout(100);const p=(await read()).ui.player;distance=Math.hypot(p[0]-before[0],p[1]-before[1]);if(distance>1)break;}
  await capture(cls+'-walking-native');
  assert(distance>1,'real WASD movement');checks.push(cls+' actual movement');
 }
 await boot('mage',{at:'npc_courtyard'},2);hudGeometry(await read(),'mage DPR2 portrait');await capture('mage-dpr2-portrait',true);
 await worldScenes();
 if(!baseline)await modelGallery();
 }
 assert.equal(errors.length,0);console.log((modelsOnly?'NATIVE_STYLE_MODELS_PASS ':merchantOnly?(merchantPhotoOnly?'NATIVE_STYLE_MERCHANT_PHOTO_PASS ':'NATIVE_STYLE_MERCHANT_PASS '):worldOnly?'NATIVE_STYLE_WORLD_PASS ':smoke?'NATIVE_STYLE_SMOKE_PASS ':baseline?'NATIVE_STYLE_BASELINE_CAPTURED ':'NATIVE_STYLE_PASS ')+JSON.stringify({checks:checks.length,captures:captures.length,errors:0,baselineViolations:baselineViolations.length,baselineBlockedActions:baselineBlockedActions.length}));
}catch(e){failure=String(e);console.error('NATIVE_STYLE_FAIL '+failure);try{await capture('failure',true);}catch{}process.exitCode=1;}
finally{await writeFile(path.join(out,'proof.json'),JSON.stringify({url:base.href,modelsOnly,merchantOnly,merchantPhotoOnly,worldOnly,baseline,smoke,merchantIdleSamples,baselineViolations,baselineBlockedActions,checks,captures,errors,failure,passed:!failure&&!errors.length},null,2));await browser.close();}
