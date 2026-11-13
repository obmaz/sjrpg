#!/usr/bin/env node
import {inspectionUrl} from './review/inspection_url.mjs';
// Actual ordinary mage route. No teleport, immortal state, camera lock, forced GC,
// tracing, GL wrappers, or production-source mutations. Pair both editions on one worker.
import assert from 'node:assert/strict';
import {mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium} = createRequire(import.meta.url)('playwright');
const base = inspectionUrl(process.argv[2] || 'http://127.0.0.1:8796/');
const out = path.resolve(process.argv[3] || 'build/frame-pacing');
const target = Math.max(120, Math.min(600, Number(process.env.SJRPG_PACING_FRAMES || 120)));
const deadline = Math.max(60000, Math.min(600000, Number(process.env.SJRPG_PACING_DEADLINE_MS || 300000)));
const variants = (process.env.SJRPG_PACING_PROFILES || 'high-keys,high-touch,low-keys,low-touch').split(',');
const report = {edition:process.env.SJRPG_PACING_EDITION || 'actual', source_sha:process.env.SJRPG_PACING_SHA || null,
  profile:{css_width:360,css_height:780,dpr:3,hero:'mage'}, target_intervals:target, deadline_ms:deadline,
  limitations:[
    'Chromium SwiftShader is CPU software rendering on a shared CI host. These are paired relative route measurements, never Galaxy S26 FPS or mobile driver certification.',
    'Native intervals are RenderingServer.frame_post_draw CPU submission boundaries from OS microseconds, not a GPU fence or physical display presentation.',
    'Godot process/physics/render/memory counters are engine latest-reported monitors; zeros may mean an unsupported monitor.',
    'The identical small read-only observer publishes progress each native submission. No forced GC, GL wrapping, tracing, cache clearing, HP edits, spawn edits, teleportation or camera changes.',
    'Same relative plaza waypoints are followed by real controls. Stop is frame-bounded, so faster/slower editions may finish at different points of this short repeated route.'
  ], profiles:[], passed:false};
await mkdir(out,{recursive:true});
let browser,context,page,cdp,closing=false,activeKeys=new Set(),touch=false;
const percentile=(values,p)=>{const a=values.filter(Number.isFinite).sort((a,b)=>a-b);return a.length?a[Math.min(a.length-1,Math.max(0,Math.ceil(a.length*p)-1))]:null;};
const summary=values=>{const a=values.filter(Number.isFinite);return {count:a.length,p50:percentile(a,.50),p95:percentile(a,.95),p99:percentile(a,.99),max:a.length?Math.max(...a):null,mean:a.length?a.reduce((n,v)=>n+v,0)/a.length:null};};
async function bounded(promise,label,ms=45000){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' protocol deadline')),ms);})]);}finally{clearTimeout(timer);}}
async function read(){return bounded(page.evaluate(()=>({runtime:window.__sjrpgPacingProgress,entry:window.__sjrpgClassButtons,title:window.__sjrpgTitleReady,ready:window.__sjrpgAdventureReady,loading:window.__sjrpgEntryLoading,size:[innerWidth,innerHeight],dpr:devicePixelRatio,visibility:document.visibilityState,token:window.__sjrpgPacingDocument,errors:window.__sjrpgPacingBrowser?.errors||[]})),'observer read');}
let current,latest;
async function check(){const s=await read();latest=s;assert.equal(current.errors.length,0,JSON.stringify(current.errors));assert.equal(s.errors.length,0,JSON.stringify(s.errors));assert.deepEqual(s.size,[360,780],'exact mobile CSS viewport');assert.equal(s.dpr,3);if(current.document_token)assert.equal(s.token,current.document_token,'unexpected reload');if(s.runtime?.native_ready){assert(!s.runtime.paused,'unexpected pause');assert(!s.runtime.dead,'ordinary hero died');assert(!s.runtime.camera_locked,'ordinary following camera required');assert(s.runtime.town&&!s.runtime.dungeon,'route must remain inside real town');}return s;}
async function wait(predicate,label,ms=180000){const until=Date.now()+ms;while(Date.now()<until){const s=await check();if(predicate(s))return s;await page.waitForTimeout(100);}throw Error(label+' deadline '+JSON.stringify(latest));}
async function entry(key){const s=await wait(s=>s.entry?.[key],'entry '+key);await page.mouse.click(s.entry[key][0]*s.size[0],s.entry[key][1]*s.size[1]);}
async function release(){if(page)for(const key of activeKeys)await page.keyboard.up(key);activeKeys.clear();if(touch&&cdp){await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});touch=false;}}
async function move(input,d,state){
 if(input==='keys'){
  const keys=new Set();if(d[0]<-.12)keys.add('a');if(d[0]>.12)keys.add('d');if(d[1]<-.12)keys.add('w');if(d[1]>.12)keys.add('s');
  for(const key of activeKeys)if(!keys.has(key))await page.keyboard.up(key);
  for(const key of keys)if(!activeKeys.has(key))await page.keyboard.down(key);
  activeKeys=keys;return;
 }
 const sx=360/state.viewport[0],sy=780/state.viewport[1],stick=state.stick;
 const x=stick.center[0]*sx,y=stick.center[1]*sy,r=stick.radius*Math.min(sx,sy)*.85;
 if(!touch){await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x,y}]});touch=true;}
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x:x+d[0]*r,y:y+d[1]*r}]});
}
async function capture(file){try{const r=await bounded(cdp.send('Page.captureScreenshot',{format:'jpeg',quality:72,fromSurface:true,captureBeyondViewport:false}),'screenshot',30000);await writeFile(path.join(out,file),Buffer.from(r.data,'base64'));}catch(error){current.capture_errors.push(String(error));}}
async function cpuMetrics(){const m=await bounded(cdp.send('Performance.getMetrics'),'CDP metrics');return Object.fromEntries(m.metrics.filter(m=>['JSHeapUsedSize','JSHeapTotalSize','Nodes','Documents','TaskDuration','ScriptDuration'].includes(m.name)).map(m=>[m.name,m.value]));}
try {
 for(const variant of variants){
  const [quality,input]=variant.split('-');assert(['high','low'].includes(quality)&&['keys','touch'].includes(input),'valid quality/input variant');
  current={variant,quality,input,passed:false,errors:[],capture_errors:[],segments:[]};report.profiles.push(current);
  browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
  browser.on('disconnected',()=>{if(!closing)current.errors.push({type:'browser-disconnected'});});
  context=await browser.newContext({viewport:{width:360,height:780},deviceScaleFactor:3,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (Linux; Android 16; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36'});
  await context.addInitScript(()=>{
   window.__sjrpgPacingDocument=crypto.randomUUID();
   const s={frames:[],long_tasks:[],errors:[]};window.__sjrpgPacingBrowser=s;let last=0;
   function frame(now){if(window.__sjrpgPacingBrowserRecording){if(last)s.frames.push({at:now,ms:now-last});if(s.frames.length>4096)s.frames.shift();last=now;}else last=0;requestAnimationFrame(frame);}requestAnimationFrame(frame);
   try{new PerformanceObserver(list=>{if(window.__sjrpgPacingBrowserRecording)for(const e of list.getEntries())s.long_tasks.push({at:e.startTime,ms:e.duration});}).observe({entryTypes:['longtask']});}catch{}
   document.addEventListener('webglcontextlost',e=>s.errors.push({type:'webglcontextlost',at:performance.now(),status:e.statusMessage}),true);
  });
  page=await context.newPage();closing=false;
  page.on('pageerror',e=>current.errors.push({type:'pageerror',message:String(e)}));page.on('crash',()=>current.errors.push({type:'page-crash'}));
  page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))current.errors.push({type:'console',message:m.text()});});
  cdp=await context.newCDPSession(page);await cdp.send('Performance.enable');
  const url=inspectionUrl(base);url.searchParams.set('frame_pacing_profile','1');url.searchParams.set('quality',quality);
  await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:180000});
  await wait(s=>s.title&&!s.ready&&s.runtime,'ordinary title');current.document_token=(await read()).token;
  await page.locator('#entry-start').click();let selected=await wait(s=>s.entry?.stage==='class'||s.entry?.stage==='slots','ordinary character/slot screen');
  if(selected.entry.stage==='slots'){
   const slot=selected.entry.slots_state?.find(x=>!x.occupied);assert(slot,'fresh disposable context must offer a normal empty slot');await entry('slot'+slot.slot);
   selected=await wait(s=>s.entry?.selected_slot===slot.slot&&s.entry?.stage==='class','normal empty slot');
  }
  await entry('mage');await entry('start');
  let s=await wait(s=>s.ready&&s.runtime?.native_ready&&!s.loading?.visible,'ordinary town ready');
  assert.equal(s.runtime.hero,'mage');assert.equal(s.runtime.quality_low,quality==='low','actual selected quality');
  const warmStart=s.runtime.draw_seq;await wait(s=>s.runtime.draw_seq-warmStart>=16,'16 actual warm-up native submissions');
  s=await check();current.start=s.runtime;current.cdp_before=await cpuMetrics();await capture(variant+'-start.jpg');
  await bounded(page.evaluate(()=>{window.__sjrpgPacingBrowserRecording=true;window.__sjrpgPacingCommand('begin');}),'begin native sample');
  const origin=s.runtime.player,waypoints=[[-150,0],[-150,120],[0,120],[0,0]].map(p=>[origin[0]+p[0],origin[1]+p[1]]);
  current.route={origin,waypoints,reach_tolerance_world_px:32,policy:'repeat the same open plaza rectangle by real input, no teleportation'};
  const until=Date.now()+deadline;let point=0,priorDirection='';
  while(true){
   s=await check();if(s.runtime.recorded>=target+1)break;
   assert(Date.now()<until,'strict '+target+' native interval target before wall deadline; actual rows='+s.runtime.recorded);
   assert(!s.runtime.overflow,'native sample buffer overflow');
   let dx=waypoints[point][0]-s.runtime.player[0],dy=waypoints[point][1]-s.runtime.player[1],distance=Math.hypot(dx,dy);
   if(distance<=32){point=(point+1)%waypoints.length;dx=waypoints[point][0]-s.runtime.player[0];dy=waypoints[point][1]-s.runtime.player[1];distance=Math.hypot(dx,dy);}
   const direction=[dx/Math.max(distance,1),dy/Math.max(distance,1)],key=point+':'+Math.sign(dx)+':'+Math.sign(dy);
   if(key!==priorDirection){current.segments.push({point,player:s.runtime.player,draw_seq:s.runtime.draw_seq});priorDirection=key;}
   await move(input,direction,s.runtime);await page.waitForTimeout(75);
  }
  const stopped=await bounded(page.evaluate(()=>{window.__sjrpgPacingCommand('stop');window.__sjrpgPacingBrowserRecording=false;return {native:window.__sjrpgPacingResult,browser:window.__sjrpgPacingBrowser,visibility:document.visibilityState};}),'stop native sample');
  await release();current.end=stopped.native.state;current.cdp_after=await cpuMetrics();
  const columns=stopped.native.columns,rows=stopped.native.samples,col=name=>{const i=columns.indexOf(name);assert(i>=0,'native column '+name);return rows.map(r=>r[i]);};
  const intervals=col('interval_ms').filter(v=>v>0),xs=col('player_x'),ys=col('player_y'),cx=col('camera_x'),cy=col('camera_y'),cz=col('camera_z');
  let walk=0,camera=0,moving=0,withInput=0;
  for(let i=1;i<rows.length;i++){const d=Math.hypot(xs[i]-xs[i-1],ys[i]-ys[i-1]);walk+=d;camera+=Math.hypot(cx[i]-cx[i-1],cy[i]-cy[i-1],cz[i]-cz[i-1]);if(d>.1)moving++;}
  const ix=col('input_x'),iy=col('input_y');for(let i=0;i<rows.length;i++)if(Math.hypot(ix[i],iy[i])>.1)withInput++;
  current.native={columns,samples:rows,monitor_semantics:stopped.native.monitor_semantics};current.browser=stopped.browser;
  current.summary={native_interval_ms:summary(intervals),browser_raf_ms:summary(stopped.browser.frames.map(f=>f.ms)),process_ms:summary(col('process_ms')),physics_ms:summary(col('physics_ms')),draw_calls:summary(col('draw_calls')),triangles:summary(col('triangles')),render_objects:summary(col('render_objects')),objects:summary(col('objects')),resources:summary(col('resources')),nodes:summary(col('nodes')),static_bytes:summary(col('static_bytes')),video_bytes:summary(col('video_bytes')),texture_bytes:summary(col('texture_bytes')),buffer_bytes:summary(col('buffer_bytes')),walk_distance_world_px:walk,camera_path_metres:camera,moving_rendered_frames:moving,input_rendered_frames:withInput,actual_native_intervals:intervals.length,engine_rendered_delta:current.end.frames_drawn-current.start.frames_drawn,physics_tick_delta:current.end.physics_ticks-current.start.physics_ticks,long_tasks:summary(stopped.browser.long_tasks.map(t=>t.ms))};
  assert(intervals.length>=target,'at least '+target+' native submission intervals');
  assert(current.summary.engine_rendered_delta>=target,'engine actual frames_drawn advances');
  assert(walk>=150&&moving>=24,'real sustained walking, not an idle timer');
  assert(withInput>=Math.floor(rows.length*.6),'actual native movement input during most samples');
  assert(camera>=.5,'ordinary following camera must actually move');
  assert(current.summary.physics_tick_delta>0,'actual spatial physics must advance');
  assert(stopped.visibility==='visible','measured page stays visible');
  assert.equal(current.errors.length,0);assert.equal(stopped.browser.errors.length,0);
  current.passed=true;console.log('FRAME_PACING_PROFILE '+JSON.stringify({edition:report.edition,variant,source_sha:report.source_sha,start:current.start,end:current.end,summary:current.summary}));
  await capture(variant+'-end.jpg');await writeFile(path.join(out,variant+'.json'),JSON.stringify(current,null,2));
  closing=true;await context.close();await browser.close();context=null;browser=null;page=null;cdp=null;
 }
 report.passed=report.profiles.every(p=>p.passed);console.log('FRAME_PACING_PASS '+JSON.stringify({edition:report.edition,source_sha:report.source_sha,profiles:report.profiles.length,minimum_intervals:target}));
}catch(error){report.failure=String(error);if(current){current.failure=String(error);current.last=latest;}console.error('FRAME_PACING_FAIL '+JSON.stringify({edition:report.edition,error:String(error),last:latest,errors:current?.errors}));process.exitCode=1;try{await release();}catch{}}
finally{closing=true;await writeFile(path.join(out,'proof.json'),JSON.stringify(report,null,2));if(context)await context.close().catch(()=>{});if(browser)await browser.close().catch(()=>{});}
