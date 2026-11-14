#!/usr/bin/env node
import {inspectionUrl} from './review/inspection_url.mjs';
// Real exported Godot UI in a fresh browser profile. The fixture only prepares test files.
import assert from 'node:assert/strict';
import path from 'node:path';
import {mkdir,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';

const {chromium}=createRequire(import.meta.url)('playwright');
const url=inspectionUrl(process.argv[2]||'http://127.0.0.1:8767/');
url.searchParams.set('save_layout_review','1');
url.searchParams.set('quality','low');
const classVisualOnly=process.env.SJRPG_ENTRY_CLASS_VISUAL_ONLY==='1';
const entryVisualOnly=process.env.SJRPG_ENTRY_VISUAL_ONLY==='1'||classVisualOnly;
const captureBaseline=process.env.SJRPG_ENTRY_BASELINE==='1';
const visualFailures=[];
const out=path.resolve(process.argv[3]||'build/save-layout-review');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,hasTouch:true});
const page=await context.newPage();
const errors=[];const errorDetails=[];const captures=[];const checks=[];let failure=null;
const cdp=await context.newCDPSession(page);await cdp.send('Log.enable');
const bad=/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/;
page.on('pageerror',error=>errors.push({kind:'page',text:String(error),stack:error.stack}));
page.on('console',message=>{if(message.type()==='error'||bad.test(message.text())){
 const entry={kind:'console',text:message.text(),location:message.location()};errors.push(entry);
 errorDetails.push(Promise.allSettled(message.args().map(arg=>arg.evaluate(value=>{
  if(value!==null&&typeof value==='object')return {type:Object.prototype.toString.call(value),name:value.name,message:value.message,errno:value.errno,code:value.code,stack:value.stack};
  return value;
 }))).then(args=>{entry.args=args;}));
}});
cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error'||bad.test(entry.text))errors.push({kind:'browser',text:entry.text});});

const read=()=>page.evaluate(()=>({ui:window.__sjrpgClassButtons,review:window.__sjrpgSaveLayoutReview,window:[innerWidth,innerHeight],location:location.href,fixture_action_type:typeof window.__sjrpgSaveLayoutAction,adventure:window.__sjrpgAdventureReady===true}));
const stateKey=s=>JSON.stringify({hashes:s.review.file_hashes,hero:s.review.hero_class,gold:s.review.gold,level:s.review.level,xp:s.review.xp,active:s.review.active_slot});
function record(name){checks.push(name);}
async function waitState(predicate,label,timeout=15000){
 const until=Date.now()+timeout;
 let last;
 while(Date.now()<until){
  assert.equal(errors.length,0,'unexpected runtime error while waiting for '+label+'; runtimeErrors='+JSON.stringify(errors));
  last=await read();
  if(last.review?.fixture_error)throw new Error(last.review.fixture_error);
  if(predicate(last))return last;
  await page.waitForTimeout(100);
 }
 throw new Error('Timed out: '+label+'; state='+JSON.stringify({stage:last?.ui?.stage,focus:last?.ui?.focus,review:last?.review,location:last?.location,fixture_action_type:last?.fixture_action_type,entry:await page.evaluate(()=>({title:window.__sjrpgTitleReady,ready:window.__sjrpgEntryReady,fixture_boot:window.__sjrpgSaveLayoutReviewBoot}))}));
}
function css(s,r){
 assert(Array.isArray(r)&&r.length===4&&r.every(Number.isFinite),'missing/faulty measured rectangle');
 const [w,h]=s.ui.viewport;
 return {x:r[0]*s.window[0]/w,y:r[1]*s.window[1]/h,w:r[2]*s.window[0]/w,h:r[3]*s.window[1]/h};
}
const endX=r=>r.x+r.w;
const endY=r=>r.y+r.h;
const encloses=(outer,inner,epsilon=1)=>inner.x>=outer.x-epsilon&&inner.y>=outer.y-epsilon&&endX(inner)<=endX(outer)+epsilon&&endY(inner)<=endY(outer)+epsilon;
const overlaps=(a,b)=>Math.min(endX(a),endX(b))-Math.max(a.x,b.x)>1&&Math.min(endY(a),endY(b))-Math.max(a.y,b.y)>1;
const pointInside=(p,r)=>p[0]>=r.x&&p[0]<=endX(r)&&p[1]>=r.y&&p[1]<=endY(r);
function geometry(s,label){
 assert.equal(s.ui.stage,'slots',label+' must show the save list');
 const layout=s.ui.save_layout;
 assert(layout&&Array.isArray(layout.cards)&&layout.cards.length===3,label+' must expose all three source rows');
 const windowRect={x:0,y:0,w:s.window[0],h:s.window[1]};
 const safe=css(s,layout.safe),sheet=css(s,layout.sheet),list=css(s,layout.list),footer=css(s,layout.footer);
 assert(encloses(windowRect,safe)&&encloses(safe,sheet)&&encloses(sheet,list)&&encloses(sheet,footer),label+' safe sheet/list/footer');
 assert(list.h>=44,label+' must retain room for a complete tappable row');
 assert(endY(list)<=footer.y+1,label+' list must not cover the fixed footer');
 const heading=css(s,layout.heading),subtitle=css(s,layout.subtitle),back=css(s,s.ui.rects.back),action=css(s,s.ui.rects.continue);
 assert(encloses(sheet,heading)&&encloses(sheet,subtitle)&&!overlaps(heading,subtitle)&&!overlaps(back,heading),label+' header and subtitle');
 assert(endY(subtitle)<=list.y+1,label+' wrapped subtitle must not enter the scrolling save list');
 const contextBox=css(s,layout.context);
 assert(encloses(footer,contextBox)&&endY(contextBox)<=action.y+1,label+' footer context must remain separate from the main action');
 assert(back.w>=43.5&&back.h>=43.5&&action.w>=43.5&&action.h>=43.5,label+' actual CSS header/footer touch targets');
 assert(encloses(footer,action),label+' main action must remain in its footer');
 const ratio=s.window[0]/s.ui.viewport[0];
 for(let i=0;i<layout.cards.length;i++){
  const c=layout.cards[i],row=css(s,c.row),select=css(s,c.select),title=css(s,c.title),meta=css(s,c.meta),number=css(s,c.number);
  assert.equal(c.slot,i+1);assert(c.title_text&&c.meta_text,label+' actual title/metadata');
  assert(select.w>=43.5&&select.h>=43.5,label+' real CSS row touch target');
  assert(c.title_font*ratio>=13.8&&c.meta_font*ratio>=11.8,label+' real CSS type size');
  const metaVisible=c.meta_visible!==false;
  assert(encloses(select,title)&&encloses(select,number)&&(!metaVisible||encloses(select,meta)),label+' visible row label bounds '+(i+1));
  assert(!overlaps(number,title)&&(!metaVisible||(!overlaps(title,meta)&&!overlaps(number,meta))),label+' distinct visible label boxes '+(i+1));
  if(c.status_text&&c.status_visible!==false)assert(!overlaps(title,css(s,c.status)),label+' title/status separation '+(i+1));
  assert(row.x>=list.x-1&&endX(row)<=endX(list)+1,label+' row horizontal clip '+(i+1));
  if(i)assert(endY(css(s,layout.cards[i-1].row))<row.y+1,label+' non-overlapping measured rows');
  assert.equal(c.delete_visible,Boolean(s.ui.slots_state[i].occupied),label+' empty slots have no delete action');
  if(c.delete_visible){
   const remove=css(s,c.delete);
   assert(remove.w>=43.5&&remove.h>=43.5&&!overlaps(select,remove)&&encloses(row,remove),label+' independent CSS delete target '+(i+1));
  }
 }
 if(layout.scroll_max<=1){
  const last=css(s,layout.cards[2].row);
  assert(footer.y-endY(last)<=40,label+' no old unused gap after the last save');
 }
 record('geometry '+label);
}

function modalGeometry(s){
 const data=s.ui.save_layout.dialog;
 assert(data&&s.ui.save_layout.modal_open,'actual deletion dialog snapshot missing');
 const safe=css(s,s.ui.save_layout.safe),panel=css(s,data.panel),body=css(s,data.body),footer=css(s,data.footer);
 assert(encloses(safe,panel)&&encloses(panel,body)&&encloses(panel,footer),'dialog remains in safe bounds');
 assert(body.h>=24,'deletion warning needs a readable body viewport');
 for(const key of ['delete_cancel','delete_confirm']){
  const button=css(s,s.ui.rects[key]);
  assert(encloses(panel,button)&&button.h>=43.5&&button.w>=43.5,'dialog action '+key+' has a real CSS touch target');
 }
 record('actual deletion modal bounds and warning viewport');
}
async function ensureCard(number){
 for(let attempt=0;attempt<14;attempt++){
  const s=await read(),layout=s.ui.save_layout,c=layout.cards[number-1];
  const row=css(s,c.row),list=css(s,layout.list);
  assert(row.h<=list.h+1,'a whole save row must fit its scroll viewport');
  if(encloses(list,row,1.5))return s;
  await page.mouse.move(list.x+list.w*0.40,list.y+list.h*0.50);
  await page.mouse.wheel(0,row.y<list.y?-240:240);
  await page.waitForTimeout(180);
 }
 throw new Error('Actual pointer scrolling cannot expose save slot '+number);
}
async function tap(key){
 if(/^(slot|delete)[1-3]$/.test(key))await ensureCard(Number(key.at(-1)));
 const s=await read();
 assert.equal(s.ui.visible[key],true,'cannot click hidden '+key);
 const point=s.ui[key];assert(Array.isArray(point),'missing actual target '+key);
 await page.mouse.click(point[0]*s.window[0],point[1]*s.window[1]);
 await page.waitForTimeout(180);
}
async function scenario(name){
 await page.evaluate(name=>window.__sjrpgSaveLayoutAction('scenario',name),name);
 await waitState(s=>s.review?.scenario===name&&s.review?.ready&&s.ui?.stage==='slots','scenario '+name);
 await page.waitForTimeout(200);
 return await read();
}
async function resize(width,height){
 await page.setViewportSize({width,height});
 await waitState(s=>s.window[0]===width&&s.window[1]===height&&s.ui?.viewport?.[0]>0&&Math.abs(s.ui.viewport[0]/s.ui.viewport[1]-width/height)<0.005,'completed main-window rotation');
 await page.waitForTimeout(220);
}
async function capture(name,inline=false){
 // UI probes are published after Godot drawing; allow Chrome to composite that frame too.
 await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
 await page.waitForTimeout(180);
 const state=await read();
 const png=path.join(out,name+'.png');
 await page.screenshot({path:png,type:'png',scale:'css',timeout:90000});
 captures.push({name,...state});
 if(inline){
  const jpeg=await page.screenshot({type:'jpeg',quality:75,scale:'css',timeout:90000});
  const encoded=jpeg.toString('base64');
  console.log('SJ_SAVE_LAYOUT_IMAGE_BEGIN '+name+' image/jpeg '+encoded.length);
  for(let offset=0;offset<encoded.length;offset+=16384)console.log('SJ_SAVE_LAYOUT_IMAGE_CHUNK '+name+' '+encoded.slice(offset,offset+16384));
  console.log('SJ_SAVE_LAYOUT_IMAGE_END '+name);
 }
}
async function preserve(expected,label){
 const s=await read();
 assert.equal(stateKey(s),expected,label+' changed save bytes or the live hero');
 assert.equal(s.review.screen,'selection',label+' unexpectedly launched or left selection');
}


function classGeometry(s,label){
 assert.equal(s.ui.stage,'class',label+' actual hero selection');
 const p=s.ui.class_layout;
 console.log('ENTRY_CLASS_LAYOUT_DIAGNOSTIC',JSON.stringify({label,stage:s.ui.stage,window:s.window,css_scale:p?.css_scale,heading:p?.heading,subtitle:p?.subtitle,back:p?.back,brand:p?.brand,visible:p?.visible,texts:p?.texts}));
 assert(p,label+' missing actual class geometry probe');
 assert.equal(p.class,s.ui.selected_class,label+' probe follows selected class');
 const win={x:0,y:0,w:s.window[0],h:s.window[1]},safe=css(s,p.safe),sheet=css(s,p.sheet);
 assert(encloses(win,safe)&&encloses(safe,sheet),label+' class sheet and safe area');
 const heading=css(s,p.heading),subtitle=css(s,p.subtitle),back=css(s,p.back),art=css(s,p.art),details=css(s,p.details);
 assert(encloses(safe,heading)&&encloses(safe,subtitle)&&!overlaps(heading,subtitle),label+' separate title/subtitle in safe area');
 assert(!overlaps(back,heading)&&encloses(safe,back),label+' back does not cover title '+JSON.stringify({stage:s.ui.stage,css_scale:p.css_scale,heading,back,visible:p.visible,texts:p.texts}));
 const tabs=['warrior','mage'].map(key=>css(s,p.tabs[key]));
 assert(!overlaps(tabs[0],tabs[1]),label+' independent class tabs');
 assert(tabs.every(tab=>!overlaps(details,tab)),label+' class information never overlaps a tab');
 if(p.tab_contents){
  for(const key of ['warrior','mage']){
   const content=p.tab_contents[key],tab=css(s,p.tabs[key]);
   const icon=css(s,content.icon),caption=css(s,content.label);
   assert(encloses(tab,icon)&&encloses(tab,caption)&&!overlaps(icon,caption),label+' real icon/caption group never overlaps '+key);
  }
 }else assert(captureBaseline,label+' missing measured live tab content');
 for(const rect of [...tabs,back,css(s,p.start),css(s,p.slotchange)]){
  assert(encloses(safe,rect)&&rect.w>=43.5&&rect.h>=43.5,label+' actual44CSS class targets');
 }
 assert(encloses(safe,art)&&encloses(safe,details),label+' art and details fit safe area');
 assert(!overlaps(css(s,p.start),css(s,p.slotchange)),label+' primary/secondary actions do not overlap');
 assert(!overlaps(details,css(s,p.start))&&!overlaps(details,css(s,p.slotchange)),label+' details never cover actions');
 if(p.portrait){
  assert(Math.max(...tabs.map(endY))<=art.y+2,label+' portrait tabs above artwork');
  assert(details.y>=art.y+art.h*0.45,label+' portrait information leaves the face and upper body visible');
  assert(endY(details)<=css(s,p.start).y+2,label+' portrait information before start');
 }
 const ratio=s.window[0]/s.ui.viewport[0];
 for(const key of ['heading','subtitle','name','role','description']){
  if(p.visible?.[key]===false)continue;
  assert(Number.isFinite(p.fonts?.[key])&&p.fonts[key]*ratio>=11.8,label+' actual readable '+key+' font');
  assert(String(p.texts?.[key]||'').trim(),label+' actual '+key+' text');
  if(['name','role','description'].includes(key)&&p.labels?.[key])assert(encloses(details,css(s,p.labels[key])),label+' '+key+' stays inside information');
 }
 assert(Array.isArray(p.stats)&&p.stats.length===2,label+' actual health/resource chips');
 for(const stat of p.stats){
  const box=css(s,stat.rect),text=css(s,stat.text_rect);
  assert(encloses(details,box)&&encloses(box,text),label+' stat chip/text remain inside information');
  assert(stat.font_size*ratio>=11.8&&String(stat.text||'').trim(),label+' actual readable stat text');
 }
 record('class geometry '+label);
}
function inspectVisual(label,callback){
 try{callback();console.log('ENTRY_VISUAL_CHECK_PASS '+label);}
 catch(error){visualFailures.push({label,error:String(error)});console.error('ENTRY_VISUAL_CHECK_FAIL '+label+' '+String(error));}
}
async function focusedVisual(){
 const sizes=[[390,844],[844,390],[320,568],[568,320],[344,883],[883,344],[768,896],[896,768],[800,800]];
 if(!classVisualOnly){
 for(const name of ['empty','mixed','full','corrupt','backup']){
  await resize(390,844);const before=stateKey(await scenario(name));
  if(name==='mixed'){await tap('slot3');await waitState(s=>s.ui.selected_slot===3,'selected mage save preview');}
  for(const [w,h]of sizes){
   await resize(w,h);const state=await read();
   await capture('entry-save-'+name+'-'+w+'x'+h,true);
   inspectVisual(name+' '+w+'x'+h,()=>geometry(state,name+' '+w+'x'+h));
   await preserve(before,name+' actual visual preview');
   if(name==='full'&&w>h){
    const footer=css(state,state.ui.save_layout.footer);
    await ensureCard(3);const last=await read();
    inspectVisual('full landscape last-row access',()=>{
     assert(encloses(css(last,last.ui.save_layout.list),css(last,last.ui.save_layout.cards[2].row),1.5),'actual last save row visible');
     assert.deepEqual(css(last,last.ui.save_layout.footer),footer,'scroll must not move fixed action footer');
    });
    await capture('entry-save-full-'+w+'x'+h+'-bottom',true);
   }
  }
 }
 await resize(390,844);await scenario('mixed');await tap('delete1');
 await waitState(s=>s.ui.save_layout.modal_open,'actual delete confirmation');
 const modalBefore=stateKey(await read());
 for(const [w,h]of sizes){
  await resize(w,h);await capture('entry-delete-'+w+'x'+h,true);
  const modalState=await read();inspectVisual('delete '+w+'x'+h,()=>modalGeometry(modalState));
 }
 await page.keyboard.press('Escape');
 await waitState(s=>!s.ui.save_layout.modal_open,'actual Escape cancel');
 await preserve(modalBefore,'cancelled visual delete');
 }
 await resize(390,844);const emptyBefore=stateKey(await scenario('empty'));
 await tap('continue');await waitState(s=>s.ui.stage==='class','actual new-hero selection');
 for(const [w,h]of [...sizes,[320,640]]){
  await resize(w,h);
  for(const cls of ['warrior','mage']){
   await tap(cls);await waitState(s=>s.ui.selected_class===cls&&s.ui.stage==='class','actual '+cls+' tab');
   const state=await read();await capture('entry-class-'+cls+'-'+w+'x'+h,true);
   if(captureBaseline&&!state.ui.class_layout)record('baseline actual class capture '+cls+' '+w+'x'+h+' (new geometry absent)');
   else inspectVisual(cls+' '+w+'x'+h,()=>classGeometry(state,cls+' '+w+'x'+h));
   await preserve(emptyBefore,'actual '+cls+' preview without creating a save');
  }
 }
 await tap('slots');await waitState(s=>s.ui.stage==='slots','class returns to actual saves');
 await preserve(emptyBefore,'class back returns without writing');
 assert.equal(errors.length,0,'unexpected runtime errors '+JSON.stringify(errors));
 assert.equal(visualFailures.length,0,'measured entry visual failures '+JSON.stringify(visualFailures));
 console.log('ENTRY_VISUAL_PASS '+JSON.stringify({checks:checks.length,captures:captures.length,errors:errors.length,baseline:captureBaseline}));
}

const idbDiagnostics={enabled:process.env.SJRPG_SAVE_IDB_DIAGNOSTICS==='1',engineLogRewrites:0};
if(idbDiagnostics.enabled){
 // Observe the otherwise discarded ErrnoError fields in this browser response only.
 // No FS calls, error handling, callbacks, transactions or production files change.
 await page.route('**/index.js',async route=>{
  const response=await route.fetch();let source=await response.text();let count=0;
  const detail=ref=>'JSON.stringify({name:'+ref+'.name,errno:'+ref+'.errno,code:'+ref+'.code,path:'+ref+'.path,stack:'+ref+'.stack,type:typeof '+ref+'})';
  source=source.replace(/Failed to save IDB file system: \$\{([$A-Za-z_][$\w]*)\.message\}/g,(_,ref)=>{
   count++;return 'Failed to save IDB file system: ${'+ref+'.message}; diagnostic=${'+detail(ref)+'}';
  });
  if(count===0)source=source.replace(/(["'])Failed to save IDB file system: \1\s*\+\s*([$A-Za-z_][$\w]*)\.message/g,(_,quote,ref)=>{
   count++;return quote+'Failed to save IDB file system: '+quote+'+'+ref+'.message+"; diagnostic="+'+detail(ref);
  });
  idbDiagnostics.engineLogRewrites+=count;
  console.log('SAVE_LAYOUT_IDB_LOG_INSTRUMENTED '+JSON.stringify({count,url:route.request().url()}));
  const headers={...response.headers()};delete headers['content-length'];delete headers['content-encoding'];
  await route.fulfill({status:response.status(),headers,body:source});
 });
}

try{
 console.log('SAVE_LAYOUT_BEGIN '+url.href);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 if(idbDiagnostics.enabled)assert.equal(idbDiagnostics.engineLogRewrites,1,'one exact Godot IDB error log must expose original error fields');
 const titleButtons=await page.evaluate(()=>window.__sjrpgTitleButtons);
 if(titleButtons){
  const point=titleButtons[captureBaseline?'new_game':'load_game'];
  await page.mouse.click(point[0]*390,point[1]*844);
 }else await page.locator('#entry-start').click();
 await waitState(s=>s.review?.ready&&s.review?.screen==='selection'&&s.ui?.save_layout,'live save selection',90000);
 if(entryVisualOnly){await focusedVisual();}else{
 const sizes=[[390,844],[844,390],[568,320],[320,640],[360,640],[390,844]];
 const cases=['mixed','full','empty','corrupt','backup','long'];
 for(const name of cases){
  await resize(390,844);
  const before=stateKey(await scenario(name));
  for(const [width,height] of sizes){
   await resize(width,height);
   let s=await read();geometry(s,name+' '+width+'x'+height);
   const fixedFooter=css(s,s.ui.save_layout.footer);
   await ensureCard(3);s=await read();
   assert(encloses(css(s,s.ui.save_layout.list),css(s,s.ui.save_layout.cards[2].row),1.5),'last row must be reachable using actual wheel input');
   assert.deepEqual(css(s,s.ui.save_layout.footer),fixedFooter,'pointer scroll moved the footer');
   await preserve(before,name+' resize/scroll');
   const inline=(name==='full'&&((width===568&&height===320)||(width===844&&height===390)))||
    (width===390&&height===844&&captures.every(c=>c.name!==name+'-portrait')&&['mixed','empty','corrupt','backup','long'].includes(name));
   const captureName=width===390&&height===844?name+'-portrait':name+'-'+width+'x'+height;
   // Rotation-back is checked separately without replacing the first portrait proof.
   if(!captures.some(c=>c.name===captureName))await capture(captureName,inline);
  }
 }
 await resize(390,844);
 const emptyBefore=stateKey(await scenario('empty'));
 await tap('continue');
 await waitState(s=>s.ui.stage==='class'&&s.ui.selected_slot===1,'empty footer selects a new hero without writing');
 await preserve(emptyBefore,'empty footer hero preview');
 await tap('slots');
 await waitState(s=>s.ui.stage==='slots','return from empty footer preview');
 const corruptBefore=stateKey(await scenario('corrupt'));
 await tap('continue');
 assert.equal((await read()).ui.stage,'slots','unreadable saves must not launch or create');
 await preserve(corruptBefore,'unreadable footer is inert');
 let s=await scenario('mixed');const baseline=stateKey(s);
 for(const number of [1,3]){
  await tap('slot'+number);
  await waitState(s=>s.ui.selected_slot===number&&s.ui.stage==='slots','actual saved-row selection');
  await preserve(baseline,'saved-row preview '+number);
 }
 await tap('slot2');
 await waitState(s=>s.ui.selected_slot===2&&s.ui.stage==='class','actual empty-row hero choice');
 await preserve(baseline,'empty-row preview');
 await tap('warrior');
 await tap('slots');
 await waitState(s=>s.ui.stage==='slots','return from hero preview');
 await preserve(baseline,'class preview return');
 await tap('slot3');
 await waitState(s=>s.ui.selected_slot===3,'select a different save from deletion target');
 await tap('delete1');
 await waitState(s=>s.ui.save_layout.modal_open&&s.ui.focus==='delete_cancel','safe initial modal focus');
 modalGeometry(await read());
 await capture('delete-confirmation-portrait',true);
 // Enter initially cancels, never destroys the data.
 await page.keyboard.press('Enter');
 await waitState(s=>!s.ui.save_layout.modal_open&&s.ui.focus==='delete1','Enter cancels and restores target focus');
 await preserve(baseline,'initial Enter cancel');
 await tap('delete1');
 await waitState(s=>s.ui.save_layout.modal_open&&s.ui.focus==='delete_cancel','reopen modal');
 for(const key of ['Tab','Shift+Tab']){
  for(let count=0;count<12;count++){
   await page.keyboard.press(key);await page.waitForTimeout(90);
   s=await read();assert(s.ui.save_layout.modal_open&&s.ui.save_layout.modal_focus,'actual '+key+' escaped to a background control');
  }
 }
 s=await read();
 const panel=css(s,s.ui.save_layout.dialog.panel);
 const background=['back','continue','slot3'].filter(k=>s.ui.visible[k]&&s.ui.rects[k]&&Array.isArray(s.ui[k])).map(k=>({point:[s.ui[k][0]*s.window[0],s.ui[k][1]*s.window[1]],rect:css(s,s.ui.rects[k])})).find(target=>pointInside(target.point,target.rect)&&!pointInside(target.point,panel))?.point;
 assert(background,'normal portrait must have a background-only pointer location');
 await page.mouse.click(...background);await page.waitForTimeout(200);
 await preserve(baseline,'background click during confirmation');
 assert((await read()).ui.save_layout.modal_open,'background click must not act as dialog confirmation');
 await page.keyboard.press('Escape');
 await waitState(s=>!s.ui.save_layout.modal_open&&s.ui.focus==='delete1','Escape closes only modal and restores target focus');
 await preserve(baseline,'Escape cancel');
 await tap('delete1');
 await waitState(s=>s.ui.save_layout.modal_open&&s.ui.focus==='delete_cancel','reopen for intentional delete');
 await tap('delete_confirm');
 await waitState(s=>!s.ui.save_layout.modal_open&&!s.ui.slots_state[0].occupied&&s.ui.focus==='slot1','explicit deletion and row focus restoration');
 s=await read();
 const original=JSON.parse(baseline);
 for(const number of ['2','3'])assert.deepEqual(s.review.file_hashes[number],original.hashes[number],'deletion altered another slot '+number);
 assert(Object.values(s.review.file_hashes['1']).every(value=>value===''),'deleted primary/backup/temp files remain');
 assert.equal(s.ui.selected_slot,3,'deleting another slot changed the selected adventure');
 assert.equal(s.review.hero_class,original.hero);assert.equal(s.review.gold,original.gold);assert.equal(s.review.level,original.level);assert.equal(s.review.xp,original.xp);assert.equal(s.review.active_slot,original.active);
 record('actual modal pointer/Enter/Escape/Tab trap, named deletion and focus restore');

 // One actual Continue verifies the unchanged root launch path, after all preview assertions.
 await resize(568,320);await scenario('full');
 let touchState=await read();const touchBefore=stateKey(touchState),selectedBefore=touchState.ui.selected_slot;
 const touchList=css(touchState,touchState.ui.save_layout.list);
 const touchRow=css(touchState,touchState.ui.save_layout.cards[0].select);
 const touchX=Math.max(touchList.x+12,Math.min(touchRow.x+touchRow.w*0.6,endX(touchList)-12));
 const touchY=Math.min(endY(touchList)-8,Math.max(touchList.y+16,touchRow.y+touchRow.h*0.6));
 const previousScroll=touchState.ui.save_layout.scroll_value;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:touchX,y:touchY,id:7}]});
 for(let step=1;step<=15;step++){
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:touchX,y:touchY-step*7,id:7}]});
  await page.waitForTimeout(16);
 }
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await waitState(s=>s.ui.save_layout.scroll_value>previousScroll+5,'real finger drag over save-row button');
 touchState=await read();assert.equal(touchState.ui.selected_slot,selectedBefore,'swipe must not activate a save');
 await preserve(touchBefore,'touch drag preserves exact saved files');
 // Continue with real finger drags; a wheel fallback would hide the reported bug.
 for(let attempt=0;attempt<24;attempt++){
  touchState=await read();
  if(touchState.ui.save_layout.scroll_value>=touchState.ui.save_layout.scroll_max-2)break;
  const list=css(touchState,touchState.ui.save_layout.list);
  const x=list.x+list.w*.55,y=list.y+list.h*.8;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:7}]});
  for(let step=1;step<=8;step++){
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-list.h*.6*step/8,id:7}]});
   await page.waitForTimeout(30);
  }
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await page.waitForTimeout(450);
 }
 touchState=await read();
 assert(touchState.ui.save_layout.scroll_value>=touchState.ui.save_layout.scroll_max-2,'finger drags must reach the last save');
 const settledScroll=touchState.ui.save_layout.scroll_value;
 await page.waitForTimeout(1100);
 assert(Math.abs((await read()).ui.save_layout.scroll_value-settledScroll)<=2,'touch release must not snap back to the focused row');
 assert.equal((await read()).ui.selected_slot,selectedBefore,'repeated swipes must not select a row');
 await preserve(touchBefore,'touch-only bottom traversal');
 await capture('touch-scroll-last-save');record('actual finger drags reach the bottom and stay there without selection or deletion');
 await resize(390,844);await scenario('full');await tap('slot3');
 const expectedHero=(await read()).ui.slots_state[2];await tap('continue');
 await waitState(s=>s.review.screen==='adventure'&&s.adventure,'real Continue launches the selected adventure',90000);
 const continued=await read();assert.equal(continued.review.active_slot,3);assert.equal(continued.review.hero_class,expectedHero.class);assert.equal(continued.review.level,expectedHero.level);
 assert.equal(errors.length,0,'unexpected app/browser/GPU errors');
 record('actual selected adventure continuation');
 console.log('SAVE_LAYOUT_PASS '+JSON.stringify({checks:checks.length,captures:captures.length,errors:0}));
 }
}catch(error){
 failure=String(error);console.error('SAVE_LAYOUT_FAIL '+failure);
 await Promise.race([Promise.allSettled(errorDetails),new Promise(resolve=>setTimeout(resolve,1500))]);
 console.error('SAVE_LAYOUT_RUNTIME_ERRORS '+JSON.stringify(errors));
 try{console.error('SAVE_LAYOUT_FAILURE_STATE '+JSON.stringify(await read()));}catch(stateError){console.error('SAVE_LAYOUT_STATE_UNAVAILABLE '+String(stateError));}
 try{await capture('failure',true);}catch(captureError){console.error('Failure screenshot unavailable: '+String(captureError));}
 process.exitCode=1;
}finally{
 await writeFile(path.join(out,'proof.json'),JSON.stringify({url:url.href,entryVisualOnly,captureBaseline,visualFailures,idbDiagnostics,checks,captures,errors,failure,passed:failure===null&&errors.length===0},null,2));
 await browser.close();
}
