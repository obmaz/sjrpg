#!/usr/bin/env node
// Native world/model photography. The CI-only observer never moves physical actors.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=new URL(process.argv[2]||'http://127.0.0.1:8786/');
const out=path.resolve(process.argv[3]||'build/terrain-npc-review');
const baseline=process.env.SJRPG_TERRAIN_EDITION==='before';
const scope=process.env.SJRPG_REVIEW_SCOPE||'terrain';
assert(['terrain','architecture','all'].includes(scope),'explicit focused review scope');
const npcs=scope!=='architecture'&&process.env.SJRPG_REVIEW_NPCS==='true';
const worldQuality=process.env.SJRPG_REVIEW_WORLD_QUALITY||'low';
assert(['low','high'].includes(worldQuality),'explicit supported actual world quality');
const expectedImports=(process.env.SJRPG_REVIEW_NPC_IDENTITIES||'').split(',').filter(Boolean);
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const errors=[],captures=[],checks=[];let context,page,failure=null;
function timed(promise,label,ms=30000){let timer;const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timeout '+label)),ms);timer.unref();});return Promise.race([promise,timeout]).finally(()=>clearTimeout(timer));}
const mark=(label,data={})=>console.log('TERRAIN_NPC_PROGRESS '+JSON.stringify({at:new Date().toISOString(),label,...data}));
const read=()=>timed(page.evaluate(()=>({ui:window.__sjrpgNativeStyleReview,native:window.__sjrpg3dProbe,review:window.__sjrpgTerrainNpcReview,window:[innerWidth,innerHeight]})),'read native browser state');
const watchdog=setTimeout(()=>{console.error('TERRAIN_NPC_WATCHDOG_FAIL '+JSON.stringify({captures:captures.map(c=>c.name),errors}));process.exit(2);},12*60*1000);watchdog.unref();
async function wait(fn,label,timeout=90000){const end=Date.now()+timeout;while(Date.now()<end){assert.equal(errors.length,0,JSON.stringify(errors));const s=await read();if(fn(s))return s;await page.waitForTimeout(120);}throw Error('Timeout '+label+' '+JSON.stringify(await read()));}
async function settle(frames=4){const first=(await read()).review.frame;return wait(s=>s.review.frame>=first+frames,'drawn native frames');}
async function boot(params={},quality=worldQuality){
 mark('boot begin',{params,quality});
 if(context)await timed(context.close(),'close prior native context');
 context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
 page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))errors.push(m.text());});
 const url=new URL(base);url.searchParams.set('native_style_review','1');url.searchParams.set('quality',quality);
 for(const[k,v]of Object.entries(params))url.searchParams.set(k,v);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});mark('document ready',{url:url.href});
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 mark('title ready');await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassButtons?.stage==='class',null,{timeout:30000});
 for(const key of['mage','start']){
  const b=await page.evaluate(key=>({p:window.__sjrpgClassButtons[key],w:innerWidth,h:innerHeight}),key);
  await page.mouse.click(b.p[0]*b.w,b.p[1]*b.h);await page.waitForTimeout(250);
 }
 mark('class selected');await wait(s=>s.review?.terrain?.length===4&&s.native?.native_active&&s.native?.physics_ticks>0,'actual native terrain ready');
 await settle();mark('actual native ready',{quality});
}
async function action(mode,role,face){
 mark('photography begin',{mode,role,face});
 await timed(page.evaluate(([mode,role,face])=>window.__sjrpgTerrainNpcAction(mode,role,face),[mode,role,face]),'apply photography view');
 return wait(s=>s.review.mode===mode&&s.review.role===role&&s.review.face===face&&s.review.frame>=s.review.requested_frame+4,'actual native photography '+mode);
}
function poseDelta(a,b){if(!a?.length||a.length!==b?.length)return 0;const x=a.flat(),y=b.flat();return Math.max(...x.map((v,i)=>Math.abs(v-y[i])));}
async function capture(name){
 mark('capture begin',{name});const s=await read();if(name!=='failure'){assert.equal(s.ui.paused,false,'actual game remains live during photography '+name);assert(!s.ui.panel.rect,'no gameplay overlay covers actual photograph '+name);assert.equal(s.ui.dungeon_active,false,'actual safe forest scene '+name);}await page.screenshot({path:path.join(out,name+'.png'),timeout:90000});
 captures.push({name,...s});await writeFile(path.join(out,'progress.json'),JSON.stringify({captures:captures.map(c=>({name:c.name,frame:c.review.frame,quality:c.review.quality,render_size:c.review.render_size})),errors},null,2));mark('capture complete',{name,frame:s.review.frame,quality:s.review.quality,render_size:s.review.render_size,gallery_render_size:s.review.gallery?.render_size});return s;
}
function verifyTerrain(s,role){
 assert.equal(s.review.projection,'orthographic');assert(Math.abs(s.review.elevation-35.264389682754654)<1e-4,'measured true isometric camera elevation');
 for(const axis of s.review.axes){const angle=((Math.atan2(axis[1],axis[0])*180/Math.PI)%180+180)%180;assert(Math.min(...[30,90,150].map(target=>Math.abs(angle-target)))<.02,'actual projected native axis '+angle);}
 assert(s.review.physics.length>=5,'shared physical terrain surfaces');
 const material=s.review.terrain.find(t=>t.role===role);
 assert(material&&material.rise>0,'real positive landmark height '+role);
 if(!baseline&&role!==1){
  assert.equal(material.upper_texture,material.lower_texture,'reuse identical ground source');
  assert.notDeepEqual(material.upper_color,material.lower_color,'readable raised turf '+role);
  assert(material.earth,'exposed earth exists on original cliff '+role);
  assert.equal(material.earth_texture,'res://assets/art/village/rock.webp','reuse actual cliff source');
 }else if(role===1)assert(material.upper_texture.includes('paving'),'stone landmark stays paved');
 checks.push('actual shared surface/material '+role+' '+s.review.azimuth);
}
try{
 await boot({at:'npc_courtyard'});
 const initialState=await read(),initial=initialState.review.physics,initialStatic=initialState.review.static_physics_sha256;
 const construction=await timed(page.evaluate(()=>window.__sjrpgTerrainNpcStaticPhysics),'read original native construction colliders');
 await writeFile(path.join(out,'static-physics.json'),JSON.stringify(construction,null,2));
 if(scope!=='architecture'){
 // Every native landmark is already built in this actual safe town scene.
 // Move only the render camera; keep the real player safe and clocks live.
 for(const role of[0,1,2,3]){
  for(const[label,width,height]of[['portrait',390,844],['landscape',844,390]]){
   await page.setViewportSize({width,height});
   await wait(s=>s.window[0]===width&&s.window[1]===height&&((width>height)===(s.ui.viewport[0]>s.ui.viewport[1])),'real orientation');
   for(const face of[0,2]){
    const s=await action('terrain',role,face);
    assert.deepEqual(s.review.physics,initial,'photography never changes physical floor/ramp data');
    verifyTerrain(s,role);
    await capture('terrain-'+role+'-'+label+'-face-'+face);
   }
  }
 }
 }
 if(scope==='architecture'||scope==='all'){
  for(const[label,width,height]of[['portrait',390,844],['landscape',844,390]]){
   await page.setViewportSize({width,height});await action('clear',0,0);await settle();
   const s=await read();assert.equal(s.review.hud_hidden,false,'normal actual game keeps its HUD');assert.equal(s.ui.paused,false,'normal actual game is live');
   await capture('village-normal-'+label);
  }
  // House facades/roof both opposite corners, gate exterior/interior,
  // corner crown and a fixed original-wall section with visible pier/recess.
  const views=[
   ...[0,1,2,3].flatMap(role=>[0,2].map(face=>({mode:'house',role,face,label:'house-'+role+'-face-'+face}))),
   ...[0,2].map(face=>({mode:'gate',role:0,face,label:'gate-0-face-'+face})),
   ...[0,2].map(face=>({mode:'corner',role:0,face,label:'wall-corner-0-face-'+face})),
   ...[0,2].map(face=>({mode:'wall_detail',role:0,face,label:'wall-detail-face-'+face}))
  ];
  await page.setViewportSize({width:768,height:768});await settle();
  const sides=[];
  for(const view of views){
   const s=await action(view.mode,view.role,view.face),a=s.review.architecture;
   assert(a&&a.kind===view.mode,'actual architecture report '+view.label);
   assert.equal(s.ui.paused,false,'live original safe town clock');
   assert.equal(s.review.hud_hidden,true,'explicit inspection removes only HUD coverage');
   assert.deepEqual(s.review.physics,initial,'actual physical surfaces unchanged');
   assert.equal(s.review.static_physics_sha256,initialStatic,'actual construction colliders unchanged during photo');
   assert.equal(s.review.projection,'orthographic');assert(Math.abs(s.review.elevation-35.264389682754654)<1e-4,'actual isometric camera elevation');
   assert(Math.abs(s.review.azimuth-(45+view.face*90))<1e-4,'actual requested opposite camera corner');
   assert(a.same_fortification_stone,'actual shared wall/gate/house stone material');
   assert(a.stone.triplanar&&a.stone.world_triplanar,'world-metre limestone material');
   assert(a.stone.uv_scale.every(v=>Math.abs(v-1/2.56)<1e-6),'same 2.56m source texel scale');
   if(view.mode==='house'){assert(a.same_house_stone&&a.closed_door,'actual house material/closed-door contract');assert(a.triangles>0&&a.surfaces<=5,'bounded actual house geometry');}
   if(view.mode==='gate')sides.push(a.view_side);
   await capture(view.label);checks.push('actual architecture '+view.label);
  }
  assert.deepEqual(sides.sort(),['inside','outside'],'photograph both actual gate sides');
  await action('clear',0,0);await settle();assert.equal((await read()).review.hud_hidden,false,'inspection restores actual original HUD');
 }
 if(npcs){
  await boot({at:'npc_courtyard'},'high');await page.setViewportSize({width:1024,height:1024});await settle();
  for(let face=0;face<4;face++){
   const s=await action('residents',0,face),g=s.review.gallery;
   assert(g&&g.count===9,'eight actual residents and adult hero scale reference');
   assert.equal(g.projection,'orthographic');assert(Math.abs(g.elevation-35.264389682754654)<1e-10,'gallery metadata preserves the true isometric elevation through Godot JSON rounding');
   assert(g.models.some(m=>m.identity==='warrior'),'actual hero scale reference');
   for(const m of g.models){
    assert(m.triangles>0&&m.surfaces>0,'actual native mesh '+m.identity);
    assert(m.bounds_max.every((v,i)=>v>m.bounds_min[i]),'full 3D envelope '+m.identity);
    if(!baseline&&expectedImports.includes(m.identity)){
     assert(m.skeletons>0&&m.skinned_meshes>0,'real skinned imported model '+m.identity);
     assert(m.scene_paths.some(p=>p.endsWith('/'+m.identity+'.glb')),'real imported scene '+m.identity);
     assert(m.sample.clip.toLowerCase().includes('idle'),'source-clock idle sample '+m.identity);
     assert(m.triangles<=18000&&m.surfaces<=8,'bounded imported geometry '+m.identity);
     assert(m.bounds_max[1]-m.bounds_min[1]>=1.6&&m.bounds_max[1]-m.bounds_min[1]<=1.9,'adult height '+m.identity);
    }
   }
   if(!baseline&&face===0){
    for(const id of expectedImports){
     const first=s.review.native_poses?.[id];assert(first?.bone_poses?.length>=20,'actual live native skeleton '+id);
     await wait(next=>{const now=next.review.native_poses?.[id];return now&&now.source_time>first.source_time+.06&&poseDelta(first.bone_poses,now.bone_poses)>1e-6;},'actual live source-clock bone motion '+id);
     checks.push('actual live source-clock skeletal idle '+id);
    }
   }
   await capture('residents-face-'+face);
   checks.push('actual NPC factory and hero scale face '+face);
  }
  for(let face=0;face<4;face++){
   const s=await action('residents',1,face),g=s.review.gallery;
   assert(g&&g.count===3,'three actual runtime models in facial/clothing closeup');
   assert.equal(s.review.quality,'high','actual high game profile for NPC closeup');assert(g.render_size[0]>=1024&&g.render_size[1]>=1024&&g.msaa>0,'full-resolution antialiased native model render');assert(g.world_render_disabled_behind_opaque_gallery,'unseen forest is not shaded behind the opaque model photograph');
   assert.deepEqual(g.models.map(m=>m.identity).sort(),['merchant','mira','warrior']);
   assert.equal(s.review.projection,'orthographic');assert(Math.abs(s.review.elevation-35.264389682754654)<1e-4);
   for(const m of g.models)assert(m.bounds_max[1]-m.bounds_min[1]>=1.6&&m.bounds_max[1]-m.bounds_min[1]<=2.0,'same adult height in closeup '+m.identity);
   await capture('npc-closeup-face-'+face);checks.push('actual three-model face/UV/hood closeup '+face);
  }
 }
 console.log('TERRAIN_NPC_REVIEW_PASS '+JSON.stringify({baseline,npcs,captures:captures.length,checks:checks.length,errors:errors.length}));
}catch(error){failure=String(error);console.error('TERRAIN_NPC_REVIEW_FAIL '+failure);try{await capture('failure');}catch{}process.exitCode=1;}
finally{
 clearTimeout(watchdog);await writeFile(path.join(out,'proof.json'),JSON.stringify({url:base.href,baseline,npcs,scope,worldQuality,expectedImports,checks,captures,errors,failure,passed:!failure&&!errors.length},null,2));
 await browser.close();
}
