#!/usr/bin/env node
// Real uninterrupted town movement. No spawn fixtures, teleportation, HP edits or forced GC.
import assert from 'node:assert/strict';
import {mkdir,writeFile,appendFile,readFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {installResourceTelemetry} from './resource_telemetry.mjs';
import {installWalkingTelemetry} from './walking_resource_telemetry.mjs';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=new URL(process.argv[2]||'http://127.0.0.1:8792/'),out=path.resolve(process.argv[3]||'build/town-walk');
const variant=process.env.SJRPG_WALK_VARIANT||'mage-high-touch';
const [hero,quality,input]=variant.split('-');
const profile={width:input==='keys'?390:768,height:input==='keys'?844:1024,dpr:3};
const duration=Math.min(300000,Math.max(30000,Number(process.env.SJRPG_WALK_DURATION_MS||90000)));
await mkdir(out,{recursive:true});
const report={edition:process.env.SJRPG_WALK_EDITION||'actual',profile,source_sha:process.env.SJRPG_WALK_SHA||null,variant,hero,quality,input,duration,passed:false,errors:[],samples:[],segments:[],limitations:['Chromium SwiftShader is a software-rendered CI route, not physical mobile FPS or driver memory certification.','Standalone/fullscreen display-mode is emulated at the requested fold viewport; this is not an installation or OS process-kill certification.','WebGL allocation counters are API storage estimates; Godot counters, Chrome RSS and PSS are reported separately.','Sum RSS double counts shared pages; aggregate PSS is reported when procfs permits.','Uninterrupted normal town gameplay can continue normal spawning, animation and autosave; no HP/gameplay-clock edits.']};
let browser,server,context,page,cdp,closing=false,monitor,rssBusy=false,touchActive=false;
let latest=null,walkDistance=0,cameraDistance=0,priorPosition=null,priorCamera=null;
async function event(kind,detail){const e={at:Date.now(),kind,detail};report.errors.push(e);await appendFile(path.join(out,'events.ndjson'),JSON.stringify(e)+'\n');}
async function osSample(){
 if(rssBusy||!server)return;rssBusy=true;
 try{
  const root=server.process().pid,entries=[];
  for(const name of await readdir('/proc'))if(/^\d+$/.test(name)){
   try{
    const text=await readFile('/proc/'+name+'/status','utf8'),pid=Number(name),get=key=>Number(new RegExp('^'+key+':\\s+(\\d+)','m').exec(text)?.[1]||0);
    entries.push({pid,ppid:get('PPid'),rss_bytes:get('VmRSS')*1024,hwm_bytes:get('VmHWM')*1024,swap_bytes:get('VmSwap')*1024,threads:get('Threads')});
   }catch{}
  }
  const selected=new Set([root]);let grew=true;while(grew){grew=false;for(const e of entries)if(selected.has(e.ppid)&&!selected.has(e.pid)){selected.add(e.pid);grew=true;}}
  const processes=entries.filter(e=>selected.has(e.pid));
  for(const e of processes){
   try{const command=(await readFile('/proc/'+e.pid+'/cmdline','utf8')).split('\0');e.role=/(?:^|\s)--type=([^\s]+)/.exec(command.join(' '))?.[1]||'browser';}catch{e.role='exited';}
   try{const smaps=await readFile('/proc/'+e.pid+'/smaps_rollup','utf8');e.pss_bytes=Number(/^Pss:\s+(\d+)/m.exec(smaps)?.[1]||0)*1024;}catch{e.pss_bytes=null;}
  }
  const sample={wall:Date.now(),root_pid:root,processes,rss_sum_bytes:processes.reduce((n,p)=>n+p.rss_bytes,0),pss_sum_bytes:processes.every(p=>p.pss_bytes!==null)?processes.reduce((n,p)=>n+p.pss_bytes,0):null,node_recorder_rss:process.memoryUsage().rss};
  await appendFile(path.join(out,'process-memory.ndjson'),JSON.stringify(sample)+'\n');
  console.log('WALK_PROCESS_MEMORY '+JSON.stringify({wall:sample.wall,rss_sum_bytes:sample.rss_sum_bytes,pss_sum_bytes:sample.pss_sum_bytes,processes:processes.map(p=>({pid:p.pid,role:p.role,rss_bytes:p.rss_bytes,pss_bytes:p.pss_bytes}))}));
 }finally{rssBusy=false;}
}
async function timeout(promise,ms,label){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' protocol stall '+ms+'ms')),ms);})]);}finally{clearTimeout(timer);}}
async function read(){
 return timeout(page.evaluate(()=>{
  const raw=window.__sjrpgResourceRead?.(),walk=window.__sjrpgWalkingRead?.();
  return {runtime:window.__sjrpgResourceProfile,entry:window.__sjrpgClassButtons,title:window.__sjrpgTitleReady,ready:window.__sjrpgAdventureReady,loading:window.__sjrpgEntryLoading,size:[innerWidth,innerHeight],dpr:devicePixelRatio,visibility:document.visibilityState,standalone:navigator.standalone===true,fullscreen:window.SjrpgFullscreen?.state?.(),document_token:window.__sjrpgWalkingDocumentToken,canvases:[...document.querySelectorAll('canvas')].map(c=>({id:c.id,width:c.width,height:c.height,css_width:c.getBoundingClientRect().width,css_height:c.getBoundingClientRect().height})),user_agent:navigator.userAgent,telemetry:raw?{at:raw.at,wasm:raw.wasm,wasm_peak_bytes:raw.wasm_peak_bytes,contexts:raw.contexts.map(({draw_frames,...r})=>r),context_lost:raw.context_lost,context_restored:raw.context_restored,shader_compiles:raw.shaders.length,shader_cpu_ms:raw.shaders.reduce((n,s)=>n+s.cpu_ms,0),links:raw.links.length,frames:raw.frames.slice(-30),long_tasks:raw.long_tasks.slice(-10)}:null,walk};
 }),30000,'page read');
}
async function check(){
 assert.equal(report.errors.length,0,JSON.stringify(report.errors));
 latest=await read();
 if(report.document_token)assert.equal(latest.document_token,report.document_token,'unexpected full document reload');
 assert.equal(latest.telemetry?.context_lost?.length||0,0,'WebGL context loss');
 if(latest.runtime?.adventure){
  assert(!latest.runtime.camera_locked,'walking route requires ordinary following camera');
  assert(!latest.runtime.dead,'hero died during town route');
  assert(!latest.runtime.paused,'unexpected game pause during route');
  if(priorPosition){walkDistance+=Math.hypot(latest.runtime.player[0]-priorPosition[0],latest.runtime.player[1]-priorPosition[1]);}
  if(priorCamera&&latest.runtime.camera_3d){cameraDistance+=Math.hypot(...latest.runtime.camera_3d.map((v,i)=>v-priorCamera[i]));}
  priorPosition=latest.runtime.player;priorCamera=latest.runtime.camera_3d;
 }
 return latest;
}
async function wait(predicate,label,ms=120000){const end=Date.now()+ms;while(Date.now()<end){const s=await check();if(predicate(s))return s;await page.waitForTimeout(180);}throw Error(label+' timeout '+JSON.stringify(latest));}
async function sample(phase){
 const s=await check();const m=await timeout(cdp.send('Performance.getMetrics'),10000,'performance metrics');
 const row={wall:Date.now(),phase,...s,metrics:Object.fromEntries(m.metrics.filter(m=>['JSHeapUsedSize','JSHeapTotalSize','Nodes','Documents','TaskDuration'].includes(m.name)).map(m=>[m.name,m.value])),walk_distance:walkDistance,camera_distance:cameraDistance};
 report.samples.push(row);await appendFile(path.join(out,'samples.ndjson'),JSON.stringify(row)+'\n');
 console.log('WALK_SAMPLE '+JSON.stringify({phase,wall:row.wall,player:s.runtime?.player,town:s.runtime?.town,frame:s.runtime?.frame,physics:s.runtime?.physics_ticks,monitors:s.runtime?.monitors,metrics:row.metrics,canvases:s.canvases,native_render_size:s.runtime?.native_render_size,native_msaa_3d:s.runtime?.native_msaa_3d,iso_sprite_cache:s.runtime?.iso_sprite_cache,actor_atlases:s.runtime?.actor_atlases,shader_compiles:s.telemetry?.shader_compiles,shader_cpu_ms:s.telemetry?.shader_cpu_ms,links:s.telemetry?.links,wasm:s.telemetry?.wasm,buffers:s.walk?.buffers,gl:s.telemetry?.contexts,walk_distance:walkDistance,camera_distance:cameraDistance}));
 return row;
}
async function holdIdle(phase,ms){const end=Date.now()+ms;while(Date.now()<end){await sample(phase);await page.waitForTimeout(900);}}
async function entry(key){const s=await wait(s=>s.entry?.[key],'entry '+key);await page.mouse.click(s.entry[key][0]*s.size[0],s.entry[key][1]*s.size[1]);}
function inside(p,polygon){let yes=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])yes=!yes;}return yes;}
const directions=[['w',0,-1],['w+d',.707,-.707],['d',1,0],['s+d',.707,.707],['s',0,1],['s+a',-.707,.707],['a',-1,0],['w+a',-.707,-.707]];
function choose(r,index){
 const polygon=r.town_polygon,centroid=polygon.reduce((p,q)=>[p[0]+q[0]/polygon.length,p[1]+q[1]/polygon.length],[0,0]);
 const choices=directions.map((d,i)=>({d,i,p:[r.player[0]+d[1]*80,r.player[1]+d[2]*80]})).filter(c=>inside(c.p,polygon));
 if(!r.town)return choices.sort((a,b)=>Math.hypot(a.p[0]-centroid[0],a.p[1]-centroid[1])-Math.hypot(b.p[0]-centroid[0],b.p[1]-centroid[1]))[0]?.d||directions[index%8];
 return choices.find(c=>c.i===index%8)?.d||choices[index%Math.max(1,choices.length)]?.d||directions[index%8];
}
async function beginMove(d,s){
 if(input==='keys'){for(const key of d[0].split('+'))await page.keyboard.down(key);return;}
 const touch=s.runtime.touch_stick,scale=s.size[0]/s.runtime.viewport[0],x=touch.center[0]*scale,y=touch.center[1]*scale,r=touch.radius*scale*.85;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:7,x,y}]});touchActive=true;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:7,x:x+d[1]*r,y:y+d[2]*r}]});
}
async function endMove(){if(input==='keys'){for(const key of ['w','a','s','d'])await page.keyboard.up(key);}else if(touchActive){await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});touchActive=false;}}
async function resizeFold(width,height,label){
 await endMove();const before=await check(),ticks=before.runtime.physics_ticks;
 await page.setViewportSize({width,height});
 const after=await wait(s=>s.size[0]===width&&s.size[1]===height&&s.runtime?.physics_ticks>ticks&&Math.abs(s.runtime.viewport[0]/s.runtime.viewport[1]-width/height)<.02&&Math.abs(s.runtime.native_render_size[0]/s.runtime.native_render_size[1]-width/height)<.02,'actual fold resize '+label,45000);
 const entry={wall:Date.now(),label,from:before.size,to:after.size,before_canvases:before.canvases,after_canvases:after.canvases,native_size:after.runtime.native_render_size,physics_ticks:after.runtime.physics_ticks};
 (report.resizes??=[]).push(entry);await appendFile(path.join(out,'resizes.ndjson'),JSON.stringify(entry)+'\n');await sample('resize-'+label);console.log('WALK_FOLD_RESIZE '+JSON.stringify(entry));
}
async function capture(name){try{await page.screenshot({path:path.join(out,name+'.jpg'),type:'jpeg',quality:76,timeout:20000});}catch(e){report.capture_error=String(e);}}
try{
 server=await chromium.launchServer({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
 browser=await chromium.connect(server.wsEndpoint());browser.on('disconnected',()=>{if(!closing)void event('browser-disconnected');});
 context=await browser.newContext({viewport:{width:profile.width,height:profile.height},deviceScaleFactor:profile.dpr,hasTouch:true,userAgent:'Mozilla/5.0 (Linux; Android 16; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36'});
 await context.addInitScript(installResourceTelemetry);await context.addInitScript(installWalkingTelemetry);
 await context.addInitScript(()=>{Object.defineProperty(navigator,'standalone',{configurable:true,get:()=>true});window.__sjrpgWalkingDocumentToken=crypto.randomUUID();const media=window.matchMedia.bind(window);window.matchMedia=query=>{const real=media(query);if(query!=='(display-mode: fullscreen)')return real;return new Proxy(real,{get(target,key){if(key==='matches')return true;const value=Reflect.get(target,key,target);return typeof value==='function'?value.bind(target):value;}});};});
 await context.tracing.start({screenshots:false,snapshots:false,sources:false});
 page=await context.newPage();page.on('pageerror',e=>void event('pageerror',String(e)));page.on('crash',()=>void event('page-crash'));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))void event('console',m.text());});
 page.on('close',()=>{if(!closing)void event('page-closed');});
 page.on('framenavigated',frame=>{if(frame===page.mainFrame())void appendFile(path.join(out,'navigations.ndjson'),JSON.stringify({wall:Date.now(),url:frame.url()})+'\n');});
 cdp=await context.newCDPSession(page);await cdp.send('Performance.enable');await cdp.send('Log.enable');
 cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error')void event('browser-log',entry.text);});
 monitor=setInterval(()=>void osSample().catch(e=>{report.os_error=String(e);}),5000);monitor.unref();await osSample();
 const url=new URL(base);url.searchParams.set('walking_profile','1');url.searchParams.set('quality',quality==='low'?'low':'high');
 // No at/preview/zoom fixture: ordinary spawn and following camera are required.
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await wait(s=>s.title&&!s.ready,'normal title');report.document_token=(await read()).document_token;
 await page.locator('#entry-start').click();await wait(s=>s.entry?.stage==='class'||s.entry?.stage==='slots','normal selection');
 let selection=await read();
 if(selection.entry.stage==='slots'){
  const empty=selection.entry.slots_state?.find(s=>!s.occupied);
  const saved=selection.entry.slots_state?.find(s=>s.valid&&s.class===hero);
  const target=empty||saved;assert(target,'a normal empty or matching save slot is required');
  await entry('slot'+target.slot);
  selection=await wait(s=>s.entry?.selected_slot===target.slot&&(s.entry.stage==='class'||s.entry.stage==='slots'),'normal selected slot');
 }
 if(selection.entry.stage==='class'){await entry(hero);await entry('start');}
 else {assert(selection.entry.slots_state?.some(s=>s.slot===selection.entry.selected_slot&&s.valid&&s.class===hero),'Continue must match the requested hero');await entry('continue');}
 await wait(s=>s.ready&&s.runtime?.adventure&&!s.loading?.visible&&!s.runtime.paused,'normal town ready');
 let s=await read();assert.equal(s.runtime.hero_class,hero,'actual selected hero');assert(s.runtime.town,'ordinary spawn must be in town');assert(s.runtime.camera_locked===false,'ordinary camera follows player');
 report.start={player:s.runtime.player,camera:s.runtime.camera_3d,frame:s.runtime.frame,physics_ticks:s.runtime.physics_ticks};await capture('start');await holdIdle('idle-before',15000);
 const begin=Date.now();let index=0,covered=false,unfolded=false;
 while(Date.now()-begin<duration){
  if(variant==='mage-high-touch'&&!covered&&Date.now()-begin>=duration/3){await resizeFold(390,844,'unfolded-to-cover');covered=true;}
  if(variant==='mage-high-touch'&&covered&&!unfolded&&Date.now()-begin>=duration*2/3){await resizeFold(768,1024,'cover-to-unfolded');unfolded=true;}
  s=await check();const d=choose(s.runtime,index++),segment={wall:Date.now(),direction:d[0],origin:s.runtime.player,town:s.runtime.town};report.segments.push(segment);
  await beginMove(d,s);const stop=Date.now()+6000;
  try{do{await sample('walking-'+d[0]);if(!latest.runtime?.town)break;await page.waitForTimeout(750);}while(Date.now()<stop&&Date.now()-begin<duration);}finally{await endMove();}
  segment.end=(await check()).runtime.player;segment.distance=Math.hypot(segment.end[0]-segment.origin[0],segment.end[1]-segment.origin[1]);await appendFile(path.join(out,'segments.ndjson'),JSON.stringify(segment)+'\n');
 }
 await endMove();await holdIdle('idle-after',15000);await capture('end');await osSample();
 s=await check();report.end={player:s.runtime.player,camera:s.runtime.camera_3d,frame:s.runtime.frame,physics_ticks:s.runtime.physics_ticks};
 if(variant==='mage-high-touch'){assert(covered&&unfolded&&report.resizes?.length===2,'both real fold resize directions must complete');}
 assert(walkDistance>=120,'route must contain real sustained movement, actual path='+walkDistance);
 assert(cameraDistance>=.25,'following camera must actually move, path='+cameraDistance);
 assert(report.end.frame-report.start.frame>=20,'actual rendered process frames must advance');
 assert(report.end.physics_ticks>report.start.physics_ticks,'real spatial physics must advance');
 report.walk_distance=walkDistance;report.camera_distance=cameraDistance;report.passed=true;
 console.log('TOWN_WALK_PASS '+JSON.stringify({variant,samples:report.samples.length,walk_distance:walkDistance,camera_distance:cameraDistance,frames:report.end.frame-report.start.frame,physics_ticks:report.end.physics_ticks-report.start.physics_ticks,errors:report.errors.length}));
}catch(e){report.failure=String(e);console.error('TOWN_WALK_FAIL '+JSON.stringify({variant,failure:report.failure,errors:report.errors,last:latest}));try{await endMove();}catch{}await capture('failure').catch(()=>{});process.exitCode=1;}
finally{
 clearInterval(monitor);await osSample().catch(()=>{});
 await writeFile(path.join(out,'proof.json'),JSON.stringify(report,null,2));
 if(context)await context.tracing.stop({path:path.join(out,'trace.zip')}).catch(()=>{});
 closing=true;if(browser)await browser.close().catch(()=>{});if(server)await server.close().catch(()=>{});
}
