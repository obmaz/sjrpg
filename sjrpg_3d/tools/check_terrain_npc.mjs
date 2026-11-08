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
const npcs=process.env.SJRPG_REVIEW_NPCS==='true';
const expectedImports=(process.env.SJRPG_REVIEW_NPC_IDENTITIES||'').split(',').filter(Boolean);
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const errors=[],captures=[],checks=[];let context,page,failure=null;
const read=()=>page.evaluate(()=>({ui:window.__sjrpgNativeStyleReview,native:window.__sjrpg3dProbe,review:window.__sjrpgTerrainNpcReview,window:[innerWidth,innerHeight]}));
async function wait(fn,label,timeout=90000){const end=Date.now()+timeout;while(Date.now()<end){assert.equal(errors.length,0,JSON.stringify(errors));const s=await read();if(fn(s))return s;await page.waitForTimeout(120);}throw Error('Timeout '+label+' '+JSON.stringify(await read()));}
async function settle(frames=4){const first=(await read()).review.frame;return wait(s=>s.review.frame>=first+frames,'drawn native frames');}
async function boot(params={}){
 if(context)await context.close();
 context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
 page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))errors.push(m.text());});
 const url=new URL(base);url.searchParams.set('native_style_review','1');url.searchParams.set('quality','high');
 for(const[k,v]of Object.entries(params))url.searchParams.set(k,v);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassButtons?.stage==='class',null,{timeout:30000});
 for(const key of['mage','start']){
  const b=await page.evaluate(key=>({p:window.__sjrpgClassButtons[key],w:innerWidth,h:innerHeight}),key);
  await page.mouse.click(b.p[0]*b.w,b.p[1]*b.h);await page.waitForTimeout(250);
 }
 await wait(s=>s.review?.terrain?.length===4&&s.native?.native_active&&s.native?.physics_ticks>0,'actual native terrain ready');
 await settle();
}
async function action(mode,role,face){
 await page.evaluate(([mode,role,face])=>window.__sjrpgTerrainNpcAction(mode,role,face),[mode,role,face]);
 return wait(s=>s.review.mode===mode&&s.review.role===role&&s.review.face===face&&s.review.frame>=s.review.requested_frame+4,'actual native photography '+mode);
}
function poseDelta(a,b){if(!a?.length||a.length!==b?.length)return 0;const x=a.flat(),y=b.flat();return Math.max(...x.map((v,i)=>Math.abs(v-y[i])));}
async function capture(name){
 const s=await read();await page.screenshot({path:path.join(out,name+'.png'),timeout:90000});
 captures.push({name,...s});return s;
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
 for(const role of[0,1,2,3]){
  await boot({at:'lm'+role});
  const initial=(await read()).review.physics;
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
 if(npcs){
  await boot({at:'npc_courtyard'});await page.setViewportSize({width:1024,height:1024});await settle();
  for(let face=0;face<4;face++){
   const s=await action('residents',0,face),g=s.review.gallery;
   assert(g&&g.count===9,'eight actual residents and adult hero scale reference');
   assert.equal(g.projection,'orthographic');assert.equal(g.elevation,35.264389682754654);
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
 }
 console.log('TERRAIN_NPC_REVIEW_PASS '+JSON.stringify({baseline,npcs,captures:captures.length,checks:checks.length,errors:errors.length}));
}catch(error){failure=String(error);console.error('TERRAIN_NPC_REVIEW_FAIL '+failure);try{await capture('failure');}catch{}process.exitCode=1;}
finally{
 await writeFile(path.join(out,'proof.json'),JSON.stringify({url:base.href,baseline,npcs,expectedImports,checks,captures,errors,failure,passed:!failure&&!errors.length},null,2));
 await browser.close();
}
