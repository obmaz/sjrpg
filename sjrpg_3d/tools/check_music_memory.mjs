#!/usr/bin/env node
import {inspectionUrl} from './review/inspection_url.mjs';
// Permanent regression: normal exported music must not copy whole songs every rendered update.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';

export function installMusicMemoryTelemetry(scope=globalThis){
 const totals={buffers:0,long_buffers:0,pcm_bytes_allocated:0,long_pcm_bytes_allocated:0,sources:0,starts:0,stops:0,resumes:0};
 const contexts=[],seen=new WeakSet();let serial=0;
 const remember=context=>{if(context&&!seen.has(context)){seen.add(context);contexts.push({id:++serial,ref:new WeakRef(context)});}};
 const base=scope.BaseAudioContext?.prototype||scope.AudioContext?.prototype||scope.webkitAudioContext?.prototype;
 if(base)for(const name of ['createBuffer','createBufferSource']){
  const original=base[name];if(!original)continue;
  base[name]=function(...args){const result=Reflect.apply(original,this,args);remember(this);
   if(name==='createBuffer'){const bytes=result.numberOfChannels*result.length*4;totals.buffers++;totals.pcm_bytes_allocated+=bytes;if(bytes>=1024*1024){totals.long_buffers++;totals.long_pcm_bytes_allocated+=bytes;}}
   else totals.sources++;
   return result;
  };
 }
 const sources=scope.AudioBufferSourceNode?.prototype;
 if(sources)for(const name of ['start','stop']){const original=sources[name];if(original)sources[name]=function(...args){const result=Reflect.apply(original,this,args);remember(this.context);totals[name==='start'?'starts':'stops']++;return result;};}
 const constructors=new Map();
 for(const name of ['AudioContext','webkitAudioContext']){
  const Original=scope[name];if(!Original)continue;
  if(!constructors.has(Original)){
   const originalResume=Original.prototype.resume;
   if(originalResume)Original.prototype.resume=function(...args){remember(this);totals.resumes++;return Reflect.apply(originalResume,this,args);};
   constructors.set(Original,new Proxy(Original,{construct(target,args){const context=Reflect.construct(target,args,target);remember(context);return context;}}));
  }
  scope[name]=constructors.get(Original);
 }
 // Keep weak context handles and scalar counters, never AudioBuffers or source nodes.
 scope.__sjrpgMusicMemorySnapshot=()=>({...totals,contexts:contexts.flatMap(({id,ref})=>{const context=ref.deref();return context?[{id,state:context.state,current_time:context.currentTime,sample_rate:context.sampleRate}]:[];})});
}

async function contract(){
 class FakeBuffer{constructor(channels,frames,rate){this.numberOfChannels=channels;this.length=frames;this.sampleRate=rate;}}
 class FakeSource{constructor(context){this.context=context;}start(){return 13;}stop(){return 17;}}
 class FakeBase{createBuffer(channels,frames,rate){if(frames<1)throw new RangeError('frames');return new FakeBuffer(channels,frames,rate);}createBufferSource(){return new FakeSource(this);}}
 class FakeContext extends FakeBase{constructor(){super();this.state='suspended';this.currentTime=0;this.sampleRate=48000;}resume(){this.state='running';return Promise.resolve('awake');}}
 const scope={BaseAudioContext:FakeBase,AudioContext:FakeContext,webkitAudioContext:FakeContext,AudioBufferSourceNode:FakeSource};
 installMusicMemoryTelemetry(scope);assert.equal(scope.AudioContext,scope.webkitAudioContext);
 const context=new scope.AudioContext();assert(context instanceof FakeContext);assert(context instanceof scope.AudioContext);
 assert.equal(await context.resume(),'awake');const short=context.createBuffer(2,128,48000),long=context.createBuffer(2,200000,48000);
 assert(short instanceof FakeBuffer&&long instanceof FakeBuffer);const source=context.createBufferSource();assert(source instanceof FakeSource);assert.equal(source.start(),13);assert.equal(source.stop(),17);
 assert.throws(()=>context.createBuffer(2,0,48000),RangeError);context.currentTime=1;
 const result=scope.__sjrpgMusicMemorySnapshot();assert.equal(result.buffers,2);assert.equal(result.long_buffers,1);assert.equal(result.pcm_bytes_allocated,1601024);assert.equal(result.long_pcm_bytes_allocated,1600000);
 assert.equal(result.sources,1);assert.equal(result.starts,1);assert.equal(result.stops,1);assert.equal(result.resumes,1);assert.equal(result.contexts.length,1);assert.equal(result.contexts[0].state,'running');assert.equal(result.contexts[0].current_time,1);
 console.log('MUSIC_MEMORY_CONTRACT_PASS '+JSON.stringify({checks:20}));
}

async function review(){
 const {chromium}=createRequire(import.meta.url)('playwright'),base=inspectionUrl(process.argv[2]||'http://127.0.0.1:8779/'),out=path.resolve(process.argv[3]||'build/music-memory');
 await mkdir(out,{recursive:true});
 const fold=process.env.SJRPG_MUSIC_PROFILE==='fold',profile=fold?{width:768,height:1024,dpr:3,quality:'high',deadline_ms:180000}:{width:390,height:844,dpr:1,quality:'low',deadline_ms:90000};
 const report={profile,normal_export:true,extra_godot_observers:false,pcm_threshold_bytes:1024*1024,pose_target:40,errors:[],samples:[],passed:false};
 let browser,context,page,token;
 const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 async function read(){const state=await page.evaluate(()=>({title:window.__sjrpgTitleReady,entry:window.__sjrpgClassButtons,ready:window.__sjrpgAdventureReady,loading:window.__sjrpgEntryLoading,native:window.__sjrpg3dProbe,audio:window.__sjrpgMusicMemorySnapshot?.(),token:window.__sjrpgMusicMemoryDocumentToken,size:[innerWidth,innerHeight],dpr:devicePixelRatio,canvases:[...document.querySelectorAll('canvas')].map(c=>({width:c.width,height:c.height}))}));assert.equal(report.errors.length,0,JSON.stringify(report.errors));if(token)assert.equal(state.token,token,'music review document reloaded');return state;}
 async function wait(fn,label,ms=profile.deadline_ms){const end=Date.now()+ms;while(Date.now()<end){const state=await read();if(fn(state))return state;await pause(180);}throw Error(label+' timeout');}
 async function entry(name){const state=await wait(s=>s.entry?.[name],'entry '+name);await page.mouse.click(state.entry[name][0]*state.size[0],state.entry[name][1]*state.size[1]);}
 try{
  browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
  context=await browser.newContext({viewport:{width:profile.width,height:profile.height},deviceScaleFactor:profile.dpr,hasTouch:true,userAgent:'Mozilla/5.0 (Linux; Android 16; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36'});
  await context.addInitScript(installMusicMemoryTelemetry);
  await context.addInitScript(()=>{window.__sjrpgMusicMemoryDocumentToken=crypto.randomUUID();});
  page=await context.newPage();page.on('pageerror',error=>report.errors.push(String(error)));page.on('crash',()=>report.errors.push('page-crash'));
  page.on('console',message=>{if(message.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(message.text()))report.errors.push(message.text());});
  const url=inspectionUrl(base);url.searchParams.set('quality',profile.quality);await page.goto(url.href,{waitUntil:'domcontentloaded'});
  await wait(s=>s.title&&!s.ready,'normal title');token=(await read()).token;
  const titleStart=await page.evaluate(()=>window.__sjrpgTitleButtons?.new_game);
  if(titleStart)await page.mouse.click(titleStart[0]*profile.width,titleStart[1]*profile.height);
  else await page.locator('#entry-start').click();
  let selected=await wait(s=>s.entry?.stage==='slots'||s.entry?.stage==='class','normal selection');
  if(selected.entry.stage==='slots'){const empty=selected.entry.slots_state?.find(slot=>!slot.occupied);assert(empty,'fresh browser needs a normal empty slot');await entry('slot'+empty.slot);selected=await wait(s=>s.entry?.selected_slot===empty.slot&&s.entry?.stage==='class','normal new-character selection');}
  assert.equal(selected.entry.stage,'class');await entry('mage');await entry('start');
  let state=await wait(s=>s.ready&&s.native?.ready&&!s.loading?.visible&&s.native?.actor_mode==='skeletal_mage','ordinary mage ready');
  assert.equal(state.native.quality,profile.quality);assert(state.audio,'WebAudio counters must exist');
  const initialPose=state.native.animation.pose_updates;
  state=await wait(s=>s.native.animation.pose_updates>=initialPose+6&&s.audio.contexts.some(c=>c.state==='running'),'warm real animation and unlocked running audio');
  const start=state,clock=Date.now();report.start=start;
  do{
   state=await read();assert(state.audio.contexts.some(c=>c.state==='running'),'audio context must remain running, not muted/suspended');
   assert.equal(state.audio.long_buffers,start.audio.long_buffers,'long AudioBuffers must not be copied during ordinary music');
   report.samples.push({pose_updates:state.native.animation.pose_updates,audio:state.audio});
   if(state.native.animation.pose_updates-start.native.animation.pose_updates>=report.pose_target)break;
   await pause(250);
  }while(Date.now()-clock<profile.deadline_ms);
  const poses=state.native.animation.pose_updates-start.native.animation.pose_updates;
  assert(poses>=report.pose_target,'must observe at least 40 actual native animation updates');
  const advancing=state.audio.contexts.some(current=>current.state==='running'&&start.audio.contexts.some(before=>before.id===current.id&&current.current_time-before.current_time>=0.1));
  assert(advancing,'the same running AudioContext clock must advance');
  report.end=state;report.pose_updates=poses;report.pcm_bytes_allocated=state.audio.pcm_bytes_allocated-start.audio.pcm_bytes_allocated;
  report.sources_created=state.audio.sources-start.audio.sources;report.long_buffers_created=state.audio.long_buffers-start.audio.long_buffers;report.passed=true;
  console.log('MUSIC_MEMORY_PASS '+JSON.stringify({profile,pose_updates:poses,long_buffers_created:report.long_buffers_created,pcm_bytes_allocated:report.pcm_bytes_allocated,sources_created:report.sources_created,running_audio_clock_advances:advancing,errors:report.errors.length}));
 }catch(error){report.failure=String(error);console.error('MUSIC_MEMORY_FAIL '+JSON.stringify({failure:report.failure,errors:report.errors}));process.exitCode=1;}
 finally{await writeFile(path.join(out,'proof.json'),JSON.stringify(report,null,2));if(browser)await browser.close();}
}
if(process.argv.includes('--self-test'))await contract();else await review();
