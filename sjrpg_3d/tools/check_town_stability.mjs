#!/usr/bin/env node
import {inspectionUrl} from './review/inspection_url.mjs';
// Real uninterrupted town movement. No spawn fixtures, teleportation, HP edits or forced GC during normal resource gates.
import assert from 'node:assert/strict';
import {mkdir,writeFile,appendFile,readFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {installResourceTelemetry,installWalkingTelemetry} from './stability_telemetry.mjs';
import {installCanvasAllocationTelemetry} from './canvas_allocation_telemetry.mjs';
import {insideTown as inside,townDirections as directions,chooseTownDirection as choose} from './town_stability_route.mjs';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=inspectionUrl(process.argv[2]||'http://127.0.0.1:8792/'),out=path.resolve(process.argv[3]||'build/town-walk');
const fold=process.env.SJRPG_STABILITY_PROFILE==='fold';
const idleMode=process.env.SJRPG_STABILITY_MODE==='idle';
const variant=fold?'mage-high-touch':'mage-low-keys';
const [hero,quality,input]=variant.split('-');
const profile=fold?{width:768,height:1024,dpr:3}:{width:270,height:480,dpr:1};
const duration=fold?240000:720000,targetFrames=fold?60:1200,minWalkMilliseconds=90000;
const processSamples=[];
await mkdir(out,{recursive:true});
const report={edition:process.env.SJRPG_WALK_EDITION||'actual',profile,stability_mode:idleMode?'idle':'walk',actual_input_after_entry:idleMode?'none':input,diagnostic_kind:'constant-cost buffer counters, actual drawn frames, no forced GC during gameplay',target_drawn_frames:targetFrames,harness_sha:process.env.SJRPG_HARNESS_SHA,source_sha:process.env.SJRPG_WALK_SHA||null,variant,hero,quality,input,duration,passed:false,errors:[],samples:[],segments:[],limitations:['Chromium SwiftShader is a software-rendered CI route, not physical mobile FPS or driver memory certification.','Standalone/fullscreen display-mode is emulated at the requested fold viewport; this is not an installation or OS process-kill certification.','WebGL allocation counters are API storage estimates; Godot counters, Chrome RSS and PSS are reported separately.','Sum RSS double counts shared pages; aggregate PSS is reported when procfs permits.','Uninterrupted normal town gameplay can continue normal spawning, animation and autosave; no HP/gameplay-clock edits.']};
let browser,server,context,page,cdp,closing=false,monitor,rssBusy=false,touchActive=false;
let latestProcessMemory=null;
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
  const sample={wall:Date.now(),drawn_frame:latest?.runtime?.drawn_frame??null,process_frame:latest?.runtime?.frame??null,root_pid:root,processes,rss_sum_bytes:processes.reduce((n,p)=>n+p.rss_bytes,0),pss_sum_bytes:processes.every(p=>p.pss_bytes!==null)?processes.reduce((n,p)=>n+p.pss_bytes,0):null,node_recorder_rss:process.memoryUsage().rss};
  latestProcessMemory=sample;processSamples.push(sample);if(sample.pss_sum_bytes>6*1024**3)report.resource_budget_exceeded={kind:'Chrome PSS exceeds 6GiB diagnostic safeguard',sample};
  await appendFile(path.join(out,'process-memory.ndjson'),JSON.stringify(sample)+'\n');
  console.log('WALK_PROCESS_MEMORY '+JSON.stringify({wall:sample.wall,rss_sum_bytes:sample.rss_sum_bytes,pss_sum_bytes:sample.pss_sum_bytes,processes:processes.map(p=>({pid:p.pid,role:p.role,rss_bytes:p.rss_bytes,pss_bytes:p.pss_bytes}))}));
 }finally{rssBusy=false;}
}
async function timeout(promise,ms,label){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' protocol stall '+ms+'ms')),ms);})]);}finally{clearTimeout(timer);}}
async function read(){
 return timeout(page.evaluate(()=>{
  const raw=window.__sjrpgResourceRead?.(),walk=window.__sjrpgWalkingRead?.();
  return {runtime:window.__sjrpgResourceProfile,entry:window.__sjrpgClassButtons,title:window.__sjrpgTitleReady,ready:window.__sjrpgAdventureReady,loading:window.__sjrpgEntryLoading,size:[innerWidth,innerHeight],dpr:devicePixelRatio,visibility:document.visibilityState,standalone:navigator.standalone===true,fullscreen:window.SjrpgFullscreen?.state?.(),document_token:window.__sjrpgWalkingDocumentToken,canvases:[...document.querySelectorAll('canvas')].map(c=>({id:c.id,width:c.width,height:c.height,css_width:c.getBoundingClientRect().width,css_height:c.getBoundingClientRect().height})),user_agent:navigator.userAgent,telemetry:raw?{at:raw.at,wasm:raw.wasm,wasm_peak_bytes:raw.wasm_peak_bytes,contexts:raw.contexts.map(({draw_frames,...r})=>r),context_lost:raw.context_lost,context_restored:raw.context_restored,shader_compiles:raw.shaders.length,shader_cpu_ms:raw.shaders.reduce((n,s)=>n+s.cpu_ms,0),links:raw.links.length,frames:raw.frames.slice(-30),long_tasks:raw.long_tasks.slice(-10)}:null,walk,audio_allocation:window.__sjrpgAudioAllocation?{...window.__sjrpgAudioAllocation,last_buffer:window.__sjrpgAudioAllocation.last_buffer?{...window.__sjrpgAudioAllocation.last_buffer}:null}:null,canvas_allocation:{probe:window.__sjrpgCanvasAllocationProbe,snapshot:window.__sjrpgCanvasAllocationSnapshot?.()}};
 }),30000,'page read');
}
async function check(){
 assert.equal(report.errors.length,0,JSON.stringify(report.errors));
 assert(!report.resource_budget_exceeded,JSON.stringify(report.resource_budget_exceeded));
 latest=await read();
 if(report.document_token)assert.equal(latest.document_token,report.document_token,'unexpected full document reload');
 assert.equal(latest.telemetry?.context_lost?.length||0,0,'WebGL context loss');
 if(latest.runtime?.adventure){
  assert(!latest.runtime.camera_locked,'walking route requires ordinary following camera');
  assert(!latest.runtime.dead,'hero died during town route');
  assert(!latest.runtime.paused,'unexpected game pause during route');if(report.phase_drawn_start!==undefined)assert(latest.runtime.town,'town route escaped the real safe polygon');
  if(priorPosition){walkDistance+=Math.hypot(latest.runtime.player[0]-priorPosition[0],latest.runtime.player[1]-priorPosition[1]);}
  if(priorCamera&&latest.runtime.camera_3d){cameraDistance+=Math.hypot(...latest.runtime.camera_3d.map((v,i)=>v-priorCamera[i]));}
  priorPosition=latest.runtime.player;priorCamera=latest.runtime.camera_3d;
 }
 return latest;
}
async function wait(predicate,label,ms=120000){const end=Date.now()+ms;while(Date.now()<end){const s=await check();if(predicate(s))return s;await page.waitForTimeout(180);}throw Error(label+' timeout '+JSON.stringify(latest));}
async function sample(phase){
 const s=await check();const m=await timeout(cdp.send('Performance.getMetrics'),10000,'performance metrics');
 const row={wall:Date.now(),phase,...s,process_memory:latestProcessMemory?{wall:latestProcessMemory.wall,drawn_frame:latestProcessMemory.drawn_frame,pss_sum_bytes:latestProcessMemory.pss_sum_bytes,rss_sum_bytes:latestProcessMemory.rss_sum_bytes}:null,metrics:Object.fromEntries(m.metrics.filter(m=>['JSHeapUsedSize','JSHeapTotalSize','Nodes','Documents','TaskDuration'].includes(m.name)).map(m=>[m.name,m.value])),walk_distance:walkDistance,camera_distance:cameraDistance};
 report.samples.push(row);await appendFile(path.join(out,'samples.ndjson'),JSON.stringify(row)+'\n');
 console.log('WALK_SAMPLE '+JSON.stringify({phase,wall:row.wall,player:s.runtime?.player,town:s.runtime?.town,frame:s.runtime?.frame,physics:s.runtime?.physics_ticks,drawn_frame:s.runtime?.drawn_frame,monitors:s.runtime?.monitors,metrics:row.metrics,canvases:s.canvases,native_render_size:s.runtime?.native_render_size,native_msaa_3d:s.runtime?.native_msaa_3d,iso_sprite_cache:s.runtime?.iso_sprite_cache,actor_atlases:s.runtime?.actor_atlases,shader_compiles:s.telemetry?.shader_compiles,shader_cpu_ms:s.telemetry?.shader_cpu_ms,links:s.telemetry?.links,wasm:s.telemetry?.wasm,buffers:s.walk?.buffers,gl:s.telemetry?.contexts,audio_allocation:s.audio_allocation,walk_distance:walkDistance,camera_distance:cameraDistance}));
 return row;
}
async function holdIdle(phase,ms){const end=Date.now()+ms;while(Date.now()<end){await sample(phase);await page.waitForTimeout(900);}}
async function entry(key){const s=await wait(s=>s.entry?.[key],'entry '+key);await page.mouse.click(s.entry[key][0]*s.size[0],s.entry[key][1]*s.size[1]);}

async function beginMove(d,s){
 if(input==='keys'){for(const key of d[0].split('+'))await page.keyboard.down(key);return;}
 const touch=s.runtime.touch_stick,scale=s.size[0]/s.runtime.viewport[0],x=touch.center[0]*scale,y=touch.center[1]*scale,r=touch.radius*scale*.85;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:7,x,y}]});touchActive=true;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:7,x:x+d[1]*r,y:y+d[2]*r}]});
}
async function endMove(){if(idleMode)return;if(input==='keys'){for(const key of ['w','a','s','d'])await page.keyboard.up(key);}else if(touchActive){await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});touchActive=false;}}
async function resizeFold(width,height,label){
 await endMove();const before=await check(),ticks=before.runtime.physics_ticks;
 await page.setViewportSize({width,height});
 const after=await wait(s=>s.size[0]===width&&s.size[1]===height&&s.runtime?.physics_ticks>ticks&&Math.abs(s.runtime.viewport[0]/s.runtime.viewport[1]-width/height)<.02&&Math.abs(s.runtime.native_render_size[0]/s.runtime.native_render_size[1]-width/height)<.02,'actual fold resize '+label,45000);
 const entry={wall:Date.now(),label,from:before.size,to:after.size,before_canvases:before.canvases,after_canvases:after.canvases,native_size:after.runtime.native_render_size,physics_ticks:after.runtime.physics_ticks};
 (report.resizes??=[]).push(entry);await appendFile(path.join(out,'resizes.ndjson'),JSON.stringify(entry)+'\n');await sample('resize-'+label);console.log('WALK_FOLD_RESIZE '+JSON.stringify(entry));
}
async function capture(name){try{
 const result=await timeout(cdp.send('Page.captureScreenshot',{format:'jpeg',quality:72,fromSurface:true,captureBeyondViewport:false}),60000,'compositor capture '+name);
 const data=Buffer.from(result.data,'base64');await writeFile(path.join(out,name+'.jpg'),data);
 (report.captures??=[]).push({name,bytes:data.length});console.log('STABILITY_IMAGE_BEGIN '+JSON.stringify({name:report.edition+'-'+(fold?'fold':'low')+'-'+name,mime:'image/jpeg',base64_length:result.data.length}));
 for(let i=0;i<result.data.length;i+=16384)console.log('STABILITY_IMAGE_CHUNK '+report.edition+'-'+(fold?'fold':'low')+'-'+name+' '+result.data.slice(i,i+16384));
 console.log('STABILITY_IMAGE_END '+report.edition+'-'+(fold?'fold':'low')+'-'+name);
}catch(e){(report.capture_errors??=[]).push({name,error:String(e)});console.error('STABILITY_CAPTURE_FAIL '+JSON.stringify({name,error:String(e)}));}}

function median(values){const a=values.filter(Number.isFinite).sort((x,y)=>x-y);assert(a.length>0,'median requires actual samples');return a[Math.floor(a.length/2)];}
function assessPlateau(){
 const start=report.phase_drawn_start,warm=start+400,end=start+report.actual_sustained_drawn_frames;
 const rows=report.samples.filter(s=>(s.phase.startsWith('walking-')||s.phase==='standing-idle')&&s.runtime.drawn_frame>=warm&&s.runtime.drawn_frame<=end);
 const windowFrames=Math.max(200,Math.floor((end-warm)/3));
 const first=rows.filter(s=>s.runtime.drawn_frame<warm+windowFrames),last=rows.filter(s=>s.runtime.drawn_frame>=end-windowFrames);
 assert(first.length>=3&&last.length>=3,'late resource windows need at least three actual samples each');
 const changes={},limits={texture_bytes:16*1024**2,buffer_bytes:8*1024**2,resources:128,objects:1024};
 const enemiesFirst=median(first.map(s=>s.runtime.enemies)),enemiesLast=median(last.map(s=>s.runtime.enemies)),newEnemies=Math.max(0,enemiesLast-enemiesFirst);
 limits.resources+=newEnemies*32;limits.objects+=newEnemies*256;
 const checks=[];
 for(const key of Object.keys(limits)){const before=median(first.map(s=>s.runtime.monitors[key])),after=median(last.map(s=>s.runtime.monitors[key]));changes[key]={before,after,growth:after-before,limit:limits[key]};checks.push(after-before<=limits[key]);}
 const nodesBefore=median(first.map(s=>s.runtime.nodes)),nodesAfter=median(last.map(s=>s.runtime.nodes)),nodeLimit=256+newEnemies*128;
 changes.nodes={before:nodesBefore,after:nodesAfter,growth:nodesAfter-nodesBefore,limit:nodeLimit};checks.push(nodesAfter-nodesBefore<=nodeLimit);
 const heapBefore=median(first.map(s=>s.metrics.JSHeapUsedSize)),heapAfter=median(last.map(s=>s.metrics.JSHeapUsedSize));
 changes.js_heap={before:heapBefore,after:heapAfter,growth:heapAfter-heapBefore,limit:32*1024**2};checks.push(heapAfter-heapBefore<=32*1024**2);
 const ps=processSamples.filter(s=>Number.isFinite(s.pss_sum_bytes)&&s.drawn_frame>=warm&&s.drawn_frame<=end);
 const pa=ps.filter(s=>s.drawn_frame<warm+windowFrames),pb=ps.filter(s=>s.drawn_frame>=end-windowFrames);
 assert(pa.length>=3&&pb.length>=3,'OS PSS windows need at least three real process samples each');
 const pssBefore=median(pa.map(s=>s.pss_sum_bytes)),pssAfter=median(pb.map(s=>s.pss_sum_bytes));
 changes.chrome_pss={before:pssBefore,after:pssAfter,growth:pssAfter-pssBefore,limit:128*1024**2};checks.push(pssAfter-pssBefore<=128*1024**2);
 const wasmBefore=median(first.map(s=>s.telemetry.wasm?.bytes)),wasmAfter=median(last.map(s=>s.telemetry.wasm?.bytes));assert(wasmBefore>0&&wasmAfter>0,'actual nonzero WASM capacity must be observed');
 changes.wasm_capacity={before:wasmBefore,after:wasmAfter,growth:wasmAfter-wasmBefore,limit:16*1024**2};checks.push(wasmAfter-wasmBefore<=16*1024**2);
 report.plateau={passed:checks.every(Boolean),window_frames:[warm,warm+windowFrames,end-windowFrames,end],sample_counts:[first.length,last.length,pa.length,pb.length],new_enemies:newEnemies,changes,limitations:'Diagnostic resource regression budgets after 400 warmup frames; Chrome software-driver PSS is not physical mobile RAM. No GC forced in either window.'};
 console.log('STABILITY_PLATEAU '+JSON.stringify(report.plateau));assert(report.plateau.passed,'late resource windows exceeded a declared growth budget');
}

try{
 server=await chromium.launchServer({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
 browser=await chromium.connect(server.wsEndpoint());browser.on('disconnected',()=>{if(!closing)void event('browser-disconnected');});
 context=await browser.newContext({viewport:{width:profile.width,height:profile.height},deviceScaleFactor:profile.dpr,hasTouch:true,userAgent:'Mozilla/5.0 (Linux; Android 16; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36'});
 await context.addInitScript(installCanvasAllocationTelemetry);await context.addInitScript(installResourceTelemetry);await context.addInitScript(installWalkingTelemetry);
 await context.addInitScript(()=>{Object.defineProperty(navigator,'standalone',{configurable:true,get:()=>true});window.__sjrpgWalkingDocumentToken=crypto.randomUUID();const media=window.matchMedia.bind(window);window.matchMedia=query=>{const real=media(query);if(query!=='(display-mode: fullscreen)')return real;return new Proxy(real,{get(target,key){if(key==='matches')return true;const value=Reflect.get(target,key,target);return typeof value==='function'?value.bind(target):value;}});};});
 // No tracing or WebGL upload/draw interception during endurance.
 page=await context.newPage();page.on('pageerror',e=>void event('pageerror',String(e)));page.on('crash',()=>void event('page-crash'));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))void event('console',m.text());});
 page.on('close',()=>{if(!closing)void event('page-closed');});
 page.on('framenavigated',frame=>{if(frame===page.mainFrame())void appendFile(path.join(out,'navigations.ndjson'),JSON.stringify({wall:Date.now(),url:frame.url()})+'\n');});
 cdp=await context.newCDPSession(page);await cdp.send('Performance.enable');await cdp.send('Log.enable');
 cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error')void event('browser-log',entry.text);});
 monitor=setInterval(()=>void osSample().catch(e=>{report.os_error=String(e);}),5000);monitor.unref();await osSample();
 const url=inspectionUrl(base);url.searchParams.set('walking_profile','1');url.searchParams.set('quality',quality==='low'?'low':'high');
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
 let s=await read();assert.equal(s.runtime.hero_class,hero,'actual selected hero');assert.equal(s.runtime.quality_low,quality==='low','requested quality must be applied');assert(s.runtime.town,'ordinary spawn must be in town');assert(s.runtime.camera_locked===false,'ordinary camera follows player');
 report.start={player:s.runtime.player,camera:s.runtime.camera_3d,frame:s.runtime.frame,physics_ticks:s.runtime.physics_ticks};await capture('start');await holdIdle('idle-before',15000);
 const begin=Date.now(),drawnStart=latest.runtime.drawn_frame;assert(Number.isFinite(drawnStart),'observer must expose actual Engine.get_frames_drawn');report.phase_drawn_start=drawnStart;report.phase_origin={player:latest.runtime.player,camera:latest.runtime.camera_3d};await page.evaluate(()=>window.__sjrpgCanvasAllocationStart=true);let index=0,covered=false,unfolded=false;
 while((latest.runtime.drawn_frame-drawnStart<targetFrames||Date.now()-begin<minWalkMilliseconds)&&Date.now()-begin<duration){
  if(idleMode){await sample('standing-idle');await page.waitForTimeout(750);continue;}
  if(variant==='mage-high-touch'&&!covered&&Date.now()-begin>=minWalkMilliseconds/3){await resizeFold(390,844,'unfolded-to-cover');covered=true;}
  if(variant==='mage-high-touch'&&covered&&!unfolded&&Date.now()-begin>=minWalkMilliseconds*2/3){await resizeFold(768,1024,'cover-to-unfolded');unfolded=true;}
  s=await check();const d=choose(s.runtime,index++),segment={wall:Date.now(),direction:d[0],origin:s.runtime.player,town:s.runtime.town};report.segments.push(segment);
  await beginMove(d,s);const stop=Date.now()+750;
  try{do{await sample('walking-'+d[0]);if(!latest.runtime?.town)break;await page.waitForTimeout(150);}while(Date.now()<stop&&Date.now()-begin<duration);}finally{await endMove();}
  segment.end=(await check()).runtime.player;segment.distance=Math.hypot(segment.end[0]-segment.origin[0],segment.end[1]-segment.origin[1]);await appendFile(path.join(out,'segments.ndjson'),JSON.stringify(segment)+'\n');
 }
 await endMove();report.actual_sustained_drawn_frames=latest.runtime.drawn_frame-drawnStart;assert(report.actual_sustained_drawn_frames>=targetFrames,'actual drawn-frame target before diagnostic deadline: '+report.actual_sustained_drawn_frames+'/'+targetFrames);await holdIdle('idle-after',15000);await capture('end');await osSample();
 s=await check();report.end={player:s.runtime.player,camera:s.runtime.camera_3d,frame:s.runtime.frame,physics_ticks:s.runtime.physics_ticks};
 if(variant==='mage-high-touch'&&!idleMode){assert(covered&&unfolded&&report.resizes?.length===2,'both real fold resize directions must complete');}
 if(idleMode){const displacement=Math.hypot(s.runtime.player[0]-report.phase_origin.player[0],s.runtime.player[1]-report.phase_origin.player[1]);report.idle_displacement=displacement;assert(displacement<=1,'standing-idle actor must remain at its actual starting position');}
 else assert(walkDistance>=120,'route must contain real sustained movement, actual path='+walkDistance);
 if(!idleMode)assert(cameraDistance>=.25,'following camera must actually move, path='+cameraDistance);
 assert(report.end.frame-report.start.frame>=20,'actual rendered process frames must advance');
 assert(report.end.physics_ticks>report.start.physics_ticks,'real spatial physics must advance');
 report.walk_distance=walkDistance;report.camera_distance=cameraDistance;report.visual_captures_validated=(report.captures||[]).some(c=>c.name==='start')&&(report.captures||[]).some(c=>c.name==='end');assert(s.canvas_allocation?.probe?.status==='complete','20-frame Canvas attribution must disconnect before normal verdict');report.canvas_allocation=s.canvas_allocation;report.audio_allocation=s.audio_allocation;if(!fold)assessPlateau();assert(report.visual_captures_validated,'both compositor screenshots must be preserved');report.passed=true;
 console.log('STABILITY_PASS '+JSON.stringify({variant,stability_mode:report.stability_mode,actual_input_after_entry:report.actual_input_after_entry,actual_sustained_drawn_frames:report.actual_sustained_drawn_frames,audio_allocation:report.audio_allocation,plateau:report.plateau,visual_captures_validated:report.visual_captures_validated,samples:report.samples.length,walk_distance:walkDistance,camera_distance:cameraDistance,frames:report.end.frame-report.start.frame,physics_ticks:report.end.physics_ticks-report.start.physics_ticks,errors:report.errors.length}));
}catch(e){report.failure=String(e);console.error('STABILITY_FAIL '+JSON.stringify({variant,failure:report.failure,errors:report.errors,last:latest}));try{await endMove();}catch{}await capture('failure').catch(()=>{});process.exitCode=1;}
finally{
 clearInterval(monitor);await osSample().catch(()=>{});
 report.process_memory=processSamples;await writeFile(path.join(out,'proof.json'),JSON.stringify(report,null,2));
 if(process.env.SJRPG_FINAL_GC_DIAGNOSTIC==='1'&&cdp&&page&&!page.isClosed()){try{const before=await read();await timeout(cdp.send('HeapProfiler.collectGarbage'),15000,'final diagnostic GC');await osSample();report.final_gc_diagnostic={outside_normal_gates:true,before_runtime:before.runtime,after:await read(),process_memory:latestProcessMemory};console.log('STABILITY_GC_CONTROL '+JSON.stringify({outside_normal_gates:true,normal_passed:report.passed,pss_after:latestProcessMemory?.pss_sum_bytes}));await writeFile(path.join(out,'proof.json'),JSON.stringify(report,null,2));}catch(e){report.final_gc_error=String(e);await writeFile(path.join(out,'proof.json'),JSON.stringify(report,null,2));}}
 
 closing=true;if(browser)await browser.close().catch(()=>{});if(server)await server.close().catch(()=>{});
}
