#!/usr/bin/env node
// Actual exported entry flow, isolated save files, and real compositor frames.
// No review delay, synthetic overlay, page pause, or production save files.
import assert from 'node:assert/strict';
import path from 'node:path';
import {mkdir,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=new URL(process.argv[2]||'http://127.0.0.1:8779/');
base.searchParams.set('save_layout_review','1');base.searchParams.set('quality','low');
const out=path.resolve(process.argv[3]||'build/entry-loading-review');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const proof={url:base.href,cases:[],errors:[],passed:false};let activePage;
const bad=/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/;
async function inline(name,data){
 await writeFile(path.join(out,name+'.jpg'),data);
 const b=data.toString('base64');
 console.log('SJ_ENTRY_LOADING_IMAGE_BEGIN '+name+' image/jpeg '+b.length);
 for(let i=0;i<b.length;i+=16384)console.log('SJ_ENTRY_LOADING_IMAGE_CHUNK '+name+' '+b.slice(i,i+16384));
 console.log('SJ_ENTRY_LOADING_IMAGE_END '+name);
}
async function bounded(promise,label,ms){
 let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' timed out after '+ms+'ms')),ms);})]);}finally{clearTimeout(timer);}
}
for(const operation of ['load','create'])for(const profile of [{name:'portrait',width:390,height:844,dpr:1},{name:'landscape-retina',width:844,height:390,dpr:2}]){
 const result={name:operation+'-'+profile.name,operation,profile,events:[],frames:[],checks:[],errors:[]};proof.cases.push(result);
 const context=await browser.newContext({viewport:{width:profile.width,height:profile.height},deviceScaleFactor:profile.dpr});
 const page=await context.newPage();activePage=page;const cdp=await context.newCDPSession(page);
 let stream=false,rotation=null,inputQueued=false;const frames=[];const pending=[];
 const recordError=e=>{result.errors.push(e);proof.errors.push({...e,case:result.name});};
 page.on('pageerror',e=>recordError({kind:'page',text:String(e),stack:e.stack}));
 page.on('console',m=>{
  const t=m.text();
  if(t.startsWith('SJ_ENTRY_PAINT ')){
   try{
    const event=JSON.parse(t.slice('SJ_ENTRY_PAINT '.length));result.events.push(event);
    if(event.kind==='raf'&&event.visible&&!inputQueued){
     inputQueued=true;result.keyboard_requested_phase=event.phase;
     pending.push((async()=>{
      for(const key of ['Escape','Enter']){
       await cdp.send('Input.dispatchKeyEvent',{type:'keyDown',key,code:key,windowsVirtualKeyCode:key==='Escape'?27:13,nativeVirtualKeyCode:key==='Escape'?27:13});
       await cdp.send('Input.dispatchKeyEvent',{type:'keyUp',key,code:key,windowsVirtualKeyCode:key==='Escape'?27:13,nativeVirtualKeyCode:key==='Escape'?27:13});
      }
     })().catch(e=>recordError({kind:'input',text:String(e)})));
    }
    if(event.kind==='raf'&&event.phase==='world'&&event.visible&&profile.name==='portrait'&&!rotation){
     rotation=page.setViewportSize({width:profile.height,height:profile.width});
     pending.push(rotation.catch(e=>recordError({kind:'rotation',text:String(e)})));
    }
   }catch(e){recordError({kind:'probe',text:String(e)});}
  }
  if(m.type()==='error'||bad.test(t))recordError({kind:'console',text:t,location:m.location()});
 });
 await cdp.send('Log.enable');cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error'||bad.test(entry.text))recordError({kind:'browser',text:entry.text});});
 cdp.on('Page.screencastFrame',event=>{
  pending.push(cdp.send('Page.screencastFrameAck',{sessionId:event.sessionId}).catch(()=>{}));
  if(!stream)return;
  // Keep first8 frames plus rolling112: retain actual middle-world spinner paints.
  // A first-only buffer followed by one final game frame loses the loading interval.
  const frame={timestamp:event.metadata.timestamp,metadata:event.metadata,data:event.data};
  if(frames.length<120)frames.push(frame);else {frames.splice(8,1);frames.push(frame);}
 });
 await page.addInitScript(()=>{
  const samples=[];window.__sjrpgEntryPaintReview=samples;
  let last='',running=false;
  const read=()=>{
   const element=document.getElementById('sjrpg-entry-loading');
   const status=document.getElementById('sjrpg-entry-loading-status');
   const spinner=document.getElementById('sjrpg-entry-loading-spinner');
   if(!element)return null;
   const style=getComputedStyle(element),r=element.getBoundingClientRect();
   const sr=status?.getBoundingClientRect(),spin=spinner&&getComputedStyle(spinner),card=element.querySelector('.entry-load-card')?.getBoundingClientRect(),sp=spinner?.getBoundingClientRect();
   return {epoch:performance.timeOrigin+performance.now(),phase:element.dataset.phase||'',visible:!element.hidden&&style.display!=='none'&&style.visibility!=='hidden'&&Number(style.opacity)>0&&r.width>0&&r.height>0,
    rect:[r.x,r.y,r.width,r.height],card_rect:card?[card.x,card.y,card.width,card.height]:null,spinner_transformed_bounds:sp?[sp.x,sp.y,sp.width,sp.height]:null,spinner_rect:sp?[sp.x+sp.width/2-spinner.offsetWidth/2,sp.y+sp.height/2-spinner.offsetHeight/2,spinner.offsetWidth,spinner.offsetHeight]:null,status:status?.textContent||'',status_rect:sr?[sr.x,sr.y,sr.width,sr.height]:null,
    spinner_animation:spin?.animationName||'',spinner_duration:spin?.animationDuration||'',spinner_transform:spin?.transform||'',
    viewport:[innerWidth,innerHeight],adventure:window.__sjrpgAdventureReady===true,probe:window.__sjrpgEntryLoading?JSON.parse(JSON.stringify(window.__sjrpgEntryLoading)):null};
  };
  const emit=kind=>{
   const sample=read();if(!sample)return;
   const key=JSON.stringify([sample.phase,sample.visible,sample.viewport,sample.status,kind]);
   if(key===last)return;last=key;sample.kind=kind;samples.push(sample);
   console.log('SJ_ENTRY_PAINT '+JSON.stringify(sample));
  };
  const tick=()=>{emit('raf');if(document.getElementById('sjrpg-entry-loading')&&!window.__sjrpgAdventureReady)requestAnimationFrame(tick);else running=false;};
  window.addEventListener('keydown',event=>{
   const sample=read();if(!sample?.visible)return;
   // CDP/UA dispatch may run a microtask checkpoint BETWEEN window listeners.
   // Read cancellation in the next task, after the app's later capture listener.
   // Keep the original event-time visibility and timestamp in the recorded sample.
   setTimeout(()=>{
    sample.kind='key';sample.key=event.key;sample.prevented=event.defaultPrevented;
    samples.push(sample);console.log('SJ_ENTRY_PAINT '+JSON.stringify(sample));
   },0);
  },true);
  const observer=new MutationObserver(()=>{
   emit('mutation');
   if(!running&&document.getElementById('sjrpg-entry-loading')&&!window.__sjrpgAdventureReady){running=true;requestAnimationFrame(tick);}
  });
  observer.observe(document,{subtree:true,childList:true,attributes:true,characterData:true});
 });
 const read=()=>page.evaluate(()=>({ui:window.__sjrpgClassButtons,review:window.__sjrpgSaveLayoutReview,adventure:window.__sjrpgAdventureReady===true,loading:window.__sjrpgEntryLoading,events:window.__sjrpgEntryPaintReview,viewport:[innerWidth,innerHeight],time_origin:performance.timeOrigin,title:window.__sjrpgTitleReady,entry:window.__sjrpgEntryReady}));
 async function wait(predicate,label,timeout=15000){
  const until=Date.now()+timeout;let s;
  while(Date.now()<until){
   assert.equal(result.errors.length,0,'runtime error '+JSON.stringify(result.errors));
   s=await read();assert(!s.review?.fixture_error,s.review?.fixture_error);
   if(predicate(s))return s;
   await page.waitForTimeout(80);
  }
  throw Error('Timed out '+label+' '+JSON.stringify(s));
 }
 async function tap(key){
  let s=await read();
  if(/^slot[1-4]$/.test(key)){
   for(let n=0;n<12;n++){
    s=await read();const i=Number(key.at(-1))-1,card=s.ui.save_layout.cards[i].select,list=s.ui.save_layout.list;
    if(card[1]>=list[1]-1&&card[1]+card[3]<=list[1]+list[3]+1)break;
    await page.mouse.move(profile.width*.5,profile.height*.5);await page.mouse.wheel(0,220);await page.waitForTimeout(100);
   }
  }
  s=await read();assert(s.ui?.visible?.[key],'actual control visible '+key);
  await page.mouse.click(s.ui[key][0]*s.viewport[0],s.ui[key][1]*s.viewport[1]);await page.waitForTimeout(120);
 }
 try{
  console.log('ENTRY_LOADING_STAGE '+JSON.stringify({name:result.name,stage:'boot'}));
  await page.goto(base.href,{waitUntil:'domcontentloaded'});
  await wait(s=>s.title&&s.entry&&s.review?.ready,'fresh title and isolated fixture',90000);
  await page.locator('#entry-start').click();
  await wait(s=>s.ui?.stage==='slots'&&s.review.screen==='selection','actual save list');
  // Actual orientation round-trip before entry: preserve the selected slot and footer.
  await page.setViewportSize({width:profile.height,height:profile.width});
  await wait(s=>s.viewport[0]===profile.height,'rotation away');
  await page.setViewportSize({width:profile.width,height:profile.height});
  await wait(s=>s.viewport[0]===profile.width&&s.ui?.stage==='slots','rotation back');
  await tap(operation==='load'?'slot3':'slot2');
  if(operation==='create'){
   await wait(s=>s.ui.stage==='class'&&s.ui.selected_slot===2,'empty slot hero selection');
   await tap('mage');
  }else await wait(s=>s.ui.selected_slot===3,'saved mage selection');
  let before=await read();result.before=before;
  const selected=operation==='load'?3:2;
  const expected=operation==='load'?before.ui.slots_state[2]:{class:'mage',level:1};
  const button=operation==='load'?'continue':'start';
  assert(before.ui.visible[button],'actual entry action');
  const point=before.ui[button].map((v,i)=>v*before.viewport[i]);
  stream=true;await cdp.send('Page.startScreencast',{format:'jpeg',quality:80,maxWidth:900,maxHeight:1000,everyNthFrame:1});
  const clickedAt=Date.now();result.clicked_at=clickedAt;
  // Two real pointer activations; the immediate overlay and root guard own suppression.
  await page.mouse.dblclick(...point,{delay:30});
  const ready=await wait(s=>s.adventure&&s.review.screen==='adventure'&&s.loading?.visible===false,'native adventure ready and overlay dismissed',90000);
  console.log('ENTRY_LOADING_STAGE '+JSON.stringify({name:result.name,stage:'native-ready',frames:frames.length,loading:ready.loading}));
  await bounded(Promise.allSettled(pending),'pre-stop CDP acknowledgements',10000);
  await page.waitForTimeout(120);
  stream=false;await bounded(cdp.send('Page.stopScreencast'),'stop screencast',10000);await bounded(Promise.allSettled(pending),'final CDP acknowledgements',10000);
  result.after=await read();
  const events=result.after.events||result.events;result.events=events;
  const paints=events.filter(e=>e.kind==='raf'&&e.visible&&!e.adventure&&e.epoch>=clickedAt-100);
  assert(paints.length>0,'actual visible pre-ready RAF paint');
  const keyboard=events.filter(e=>e.kind==='key'&&e.visible&&['Escape','Enter'].includes(e.key));
  result.keyboard_during_loading=keyboard;
  assert(keyboard.some(e=>e.key==='Escape')&&keyboard.some(e=>e.key==='Enter'),'actual Escape/Enter delivered while overlay visible');
  assert(keyboard.every(e=>e.prevented),'overlay traps queued navigation/activation');
  if(profile.name==='portrait'){
   assert(rotation,'actual rotation requested during world loading');
   assert.deepEqual(result.after.viewport,[profile.height,profile.width],'rotation delivered before final screenshot');
  }
  const first=paints.find(e=>e.phase===operation)||paints[0];
  assert.equal(first.phase,operation,'first visible loading phase matches actual operation');
  assert(first.status.trim().length>0,'real phase status text');
  assert(first.spinner_animation&&first.spinner_animation!=='none','real animated spinner');
  assert.equal(first.rect[0],0);assert.equal(first.rect[1],0);
  assert(Math.abs(first.rect[2]-first.viewport[0])<2&&Math.abs(first.rect[3]-first.viewport[1])<2,'loading overlay covers actual viewport');
  const sr=first.status_rect;assert(sr&&sr[2]>0&&sr[3]>0&&sr[0]>=0&&sr[1]>=0&&sr[0]+sr[2]<=first.viewport[0]+1&&sr[1]+sr[3]<=first.viewport[1]+1,'status text inside viewport');
  const phaseEvents=ready.loading.phase_events||[];
  for(const phase of [operation,'world']){
   const event=phaseEvents.find(e=>e.phase===phase);
   assert(event&&['shown_at','raf1_at','painted_at','work_at'].every(k=>Number.isFinite(event[k])),'actual '+phase+' paint/work timestamps');
   assert(event.shown_at<=event.raf1_at&&event.raf1_at<=event.painted_at&&event.painted_at<=event.work_at,'actual '+phase+' browser paint acknowledgement precedes blocking work');
  }
  assert(Number.isFinite(ready.loading.native_ready_at)&&Number.isFinite(ready.loading.finished_at)&&ready.loading.native_ready_at<=ready.loading.finished_at,'native readiness precedes overlay dismissal');
  assert.equal(ready.loading.result,'ready','actual successful cleanup result');
  const phases=ready.loading.painted_phases||[];
  assert(phases.some(p=>(typeof p==='string'?p:p.phase)===operation),'production double-RAF acknowledgement for operation');
  assert(phases.some(p=>(typeof p==='string'?p:p.phase)==='world'),'production double-RAF acknowledgement before world build');
  const worldPaint=paints.find(e=>e.phase==='world');assert(worldPaint,'actual world phase before native ready');
  assert.equal(ready.loading.sequence,1,'double activation must create only one loading sequence');
  assert.equal(Number(ready.loading.slot),selected,'loading belongs to requested slot');
  assert.equal(ready.review.active_slot,selected);assert.equal(ready.review.hero_class,expected.class);assert.equal(ready.review.level,expected.level);
  for(const n of ['1','3','4'])if(Number(n)!==selected)assert.deepEqual(ready.review.file_hashes[n],before.review.file_hashes[n],'entry changed another slot '+n);
  assert(Object.values(ready.review.file_hashes[String(selected)]).some(Boolean),'selected slot remains persisted after actual entry');
  // CDP can deliver a stale compositor buffer with a recent timestamp.
  // Verify real JPEG pixels against the actual DOM card + spinner geometry.
  const worldEvent=ready.loading.phase_events.find(e=>e.phase==='world');
  const worldEpoch=ready.time_origin+worldEvent.painted_at;
  const nativeReadyEpoch=ready.time_origin+ready.loading.native_ready_at;
  const end=Math.min(nativeReadyEpoch,ready.time_origin+ready.loading.finished_at);
  const candidates=frames.filter(f=>Number.isFinite(f.timestamp)&&f.timestamp*1000>=worldEpoch&&f.timestamp*1000<end);
  assert(candidates.length>0,'actual compositor JPEGs after the world paint acknowledgement');
  console.log('ENTRY_LOADING_STAGE '+JSON.stringify({name:result.name,stage:'pixel-scoring',frames:frames.length,candidates:candidates.length}));
  for(const index of [...new Set([0,Math.floor(candidates.length/2),candidates.length-1])])await inline(result.name+'-raw-compositor-'+index,Buffer.from(candidates[index].data,'base64'));
  const scored=await bounded(page.evaluate(async({frames,events})=>{
   const results=[];
   for(let index=0;index<frames.length;index++){
    const frame=frames[index],img=new Image();img.src='data:image/jpeg;base64,'+frame.data;
    let timer;
    try{await Promise.race([img.decode(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('JPEG decode frame '+index+' timed out after 5000ms')),5000);})]);}finally{clearTimeout(timer);}
    const event=[...events].reverse().find(e=>e.visible&&e.card_rect&&e.spinner_rect&&e.epoch<=frame.timestamp*1000&&Math.abs(img.width/img.height-e.viewport[0]/e.viewport[1])<.03);
    if(!event){results.push({index,accepted:false,reason:'no matching actual DOM viewport geometry'});continue;}
    const canvas=document.createElement('canvas');canvas.width=img.width;canvas.height=img.height;
    const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(img,0,0);
    const bytes=ctx.getImageData(0,0,img.width,img.height).data,sx=img.width/event.viewport[0],sy=img.height/event.viewport[1];
    const pixel=(x,y)=>{
     x=Math.max(0,Math.min(img.width-1,Math.floor(x*sx)));y=Math.max(0,Math.min(img.height-1,Math.floor(y*sy)));
     return [...bytes.slice((y*img.width+x)*4,(y*img.width+x)*4+3)];
    };
    const bronze=p=>p[0]>=48&&p[0]>p[1]+4&&p[1]>p[2]+5;
    const dark=p=>Math.abs(p[0]-23)<=14&&Math.abs(p[1]-30)<=14&&Math.abs(p[2]-28)<=14;
    const luminance=p=>.2126*p[0]+.7152*p[1]+.0722*p[2];
    const [x,y,w,h]=event.card_rect;
    let border=0,background=0,ring=0;const borderSamples=[];
    for(let i=0;i<8;i++){
     const t=(i+.5)/8;
     // JPEG chroma subsampling desaturates the real 1px bronze line.
     // Verify its measured bright edge against the adjacent dark interior.
     for(const [ex,ey,ix,iy]of [[x+12+(w-24)*t,y+.5,x+12+(w-24)*t,y+4],[x+12+(w-24)*t,y+h-.5,x+12+(w-24)*t,y+h-4],[x+.5,y+12+(h-24)*t,x+4,y+12+(h-24)*t],[x+w-.5,y+12+(h-24)*t,x+w-4,y+12+(h-24)*t]]){
      const edge=pixel(ex,ey),inside=pixel(ix,iy),contrast=luminance(edge)-luminance(inside);
      border+=Number(contrast>=25);
      if(borderSamples.length<8)borderSamples.push({edge,inside,contrast});
     }
    }
    for(const p of [[x+9,y+9],[x+w-9,y+9],[x+9,y+h-9],[x+w-9,y+h-9],[x+9,y+h*.4],[x+w-9,y+h*.4],[x+9,y+h*.7],[x+w-9,y+h*.7]])background+=Number(dark(pixel(...p)));
    const [a,b,c,d]=event.spinner_rect;
    for(let i=0;i<16;i++){const angle=i*Math.PI/8;ring+=Number(bronze(pixel(a+c/2+Math.cos(angle)*(c/2-1),b+d/2+Math.sin(angle)*(d/2-1))));}
    const score={border:border/32,background:background/8,spinner:ring/16};
    const accepted=score.border>=.5&&score.background>=.75&&score.spinner>=.25;
    results.push({index,score,accepted,border_samples:borderSamples,epoch:frame.timestamp*1000,dom_epoch:event.epoch,viewport:event.viewport,image:[img.width,img.height],card_rect:event.card_rect,spinner_rect:event.spinner_rect});
    if(accepted)return results; // The gate already asks for the first actual overlay, not every video frame.
   }
   return results;
  },{frames:candidates.map(f=>({timestamp:f.timestamp,data:f.data})),events}),'real compositor pixel scoring',20000);
  result.frame_pixel_checks=scored;
  const match=scored.find(f=>f.accepted);
  if(!match){
   for(const [i,f]of candidates.filter((_,i,a)=>i===0||i===Math.floor(a.length/2)||i===a.length-1).entries())await inline(result.name+'-unmatched-compositor-'+i,Buffer.from(f.data,'base64'));
  }
  assert(match,'a real compositor frame must visibly contain the measured loading card and spinner; '+JSON.stringify(scored));
  const frame=candidates[match.index];
  result.loading_frame={timestamp:frame.timestamp,metadata:frame.metadata,paint_epoch:worldEpoch,native_ready_epoch:nativeReadyEpoch,dismissed_epoch:ready.time_origin+ready.loading.finished_at,pixel_match:match};
  assert(frame.timestamp*1000<nativeReadyEpoch,'actual loading image precedes native adventure readiness');
  result.frames=frames.map(f=>({timestamp:f.timestamp,metadata:f.metadata,bytes:Buffer.byteLength(f.data,'base64')}));
  await inline(result.name+'-loading',Buffer.from(frame.data,'base64'));
  await inline(result.name+'-ready',await page.screenshot({type:'jpeg',quality:80,scale:'css'}));
  result.checks.push('fresh actual '+operation+' launches selected slot','rapid double pointer produces one entry','operation and world phases painted before native ready','actual full-viewport compositor loading JPEG','real orientation round-trip and final viewport','other save slots unchanged and requested slot persisted');
  assert.equal(result.errors.length,0,'no app/browser/GPU/IDB errors');
  console.log('ENTRY_LOADING_CASE_PASS '+JSON.stringify({name:result.name,checks:result.checks.length,frames:result.frames.length,keyboard_during_loading:result.keyboard_during_loading,loading_frame:result.loading_frame,time_origin:ready.time_origin,loading:ready.loading}));
 }catch(e){
  result.failure=String(e);console.error('ENTRY_LOADING_CASE_FAIL '+result.name+' '+String(e));
  result.frames=frames.map(f=>({timestamp:f.timestamp,metadata:f.metadata,bytes:Buffer.byteLength(f.data,'base64')}));
  const visible=result.events.find(e=>e.kind==='raf'&&e.visible&&!e.adventure);
  if(visible){
   const hidden=result.events.find(e=>!e.visible&&e.epoch>visible.epoch);
   const frame=frames.find(f=>f.timestamp*1000>=visible.epoch&&(!hidden||f.timestamp*1000<hidden.epoch));
   if(frame)await inline(result.name+'-loading-diagnostic',Buffer.from(frame.data,'base64'));
  }
  try{result.failure_state=await read();await inline(result.name+'-failure',await page.screenshot({type:'jpeg',quality:75,scale:'css'}));}catch(diagnosticError){result.diagnostic_error=String(diagnosticError);}
  process.exitCode=1;
 }finally{
  if(stream)await cdp.send('Page.stopScreencast').catch(()=>{});
  await context.close();
  await writeFile(path.join(out,'proof.json'),JSON.stringify(proof,null,2));
 }
}
proof.passed=proof.cases.length===4&&proof.cases.every(c=>!c.failure&&c.errors.length===0);
await writeFile(path.join(out,'proof.json'),JSON.stringify(proof,null,2));
console.log((proof.passed?'ENTRY_LOADING_PASS ':'ENTRY_LOADING_FAIL ')+JSON.stringify({cases:proof.cases.length,checks:proof.cases.reduce((sum,c)=>sum+c.checks.length,0),errors:proof.errors.length}));
await browser.close();
if(!proof.passed)process.exitCode=1;
