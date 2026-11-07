#!/usr/bin/env node
// Real exported Godot UI in a fresh browser profile. The fixture only prepares test files.
import assert from 'node:assert/strict';
import path from 'node:path';
import {mkdir,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';

const {chromium}=createRequire(import.meta.url)('playwright');
const url=new URL(process.argv[2]||'http://127.0.0.1:8767/');
url.searchParams.set('save_layout_review','1');
url.searchParams.set('quality','low');
const out=path.resolve(process.argv[3]||'build/save-layout-review');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
const page=await context.newPage();
const errors=[];const captures=[];const checks=[];let failure=null;
const cdp=await context.newCDPSession(page);await cdp.send('Log.enable');
const bad=/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/;
page.on('pageerror',error=>errors.push({kind:'page',text:String(error)}));
page.on('console',message=>{if(message.type()==='error'||bad.test(message.text()))errors.push({kind:'console',text:message.text()});});
cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error'||bad.test(entry.text))errors.push({kind:'browser',text:entry.text});});

const read=()=>page.evaluate(()=>({ui:window.__sjrpgClassButtons,review:window.__sjrpgSaveLayoutReview,window:[innerWidth,innerHeight],adventure:window.__sjrpgAdventureReady===true}));
const stateKey=s=>JSON.stringify({hashes:s.review.file_hashes,hero:s.review.hero_class,gold:s.review.gold,level:s.review.level,xp:s.review.xp,active:s.review.active_slot});
function record(name){checks.push(name);}
async function waitState(predicate,label,timeout=15000){
 const until=Date.now()+timeout;
 let last;
 while(Date.now()<until){
  assert.equal(errors.length,0,'unexpected runtime error while waiting for '+label);
  last=await read();
  if(last.review?.fixture_error)throw new Error(last.review.fixture_error);
  if(predicate(last))return last;
  await page.waitForTimeout(100);
 }
 throw new Error('Timed out: '+label+'; last stage='+last?.ui?.stage+' focus='+last?.ui?.focus);
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
 assert(layout&&Array.isArray(layout.cards)&&layout.cards.length===4,label+' must expose all four source rows');
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
 for(let i=0;i<4;i++){
  const c=layout.cards[i],row=css(s,c.row),select=css(s,c.select),title=css(s,c.title),meta=css(s,c.meta),number=css(s,c.number);
  assert.equal(c.slot,i+1);assert(c.title_text&&c.meta_text,label+' actual title/metadata');
  assert(select.w>=43.5&&select.h>=43.5,label+' real CSS row touch target');
  assert(c.title_font*ratio>=13.8&&c.meta_font*ratio>=11.8,label+' real CSS type size');
  assert(encloses(select,title)&&encloses(select,meta)&&encloses(select,number),label+' row label bounds '+(i+1));
  assert(!overlaps(title,meta)&&!overlaps(number,title)&&!overlaps(number,meta),label+' distinct label boxes '+(i+1));
  if(c.status_text)assert(!overlaps(title,css(s,c.status)),label+' title/status separation '+(i+1));
  assert(row.x>=list.x-1&&endX(row)<=endX(list)+1,label+' row horizontal clip '+(i+1));
  if(i)assert(endY(css(s,layout.cards[i-1].row))<row.y+1,label+' non-overlapping measured rows');
  assert.equal(c.delete_visible,Boolean(s.ui.slots_state[i].occupied),label+' empty slots have no delete action');
  if(c.delete_visible){
   const remove=css(s,c.delete);
   assert(remove.w>=43.5&&remove.h>=43.5&&!overlaps(select,remove)&&encloses(row,remove),label+' independent CSS delete target '+(i+1));
  }
 }
 if(layout.scroll_max<=1){
  const last=css(s,layout.cards[3].row);
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
 if(/^(slot|delete)[1-4]$/.test(key))await ensureCard(Number(key.at(-1)));
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
 await waitState(s=>s.window[0]===width&&s.window[1]===height&&s.ui?.viewport?.[0]>0&&((s.ui.viewport[0]>s.ui.viewport[1])===(width>height)),'real main-window rotation');
 await page.waitForTimeout(220);
}
async function capture(name,inline=false){
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

try{
 console.log('SAVE_LAYOUT_BEGIN '+url.href);
 await page.goto(url.href,{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 await page.locator('#entry-start').click();
 await waitState(s=>s.review?.ready&&s.review?.screen==='selection'&&s.ui?.save_layout,'live save selection',90000);
 const sizes=[[390,844],[844,390],[568,320],[320,640],[360,640],[390,844]];
 const cases=['mixed','full','empty','corrupt','backup','long'];
 for(const name of cases){
  await resize(390,844);
  const before=stateKey(await scenario(name));
  for(const [width,height] of sizes){
   await resize(width,height);
   let s=await read();geometry(s,name+' '+width+'x'+height);
   const fixedFooter=css(s,s.ui.save_layout.footer);
   await ensureCard(4);s=await read();
   assert(encloses(css(s,s.ui.save_layout.list),css(s,s.ui.save_layout.cards[3].row),1.5),'last row must be reachable using actual wheel input');
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
 for(const number of ['2','3','4'])assert.deepEqual(s.review.file_hashes[number],original.hashes[number],'deletion altered another slot '+number);
 assert(Object.values(s.review.file_hashes['1']).every(value=>value===''),'deleted primary/backup/temp files remain');
 assert.equal(s.ui.selected_slot,3,'deleting another slot changed the selected adventure');
 assert.equal(s.review.hero_class,original.hero);assert.equal(s.review.gold,original.gold);assert.equal(s.review.level,original.level);assert.equal(s.review.xp,original.xp);assert.equal(s.review.active_slot,original.active);
 record('actual modal pointer/Enter/Escape/Tab trap, named deletion and focus restore');

 // Keyboard traversal must expose offscreen cards through the real ScrollContainer.
 await resize(568,320);await scenario('full');
 const keyboardBefore=stateKey(await read());
 await tap('slot1');let sawLast=false;
 for(let count=0;count<22;count++){
  await page.keyboard.press('Tab');await page.waitForTimeout(80);
  s=await read();
  if(/^slot[1-4]$/.test(s.ui.focus)){
   const index=Number(s.ui.focus.at(-1))-1;
   assert(encloses(css(s,s.ui.save_layout.list),css(s,s.ui.save_layout.cards[index].select),1.5),'keyboard focus remains clipped by footer/list');
   sawLast||=index===3;
  }
 }
 assert(sawLast,'Tab traversal never reached slot4');
 await preserve(keyboardBefore,'short-window keyboard traversal');
 record('actual short-window focus scrolling');

 // One actual Continue verifies the unchanged root launch path, after all preview assertions.
 await resize(390,844);await scenario('full');await tap('slot3');
 const expectedHero=(await read()).ui.slots_state[2];await tap('continue');
 await waitState(s=>s.review.screen==='adventure'&&s.adventure,'real Continue launches the selected adventure',90000);
 const continued=await read();assert.equal(continued.review.active_slot,3);assert.equal(continued.review.hero_class,expectedHero.class);assert.equal(continued.review.level,expectedHero.level);
 assert.equal(errors.length,0,'unexpected app/browser/GPU errors');
 record('actual selected adventure continuation');
 console.log('SAVE_LAYOUT_PASS '+JSON.stringify({checks:checks.length,captures:captures.length,errors:0}));
}catch(error){
 failure=String(error);console.error('SAVE_LAYOUT_FAIL '+failure);
 try{await capture('failure',true);}catch(captureError){console.error('Failure screenshot unavailable: '+String(captureError));}
 process.exitCode=1;
}finally{
 await writeFile(path.join(out,'proof.json'),JSON.stringify({url:url.href,checks,captures,errors,failure,passed:failure===null&&errors.length===0},null,2));
 await browser.close();
}
