#!/usr/bin/env node
import {inspectionUrl} from './review/inspection_url.mjs';
// Virtual standard Xbox device -> navigator.getGamepads -> Godot's real web input.
// No physical-controller claim, injected Godot action, or direct gameplay-method call.
import assert from 'node:assert/strict';
import path from 'node:path';
import {mkdir,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=inspectionUrl(process.argv[2]||'http://127.0.0.1:8784/');
base.searchParams.set('gamepad_review','1');base.searchParams.set('quality','low');base.searchParams.set('at','npc_nw');
const out=path.resolve(process.argv[3]||'build/gamepad-review');await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const proof={device:'virtual standard Xbox API device',physical_device:false,cases:[],passed:false};
let anyFailure=false;
for(const profile of [{name:'portrait-mage-continue',width:390,height:844,dpr:1,newGame:false},{name:'landscape-warrior-new',width:844,height:390,dpr:2,newGame:true}]){
 const c={profile,checks:[],captures:[],errors:[]};proof.cases.push(c);
 const context=await browser.newContext({viewport:{width:profile.width,height:profile.height},deviceScaleFactor:profile.dpr,hasTouch:true});
 const page=await context.newPage();
 const bad=/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/;
 page.on('pageerror',e=>c.errors.push({kind:'page',text:String(e)}));
 page.on('console',m=>{if(m.type()==='error'||bad.test(m.text()))c.errors.push({kind:'console',text:m.text()});});
 const cdp=await context.newCDPSession(page);await cdp.send('Log.enable');
 cdp.on('Log.entryAdded',({entry})=>{if(entry.level==='error'||bad.test(entry.text))c.errors.push({kind:'browser',text:entry.text});});
 await page.addInitScript(({releaseForFresh})=>{
  const pad={id:'Xbox 360 Controller (STANDARD GAMEPAD Vendor: 045e Product: 028e)',index:0,connected:false,mapping:'standard',timestamp:0,axes:[0,0,0,0],buttons:Array.from({length:17},()=>({pressed:false,touched:false,value:0})),vibrationActuator:null};
  const stamp=()=>{pad.timestamp=performance.now();};
  const event=name=>{const e=new Event(name);Object.defineProperty(e,'gamepad',{value:pad});window.dispatchEvent(e);};
  Object.defineProperty(navigator,'getGamepads',{configurable:true,value:()=>pad.connected?[pad]:[]});
  window.__sjrpgVirtualXbox={
   connect(){pad.connected=true;stamp();event('gamepadconnected');},
   disconnect(){pad.connected=false;stamp();event('gamepaddisconnected');},
   button(index,value){Object.assign(pad.buttons[index],{value,pressed:value>=.55,touched:value>0});stamp();},
   axis(index,value){pad.axes[index]=value;stamp();},
   neutral(){pad.axes.fill(0);for(const b of pad.buttons)Object.assign(b,{pressed:false,touched:false,value:0});stamp();},
   snapshot(){return JSON.parse(JSON.stringify(pad));}
  };
  window.__sjrpgVirtualXboxEntryTrace=[];let released=false,fresh=false;
  new MutationObserver(()=>{
   const state=window.__sjrpgEntryLoading;
   if(!releaseForFresh||!state?.visible)return;
   if(!released&&state.phase==='load'){
    released=true;window.__sjrpgVirtualXbox.button(0,0);
    window.__sjrpgVirtualXboxEntryTrace.push({kind:'release-entry-A',epoch:performance.timeOrigin+performance.now(),phase:state.phase,native_ready:window.__sjrpgAdventureReady===true,visible:state.visible});
   }
   if(released&&!fresh&&state.phase==='ready'&&window.__sjrpgAdventureReady===true){
    fresh=true;window.__sjrpgVirtualXbox.button(2,1);
    window.__sjrpgVirtualXboxEntryTrace.push({kind:'fresh-X-after-native-ready',epoch:performance.timeOrigin+performance.now(),phase:state.phase,native_ready:true,visible:state.visible});
   }
  }).observe(document,{attributes:true,childList:true,subtree:true});
 },{releaseForFresh:!profile.newGame});
 const read=()=>page.evaluate(()=>({review:window.__sjrpgGamepadReview,ui:window.__sjrpgClassButtons,loading:window.__sjrpgEntryLoading,adventure:window.__sjrpgAdventureReady===true,title:window.__sjrpgTitleReady,entry:window.__sjrpgEntryReady,window:[innerWidth,innerHeight],dpr:devicePixelRatio,virtual:window.__sjrpgVirtualXbox.snapshot(),entry_trace:window.__sjrpgVirtualXboxEntryTrace}));
 async function wait(predicate,label,timeout=15000){
  const end=Date.now()+timeout;let last;
  while(Date.now()<end){
   assert.equal(c.errors.length,0,'runtime errors '+JSON.stringify(c.errors));last=await read();
   assert(!last.review?.error,last.review?.error);if(predicate(last))return last;
   await page.waitForTimeout(80);
  }
  throw Error('Timed out '+label+' '+JSON.stringify(last));
 }
 const button=(index,value)=>page.evaluate(([i,v])=>window.__sjrpgVirtualXbox.button(i,v),[index,value]);
 const axis=(index,value)=>page.evaluate(([i,v])=>window.__sjrpgVirtualXbox.axis(i,v),[index,value]);
 async function neutral(){await page.evaluate(()=>window.__sjrpgVirtualXbox.neutral());await wait(s=>s.review?.pad?.armed,'neutral input armed');await page.waitForTimeout(140);}
 async function tap(index){await button(index,1);await page.waitForTimeout(180);await button(index,0);await page.waitForTimeout(180);}
 async function focusTo(predicate,label){
  let s=await wait(s=>s.review?.navigation?.focus_inside,'actual scoped focus for '+label);
  const maximum=Math.max(8,Math.min(90,Number(s.review.navigation.targets)+3));
  for(let i=0;i<maximum;i++){
   s=await read();if(predicate(s))return s;
   await tap(13); // Standard Xbox D-pad down, through the engine.
  }
  throw Error('Real D-pad traversal could not reach '+label+' '+JSON.stringify((await read()).review?.navigation));
 }
 function focused(s){
  const n=s.review.navigation;assert(n?.focus_inside,'focused real Control belongs to current scope');
  const [x,y,w,h]=n.focus_rect,[vw,vh]=s.review.viewport;
  assert(w>0&&h>0&&x>=-1&&y>=-1&&x+w<=vw+2&&y+h<=vh+2,'actual focused target lies inside viewport');
 }
 function record(label){c.checks.push(label);console.log('GAMEPAD_CHECK_PASS '+JSON.stringify({profile:profile.name,label}));}
 async function capture(suffix){
  const name=profile.name+'-'+suffix,data=await page.screenshot({type:'jpeg',quality:78,scale:'css'});
  await writeFile(path.join(out,name+'.jpg'),data);const b=data.toString('base64');
  console.log('SJ_GAMEPAD_IMAGE_BEGIN '+name+' image/jpeg '+b.length);
  for(let i=0;i<b.length;i+=16384)console.log('SJ_GAMEPAD_IMAGE_CHUNK '+name+' '+b.slice(i,i+16384));
  console.log('SJ_GAMEPAD_IMAGE_END '+name);c.captures.push({name,state:await read()});
 }
 const panelIs=(s,file)=>s.review?.panel?.script?.endsWith('/'+file+'.gd');
 async function openPanel(index,file){
  await neutral();await tap(index);const s=await wait(s=>panelIs(s,file)&&s.review.paused&&s.review.navigation.focus_inside,'actual '+file);
  focused(s);return s;
 }
 async function closePanel(){
  await neutral();await tap(1);await wait(s=>!s.review.panel?.script&&!s.review.paused,'actual B back closes panel');
  await neutral();
 }
 try{
  console.log('GAMEPAD_STAGE '+JSON.stringify({profile:profile.name,stage:'boot'}));
  await page.goto(base.href,{waitUntil:'domcontentloaded'});
  await wait(s=>s.review?.ready&&s.title&&s.entry,'isolated actual title',90000);
  await page.evaluate(()=>window.__sjrpgVirtualXbox.connect());
  await wait(s=>s.review.pad.active_device===0&&s.review.pad.armed,'real Godot detects virtual standard device');
  await tap(0);await wait(s=>s.review.screen==='selection'&&s.ui?.stage==='slots','A opens actual save selection');
  let s=await wait(s=>s.review.navigation.focus_inside,'save focus');focused(s);
  const originalFiles=s.review.file_hashes;
  await focusTo(s=>s.ui.focus==='slot2','empty save2');await tap(0);
  await wait(s=>s.ui.stage==='class'&&s.ui.selected_slot===2,'A selects actual empty save');
  await focusTo(s=>s.ui.focus==='warrior','warrior class');await tap(0);
  await wait(s=>s.ui.selected_class==='warrior','A chooses actual warrior');
  assert.deepEqual((await read()).review.file_hashes,originalFiles,'class preview must not write any save');
  if(profile.newGame){
   await focusTo(s=>s.ui.focus==='start','new warrior start');
   // Hold A through real entry. Loading/context changes must consume it until release.
   await button(0,1);
  }else{
   await tap(1);await wait(s=>s.ui.stage==='slots','B returns from class preview');
   await focusTo(s=>s.ui.focus==='slot1','saved mage');await tap(0);
   await focusTo(s=>s.ui.focus==='continue','Continue');await button(0,1);
  }
  s=await wait(s=>s.adventure&&s.review.native_ready&&!s.loading?.visible,'actual selected native game',90000);
  assert.equal(s.review.class,profile.newGame?'warrior':'mage');assert.equal(s.review.slot,profile.newGame?2:1);
  assert.equal(s.review.player.serial,0,'entry input must not leak an attack through loading');
  if(!profile.newGame){
   assert(s.entry_trace.some(e=>e.kind==='release-entry-A'),'saved entry A really released during loading');
   assert(s.entry_trace.some(e=>e.kind==='fresh-X-after-native-ready'&&e.native_ready&&e.visible),'fresh actual X injected after native ready but before DOM dismissal');
   assert.equal(s.virtual.buttons[2].pressed,true,'fresh loading X remains physically held at exit');
  }
  c.entry_trace=s.entry_trace;
  await page.waitForTimeout(300);
  assert.equal((await read()).review.player.serial,0,'held entry A remains gated in live game');
  await neutral();
  record('real pad title/save/class/Continue or New; preview files preserved; held A entry gate');
  console.log('GAMEPAD_STAGE '+JSON.stringify({profile:profile.name,stage:'live'}));
  await neutral();
  assert.equal((await read()).review.near,'상인','legal merchant entry remains within real interaction distance');
  await button(6,.9);await wait(s=>panelIs(s,'bag_panel')&&s.review.panel.shopping,'LT opens actual merchant');
  await neutral();focused(await wait(s=>s.review.navigation.focus_inside,'merchant focus'));await closePanel();record('LT actual merchant interaction');

  let origin=(await read()).review.player.position;
  await axis(0,.1);await axis(1,-.1);await page.waitForTimeout(450);s=await read();
  assert(Math.hypot(s.review.player.position[0]-origin[0],s.review.player.position[1]-origin[1])<.5,'real deadzone blocks stick drift');
  await axis(1,0);await axis(0,.85);
  await wait(s=>Math.hypot(s.review.player.position[0]-origin[0],s.review.player.position[1]-origin[1])>10,'actual stick movement');
  await neutral();await axis(2,0);await axis(3,-.85);
  await wait(s=>Math.abs(Math.atan2(Math.sin(s.review.player.facing+Math.PI/2),Math.cos(s.review.player.facing+Math.PI/2)))<.08,'right stick actual aim');
  await neutral();record('real deadzone, spatial movement and right-stick aim');

  let serial=(await read()).review.player.serial;
  await button(0,1);await wait(s=>s.review.player.serial>=serial+2,'actual held A repeats primary',8000);
  await neutral();await wait(s=>s.review.player.attack_time<=0,'primary animation completes');
  if(!profile.newGame){
   for(const [index,id]of [[2,'fireball'],[3,'frostNova'],[5,'nova'],[7,'lightning']]){
    await button(index,index===7?.9:1);
    await wait(s=>(s.review.player.cooldowns[id]||0)>0,'actual auxiliary '+id);
    await neutral();await wait(s=>s.review.player.attack_time<=0,'auxiliary animation completes');
   }
   record('X/Y/RB/RT cast all four actual equipped spells');
   const manaBefore=(await read()).review.mana_potions;
   await tap(12);await wait(s=>s.review.mana_potions===manaBefore-1,'D-pad up actual mana potion');
  }
  serial=(await read()).review.player.serial;origin=(await read()).review.player.position;
  await button(1,1);await wait(s=>s.review.player.serial>serial&&s.review.player.roll_time>0,'actual B dodge');
  await neutral();await wait(s=>s.review.player.roll_time<=0,'dodge completes');
  s=await read();assert(Math.hypot(s.review.player.position[0]-origin[0],s.review.player.position[1]-origin[1])>8,'real dodge movement');
  record('held primary and B actual dodge');
  s=await wait(s=>s.review.hints?.visible&&s.review.hints.glyphs?.length>=12,'actual drawn Xbox HUD glyphs');
  const expected={slot0:'A',slot1:'X',slot2:'Y',slot3:'RB',slot4:'RT',roll:'B',potion_hp:'LB',bar_gear:'Menu'};
  for(const [name,text]of Object.entries(expected))assert(s.review.hints.glyphs.some(g=>g.name===name&&g.text===text),'actual drawn Xbox glyph '+name);
  for(const g of s.review.hints.glyphs){
   const [x,y,w,h]=g.rect,[vw,vh]=s.review.viewport;
   assert(g.font_size*s.window[0]/vw>=11.95,'actual Xbox glyph font is at least12CSS '+g.name);
   assert(x>=-1&&y>=-1&&x+w<=vw+2&&y+h<=vh+2,'drawn Xbox glyph remains inside viewport '+g.name);
  }
  await capture('pad-hud');


  await openPanel(14,'bag_panel');
  let before=(await read()).review.navigation.focus_key;await tap(13);
  s=await read();focused(s);if(s.review.navigation.targets>1)assert.notEqual(s.review.navigation.focus_key,before,'D-pad changes actual bag focus');
  await closePanel();record('bag actual focus and B back');
  await openPanel(15,'journal_panel');await closePanel();record('quest journal actual focus and B back');
  await openPanel(8,'map_panel');await closePanel();record('View opens actual map and B closes');

  await openPanel(13,'skill_tree_panel');
  await focusTo(s=>String(s.review.navigation.focus_key).startsWith('skill:'),'actual skill graph node');
  s=await read();const selected=s.review.panel.selected;assert(selected,'focused skill selects actual detail');
  await tap(0);
  s=await wait(s=>/^(learn:|assign:)/.test(s.review.navigation.focus_key),'A focuses an actual enabled skill detail action');
  focused(s);assert(panelIs(s,'skill_tree_panel'),'A navigates actual skill detail without escaping scope');
  await capture('skill-focus');
  await neutral();await tap(1);
  await wait(s=>panelIs(s,'skill_tree_panel')&&String(s.review.navigation.focus_key).startsWith('skill:'),'first B returns from detail to graph');
  await closePanel();record('skill graph focus, real A detail action, first B graph and second B close');

  await openPanel(9,'settings_panel');
  await focusTo(s=>s.review.navigation.focus_key==='setting:배경 음악','music setting');
  const music=(await read()).review.preferences.music;
  await tap(0);await wait(s=>s.review.preferences.music!==music,'A toggles actual music setting');
  s=await read();before=s.review.navigation.focus_key;const scroll=s.review.panel.scroll;
  if(s.review.panel.scroll_max>0){
   const direction=scroll+3<s.review.panel.scroll_max?1:-1;
   await axis(3,.9*direction);await wait(s=>Math.abs(s.review.panel.scroll-scroll)>2,'right stick scrolls actual settings');
   await axis(3,0);await page.waitForTimeout(220);
   assert.equal((await read()).review.navigation.focus_key,before,'right-stick scroll must preserve focus');
  }
  await tap(12);focused(await read());
  await capture('settings-focus');await closePanel();record('Menu settings, A actual toggle, RS real scroll, B back');

  // Disconnect mid-hold and reconnect with controls already down: no synthetic release action.
  await button(0,1);await axis(0,.7);await page.waitForTimeout(200);
  await page.evaluate(()=>window.__sjrpgVirtualXbox.disconnect());
  await wait(s=>s.review.pad.active_device<0&&s.review.pad.held_slots.length===0,'disconnect clears actual pad owner');
  await page.waitForTimeout(450);
  await page.evaluate(()=>window.__sjrpgVirtualXbox.connect());
  await wait(s=>s.review.pad.active_device===0&&!s.review.pad.armed,'held reconnection neutral gate');
  s=await read();serial=s.review.player.serial;origin=s.review.player.position;
  await page.waitForTimeout(350);s=await read();
  assert.equal(s.review.player.serial,serial,'held reconnect cannot cast');
  assert(Math.hypot(s.review.player.position[0]-origin[0],s.review.player.position[1]-origin[1])<.5,'held reconnect cannot move');
  await neutral();record('disconnect clears held input and reconnect requires real neutral');

  // Real keyboard and touch input switch the displayed modality while the pad remains connected.
  origin=(await read()).review.player.position;await page.keyboard.down('d');
  await wait(s=>!s.review.pad.using_gamepad&&Math.hypot(s.review.player.position[0]-origin[0],s.review.player.position[1]-origin[1])>5,'actual keyboard fallback');
  await page.keyboard.up('d');await wait(s=>s.review.hints?.visible===false&&s.review.hints.glyphs.length===0,'actual Xbox glyphs disappear after keyboard input');await capture('keyboard-fallback');
  const beforeTouch=await read();
  // This is a live world: if an enemy killed the hero during the preceding
  // navigation checks, wait for the existing automatic respawn, never mutate HP.
  const touchReady=await wait(s=>!s.review.player.dead&&s.review.player.hp>0&&!s.review.paused&&!s.review.panel?.script&&s.review.player.attack_time<=0,'actual living idle player before touch fallback',8000);
  c.touch_prerequisite={dead_before:beforeTouch.review.player.dead,hp_before:beforeTouch.review.player.hp,dead_at_gesture:touchReady.review.player.dead,hp_at_gesture:touchReady.review.player.hp,position:touchReady.review.player.position};
  s=await read();const [tx,ty]=s.review.touch.slot0,[vw,vh]=s.review.viewport;
  serial=s.review.player.serial;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:tx*s.window[0]/vw,y:ty*s.window[1]/vh}]});
  await wait(s=>!s.review.player.dead&&s.review.player.hp>0&&s.review.player.serial>serial&&s.review.player.attack_time>0&&!s.review.pad.using_gamepad,'actual touch primary fallback',6000);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await wait(s=>s.review.hints?.visible===false,'actual Xbox glyphs remain hidden after touch');
  record('real keyboard and touch fallback with pad still connected');
  c.final=await read();assert.equal(c.errors.length,0);
  console.log('GAMEPAD_CASE_PASS '+JSON.stringify({profile:profile.name,checks:c.checks.length,captures:c.captures.length,errors:0,virtual:true}));
 }catch(error){
  anyFailure=true;c.failure=String(error);console.error('GAMEPAD_CASE_FAIL '+profile.name+' '+String(error));
  try{c.failure_state=await read();await capture('failure');}catch(e){c.diagnostic_error=String(e);}
 }finally{
  await writeFile(path.join(out,'proof.json'),JSON.stringify(proof,null,2));
  await context.close();
 }
}
proof.passed=!anyFailure&&proof.cases.length===2&&proof.cases.every(c=>c.errors.length===0);
await writeFile(path.join(out,'proof.json'),JSON.stringify(proof,null,2));
console.log((proof.passed?'GAMEPAD_PASS ':'GAMEPAD_FAIL ')+JSON.stringify({profiles:proof.cases.length,checks:proof.cases.reduce((n,c)=>n+c.checks.length,0),virtual:true}));
await browser.close();if(!proof.passed)process.exitCode=1;
