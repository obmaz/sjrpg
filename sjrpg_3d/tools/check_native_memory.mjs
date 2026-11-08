#!/usr/bin/env node
// Isolated native-allocation diagnostic. Uses an immutable existing export; no game-source overlay.
import assert from 'node:assert/strict';
import {mkdir,writeFile,appendFile,readFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=new URL(process.argv[2]||'http://127.0.0.1:8795/'),out=path.resolve(process.argv[3]||'build/native-memory-profile');
await mkdir(out,{recursive:true});
const report={diagnostic_only:true,source_sha:process.env.SJRPG_NATIVE_APP_SHA||'991d38c6bbba7ddf347721a489f74160909d1133',source_run:42440737243,
 target_pose_updates:160,minimum_observation_ms:15000,deadline_ms:90000,pss_safeguard_bytes:3*1024**3,
 source_kind:'exact previously exported normal app; no GDScript observer or gameplay modification',
 limitation:'Native sampling/memory dumps perturb allocation timing. This is allocation attribution, not an endurance or physical-phone stability pass.',
 errors:[],samples:[],native_sampling:{available:false},memory_trace:{available:false},passed:false};
let browserServer,browser,context,page,cdp,browserCdp,closing=false,traceStarted=false,samplingStarted=false,traceCompletion;
let token,latest=null;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function timeout(p,ms,label){let timer;try{return await Promise.race([p,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' timed out '+ms+'ms')),ms);})]);}finally{clearTimeout(timer);}}
async function save(name,value){await writeFile(path.join(out,name),JSON.stringify(value,null,2));}
async function osMemory(){
 const root=browserServer.process().pid,rows=[];
 for(const name of await readdir('/proc'))if(/^\d+$/.test(name)){try{
  const status=await readFile('/proc/'+name+'/status','utf8'),number=key=>Number(new RegExp('^'+key+':\\s+(\\d+)','m').exec(status)?.[1]||0);
  rows.push({pid:Number(name),ppid:number('PPid'),rss_bytes:number('VmRSS')*1024});
 }catch{}}
 const ids=new Set([root]);let more=true;while(more){more=false;for(const row of rows)if(ids.has(row.ppid)&&!ids.has(row.pid)){ids.add(row.pid);more=true;}}
 const processes=rows.filter(row=>ids.has(row.pid));
 for(const row of processes){try{
  const text=await readFile('/proc/'+row.pid+'/smaps_rollup','utf8');row.pss_bytes=Number(/^Pss:\s+(\d+)/m.exec(text)?.[1]||0)*1024;
  const command=(await readFile('/proc/'+row.pid+'/cmdline','utf8')).split('\0').join(' ');row.role=/--type=([^\s]+)/.exec(command)?.[1]||'browser';
 }catch{row.pss_bytes=null;row.role='exited';}}
 return {processes,pss_bytes:processes.every(p=>p.pss_bytes!==null)?processes.reduce((n,p)=>n+p.pss_bytes,0):null,rss_sum_bytes:processes.reduce((n,p)=>n+p.rss_bytes,0)};
}
async function read(){return timeout(page.evaluate(()=>({
 title:window.__sjrpgTitleReady,entry:window.__sjrpgClassButtons,ready:window.__sjrpgAdventureReady,loading:window.__sjrpgEntryLoading,
 native:window.__sjrpg3dProbe,token:window.__nativeMemoryDocumentToken,size:[innerWidth,innerHeight],dpr:devicePixelRatio,
 canvases:[...document.querySelectorAll('canvas')].map(c=>({width:c.width,height:c.height})),build:window.__sjrpgBuild
})),15000,'normal app probe');}
async function check(){assert.equal(report.errors.length,0,JSON.stringify(report.errors));latest=await read();if(token)assert.equal(latest.token,token,'normal app document reloaded');return latest;}
async function wait(fn,label,ms=120000){const end=Date.now()+ms;while(Date.now()<end){const value=await check();if(fn(value))return value;await pause(150);}throw Error(label+' timeout');}
async function entry(name){const state=await wait(s=>s.entry?.[name],'entry '+name);await page.mouse.click(state.entry[name][0]*state.size[0],state.entry[name][1]*state.size[1]);}
function compactProfile(profile){
 const stacks=new Map();for(const sample of profile.samples||[]){
  const stack=sample.stack||[],key=stack.join('\n');const row=stacks.get(key)||{estimated_live_bytes:0,sampled_allocation_bytes:0,samples:0,stack};
  row.estimated_live_bytes+=sample.total||0;row.sampled_allocation_bytes+=sample.size||0;row.samples++;stacks.set(key,row);
 }
 const top=[...stacks.values()].sort((a,b)=>b.estimated_live_bytes-a.estimated_live_bytes);
 return {sample_count:profile.samples?.length||0,estimated_live_bytes:top.reduce((n,r)=>n+r.estimated_live_bytes,0),top_stacks:top.slice(0,40),modules:profile.modules||[]};
}
async function sample(label){
 const runtime=await check(),heap=await timeout(cdp.send('Runtime.getHeapUsage'),15000,'V8/embedder heap usage'),memory=await osMemory();
 const row={at:Date.now(),label,pose_updates:runtime.native?.animation?.pose_updates,native:runtime.native,heap,memory};
 report.samples.push(row);await appendFile(path.join(out,'native-samples.ndjson'),JSON.stringify(row)+'\n');
 console.log('NATIVE_MEMORY_SAMPLE '+JSON.stringify({label,pose_updates:row.pose_updates,heap,pss_bytes:memory.pss_bytes,processes:memory.processes}));
 return row;
}
async function nativeProfile(label){
 if(!samplingStarted)return;
 try{const result=await timeout(cdp.send('Memory.getSamplingProfile'),20000,'native allocation sampling profile');
  await save('native-profile-'+label+'.json',result.profile);const summary=compactProfile(result.profile);
  report.native_sampling[label]=summary;console.log('NATIVE_MEMORY_STACKS '+JSON.stringify({label,...summary,top_stacks:summary.top_stacks.slice(0,12)}));
 }catch(error){report.native_sampling[label+'_error']=String(error);}
}
async function memoryDump(label){
 if(!traceStarted)return;
 try{const value=await timeout(browserCdp.send('Tracing.requestMemoryDump',{deterministic:false,levelOfDetail:'detailed'}),20000,'native memory dump');
  (report.memory_trace.dumps??=[]).push({label,at:Date.now(),...value});console.log('NATIVE_MEMORY_DUMP '+JSON.stringify({label,...value}));
 }catch(error){(report.memory_trace.errors??=[]).push({label,error:String(error)});}
}
function attrNumber(attr){if(!attr||attr.type!=='scalar'||attr.units!=='bytes')return null;const value=String(attr.value);return /^[0-9a-fA-F]+$/.test(value)?parseInt(value,16):Number(value);}
function summarizeTrace(trace){
 const dumps=[];for(const event of trace.traceEvents||[]){
  const data=event.args?.dumps;if(!data?.allocators)continue;
  const allocators=[];for(const [name,allocation]of Object.entries(data.allocators)){
   const attributes={};for(const [key,value]of Object.entries(allocation.attrs||{})){const amount=attrNumber(value);if(Number.isFinite(amount))attributes[key]=amount;}
   if(Object.keys(attributes).length)allocators.push({name,...attributes});
  }
  allocators.sort((a,b)=>(b.size??b.allocated_objects_size??0)-(a.size??a.allocated_objects_size??0));
  dumps.push({pid:event.pid,ts:event.ts,guid:event.id||event.id2,process_totals:data.process_totals,top_allocators:allocators.slice(0,60)});
 }
 return {note:'Allocator names form a hierarchy; do not sum parent and child sizes.',dumps};
}
async function stopTrace(){
 if(!traceStarted)return;traceStarted=false;
 try{
  await browserCdp.send('Tracing.end');const complete=await timeout(traceCompletion,30000,'memory trace completion');
  assert(complete.stream,'memory trace must provide a stream');let total=0;const chunks=[];
  for(;;){const result=await timeout(browserCdp.send('IO.read',{handle:complete.stream,size:1024*1024}),15000,'trace stream read');
   const bytes=Buffer.from(result.data,result.base64Encoded?'base64':'utf8');total+=bytes.length;
   if(total>96*1024**2)throw Error('memory-only trace exceeded 96MiB diagnostic cap');
   chunks.push(bytes);if(result.eof)break;
  }
  await browserCdp.send('IO.close',{handle:complete.stream});const bytes=Buffer.concat(chunks);
  await writeFile(path.join(out,'memory-infra-trace.json'),bytes);const summary=summarizeTrace(JSON.parse(bytes.toString('utf8')));
  report.memory_trace.bytes=bytes.length;report.memory_trace.summary=summary;await save('memory-infra-summary.json',summary);
  for(const dump of summary.dumps)console.log('NATIVE_MEMORY_ALLOCATORS '+JSON.stringify({...dump,top_allocators:dump.top_allocators.slice(0,20)}));
 }catch(error){report.memory_trace.error=String(error);}
}
async function capture(name){try{const value=await timeout(cdp.send('Page.captureScreenshot',{format:'jpeg',quality:70,fromSurface:true,captureBeyondViewport:false}),30000,'compositor screenshot');await writeFile(path.join(out,name+'.jpg'),Buffer.from(value.data,'base64'));}catch(error){(report.capture_errors??=[]).push(String(error));}}
try{
 browserServer=await chromium.launchServer({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
 browser=await chromium.connect(browserServer.wsEndpoint());browser.on('disconnected',()=>{if(!closing)report.errors.push('browser-disconnected');});
 context=await browser.newContext({viewport:{width:270,height:480},deviceScaleFactor:1,hasTouch:true,userAgent:'Mozilla/5.0 (Linux; Android 16; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36'});
 await context.addInitScript(()=>{window.__nativeMemoryDocumentToken=crypto.randomUUID();Object.defineProperty(navigator,'standalone',{configurable:true,get:()=>true});const media=window.matchMedia.bind(window);window.matchMedia=query=>{const value=media(query);if(query!=='(display-mode: fullscreen)')return value;return new Proxy(value,{get(target,key){if(key==='matches')return true;const result=Reflect.get(target,key,target);return typeof result==='function'?result.bind(target):result;}});};});
 page=await context.newPage();page.on('pageerror',error=>report.errors.push(String(error)));page.on('crash',()=>report.errors.push('page-crash'));
 page.on('console',message=>{if(message.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(VALUE|OPERATION|ENUM)/.test(message.text()))report.errors.push(message.text());});
 page.on('close',()=>{if(!closing)report.errors.push('page-closed');});
 cdp=await context.newCDPSession(page);browserCdp=await browser.newBrowserCDPSession();await cdp.send('Log.enable');
 cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error')report.errors.push(entry.text);});
 const url=new URL(base);url.searchParams.set('quality','low');
 await page.goto(url.href,{waitUntil:'domcontentloaded'});await wait(s=>s.title&&!s.ready,'normal title');token=(await read()).token;
 await page.locator('#entry-start').click();await wait(s=>s.entry?.stage==='slots'||s.entry?.stage==='class','normal selection');
 let selected=await read();
 if(selected.entry.stage==='slots'){const empty=selected.entry.slots_state?.find(s=>!s.occupied);assert(empty,'fresh browser needs an empty normal save slot');await entry('slot'+empty.slot);selected=await wait(s=>s.entry?.selected_slot===empty.slot,'normal selected empty slot');}
 assert.equal(selected.entry.stage,'class','new adventure uses class selection');await entry('mage');await entry('start');
 await wait(s=>s.ready&&s.native?.ready&&!s.loading?.visible&&s.native?.animation?.pose_updates>0,'ordinary native mage ready');
 const state=await read();assert.equal(state.native.actor_mode,'skeletal_mage');assert.equal(state.native.quality,'low');report.normal_start=state;
 await capture('start');
 try{await cdp.send('Memory.startSampling',{samplingInterval:262144,suppressRandomness:false});samplingStarted=true;report.native_sampling.available=true;}catch(error){report.native_sampling.error=String(error);}
 try{
  traceCompletion=new Promise(resolve=>browserCdp.once('Tracing.tracingComplete',resolve));
  await browserCdp.send('Tracing.start',{transferMode:'ReturnAsStream',traceConfig:{recordMode:'recordUntilFull',includedCategories:['disabled-by-default-memory-infra'],memoryDumpConfig:{triggers:[]}}});
  traceStarted=true;report.memory_trace.available=true;
 }catch(error){report.memory_trace.start_error=String(error);}
 await sample('start');await nativeProfile('start');await memoryDump('start');
 const began=Date.now(),firstPose=latest.native.animation.pose_updates;
 for(;;){
  const row=await sample('standing-idle'),poses=row.pose_updates-firstPose;report.actual_pose_updates=poses;
  if(row.memory.pss_bytes>report.pss_safeguard_bytes){report.stop_reason='native diagnostic PSS safeguard';break;}
  if(poses>=report.target_pose_updates&&Date.now()-began>=report.minimum_observation_ms){report.stop_reason='target observed';break;}
  if(Date.now()-began>=report.deadline_ms){report.stop_reason='bounded diagnostic deadline';break;}
  await pause(1500);
 }
 await sample('end');await nativeProfile('end');await memoryDump('end');
 // This secondary control is outside the normal observation. Gameplay/rendering continue.
 try{report.finish_control={outside_normal_observation:true,result:await timeout(page.evaluate(()=>[...document.querySelectorAll('canvas')].map(canvas=>{const gl=canvas.getContext('webgl2');if(!gl)return{active:false};const start=performance.now();gl.finish();return{active:true,milliseconds:performance.now()-start,width:gl.drawingBufferWidth,height:gl.drawingBufferHeight};})),15000,'single GL finish')};await sample('after-finish-0');await pause(2000);await sample('after-finish-2s');await memoryDump('after-finish');}catch(error){report.finish_control_error=String(error);}
 try{await timeout(cdp.send('HeapProfiler.collectGarbage'),15000,'outside-observation GC');await sample('after-final-GC');report.final_gc_outside_observation=true;}catch(error){report.final_gc_error=String(error);}
 assert.equal(report.errors.length,0,JSON.stringify(report.errors));
 assert(report.actual_pose_updates>=20,'native profile needs at least 20 genuine hero pose updates');
 assert(report.native_sampling.available||report.memory_trace.available,'at least one native allocation diagnostic must be supported');
 report.passed=true;console.log('NATIVE_MEMORY_DIAGNOSTIC_COMPLETE '+JSON.stringify({diagnostic_only:true,pose_updates:report.actual_pose_updates,stop_reason:report.stop_reason,sampling:report.native_sampling.available,memory_trace:report.memory_trace.available}));
}catch(error){report.failure=String(error);console.error('NATIVE_MEMORY_DIAGNOSTIC_FAIL '+JSON.stringify({failure:report.failure,errors:report.errors}));process.exitCode=1;}
finally{
 await nativeProfile('final').catch(()=>{});await stopTrace().catch(()=>{});
 if(samplingStarted)await cdp.send('Memory.stopSampling').catch(()=>{});
 if(page&&!page.isClosed())await capture('end').catch(()=>{});
 await save('proof.json',report);closing=true;if(browser)await browser.close().catch(()=>{});if(browserServer)await browserServer.close().catch(()=>{});
}
