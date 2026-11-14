#!/usr/bin/env node
// 실제 입력으로 패널을 연 뒤 대표 화면 비율을 한 게임 세션에서 검수한다.
// Fold 항목은 비율 모사이며 특정 실기기 검증을 뜻하지 않는다.
import {inspectionUrl} from './review/inspection_url.mjs';
import {createRequire} from 'node:module';
import {mkdir, writeFile} from 'node:fs/promises';
const {chromium} = createRequire(import.meta.url)('playwright');
const base = process.argv[2] || 'http://127.0.0.1:8765/3d/';
const out = process.argv[3] || 'build/reports/mobile-panels';
const sizes = (process.env.PANEL_VIEWPORTS || '390x844,568x320,344x883,768x896,896x768,800x800')
 .split(',').map(size => size.split('x').map(Number));
const panels = (process.env.PANEL_TYPES || 'bag,skills,journal,settings,pause').split(',');
const detailReview = process.env.PANEL_DETAIL_REVIEW === '1';
await mkdir(out, {recursive:true});
const browser = await chromium.launch({headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const results = [], errors = [], failures = [], detailFlow = [];
let page;
const contains = (a,b,e=1.1) => b[0]>=a[0]-e && b[1]>=a[1]-e && b[0]+b[2]<=a[0]+a[2]+e && b[1]+b[3]<=a[1]+a[3]+e;
const area = r => r[2]*r[3];
try {
 const context = await browser.newContext({viewport:{width:sizes[0][0],height:sizes[0][1]},isMobile:true,hasTouch:true,deviceScaleFactor:1});
 page = await context.newPage();
 page.on('pageerror', error => errors.push(String(error)));
 page.on('console', message => {if (/SCRIPT ERROR|^ERROR:/.test(message.text())) errors.push(message.text());});
 const cdp = await context.newCDPSession(page);
 const read = () => page.evaluate(() => window.__sjrpgPanelLayout);
 const fresh = async previous => {
  await page.waitForFunction(frame => window.__sjrpgPanelLayout?.frame > frame, previous ?? -1, {timeout:15000});
  return read();
 };
 const point = (state, rect) => ({x:(rect[0]+rect[2]/2)/state.viewport[0]*page.viewportSize().width,y:(rect[1]+rect[3]/2)/state.viewport[1]*page.viewportSize().height});
 const tapRect = async (state, rect) => {const p=point(state,rect);await page.touchscreen.tap(p.x,p.y);};
 async function swipe(state, rect, dy) {
  const p=point(state,rect);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...p,id:1}]});
  await page.waitForTimeout(60);
  for(let step=1;step<=6;step++) {
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:p.x,y:p.y+dy*step/6,id:1}]});
   await page.waitForTimeout(25);
  }
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await page.waitForTimeout(300);
  return fresh(state.frame);
 }
 const url=inspectionUrl(base);url.searchParams.set('ui_layout_review','1');url.searchParams.set('gamepad_review','1');
 if(detailReview)url.searchParams.set('expedition_review','1');
 await page.goto(url.href);
 await page.waitForFunction(()=>window.__sjrpgTitleReady && window.__sjrpgEntryReady,null,{timeout:120000});
 const title=await page.evaluate(()=>window.__sjrpgTitleButtons?.new_game);
 if(title) await page.touchscreen.tap(title[0]*sizes[0][0],title[1]*sizes[0][1]);
 else await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassSelectReady && window.__sjrpgClassButtons,null,{timeout:30000});
 async function tapEntry(key) {
  const p=await page.evaluate(name=>window.__sjrpgClassButtons[name],key);
  if(!p) throw new Error(`Missing actual entry button ${key}`);
  const size=page.viewportSize();await page.touchscreen.tap(p[0]*size.width,p[1]*size.height);
  await page.waitForTimeout(350);
 }
 if(await page.evaluate(()=>window.__sjrpgClassButtons.stage)==='slots') {
  await tapEntry('slot2');
  await page.waitForFunction(()=>window.__sjrpgClassButtons.stage==='class');
 }
 await tapEntry('mage');await tapEntry('start');
 await page.waitForFunction(()=>window.__sjrpgAdventureReady && window.__sjrpg3dReady && window.__sjrpgPanelLayout?.native_ready && window.__sjrpgEntryLoading?.visible===false,null,{timeout:120000});
 async function closePanel() {
  let state=await read();if(!state.panel?.rect)return;
  const footer=state.panel.controls.find(c=>c.kind==='button' && c.in_footer && !c.disabled && /^(모험 계속하기|탐험 계속하기|계속 탐험하기|닫기|돌아가기|대화 마치기|취소 \/ 돌아가기)$/.test(c.text) && area(c.visible_rect)>0);
  if(footer)await tapRect(state,footer.visible_rect);
  else if(state.panel.close?.length===4)await tapRect(state,state.panel.close);
  else throw new Error(`Panel has neither an actual resume/close footer nor visible close X: ${state.panel.type}`);
  await page.waitForFunction(()=>!window.__sjrpgPanelLayout?.panel?.rect,null,{timeout:15000});
 }
 // 게임 메뉴는 키보드 단축키 없이 실제 HUD 터치 위치로 연다.
 async function openPanel(kind) {
  await closePanel();
  if(kind==='pause') {
   await page.evaluate(()=>document.querySelector('canvas').blur());
  } else if(['bag','skills','journal','settings'].includes(kind)) {
   const key={bag:'bar_bag',skills:'bar_skills',journal:'bar_quests',settings:'bar_gear'}[kind];
   const state=await read(),p=state.hud_targets[key],size=page.viewportSize();
   if(!p)throw new Error(`Missing actual HUD touch target ${key}`);
   await page.touchscreen.tap(p[0]/state.viewport[0]*size.width,p[1]/state.viewport[1]*size.height);
  } else if(kind==='map')await page.keyboard.press('m');
  else throw new Error(`Unknown panel review kind ${kind}`);
  await page.waitForFunction(()=>!!window.__sjrpgPanelLayout?.panel?.rect,null,{timeout:15000});
  await page.waitForTimeout(400);
  const state=await read();
  const expected={bag:'/bag_panel.gd',skills:'/skill_tree_panel.gd',journal:'/journal_panel.gd',settings:'/settings_panel.gd',pause:'/panel_frame.gd',map:'/map_panel.gd'}[kind];
  if(!state.panel.type.endsWith(expected)) throw new Error(`${kind}: actual input opened ${state.panel.type}`);
  return state;
 }
 function audit(state, issues) {
  const p=state.panel,scale=state.scale;
  if(!contains(state.safe,p.rect))issues.push('frame exceeds safe viewport');
  for(const key of ['header','close','footer','body_holder'])if(p[key]?.length===4&&!contains(p.rect,p[key]))issues.push(`${key} exceeds panel`);
  for(const key of ['header','close','footer','body_holder'])if(p[key]?.length===4&&p.content_rect&&!contains(p.content_rect,p[key]))issues.push(`${key} overlaps decorative frame`);
  if(p.body_holder[3]/scale<40)issues.push('scroll body has less than 40 display pixels of height');
  for(const c of p.controls) {
   if(!area(c.visible_rect))continue;
   if(c.text && c.font/scale<13.99)issues.push(`text below 14 display pixels: ${c.text} (${c.font/scale})`);
   if(c.kind==='button' && c.text && !c.input_ignored && c.font/scale<15.99)issues.push(`button text below 16 display pixels: ${c.text}`);
   if(c.kind==='button' && !c.disabled && !c.input_ignored && (c.rect[2]/scale<55.9 || c.rect[3]/scale<55.9))issues.push(`target below 56 display pixels: ${c.text||c.key||c.path}`);
   // 스크롤 탭의 원래 사각형은 클립 밖으로 이어져도 된다. 실제 그려진 범위를 검사한다.
   const visible=c.visible_rect;
   if(visible[0]<p.rect[0]-1.1 || visible[0]+visible[2]>p.rect[0]+p.rect[2]+1.1)issues.push(`horizontal panel overflow: ${c.text||c.path}`);
   if(c.text && c.wrap===0 && c.text_width>c.rect[2]+1.1)issues.push(`unwrapped text exceeds control: ${c.text}`);
   if(c.kind==='button'&&c.text&&c.art_source&&c.content_rect) {
    const left=c.content_rect[0]-c.rect[0],right=c.rect[0]+c.rect[2]-c.content_rect[0]-c.content_rect[2];
    const top=c.content_rect[1]-c.rect[1],bottom=c.rect[1]+c.rect[3]-c.content_rect[1]-c.content_rect[3];
    if(Math.abs(left-right)>1.1||Math.abs(top-bottom)>1.1)issues.push(`generated button has partially updated padding: ${c.text}`);
    if(c.wrap===0&&c.text_width>c.content_rect[2]+1.1)issues.push(`button text exceeds painted inner face: ${c.text}`);
    if(c.text_height>c.content_rect[3]+1.1)issues.push(`button text overlaps painted border: ${c.text}`);
   }
  }
  for(const c of p.controls.filter(c=>c.kind==='button'&&['진동 확인','효과음 확인'].includes(c.text))) {
   if(!c.text_centered||Math.abs(c.rect[0]+c.rect[2]/2-p.body[0]-p.body[2]/2)>1.1)issues.push(`settings action is not centered: ${c.text}`);
  }
  for(const scroll of p.scrolls) {if(scroll.v_bar_visible||scroll.h_bar_visible)issues.push(`native scrollbar remains visible: ${scroll.path}`);if(!scroll.arrow_cues)issues.push(`scroll is missing arrow cues: ${scroll.path}`);}
  for(const scroll of p.scrolls)if(scroll.horizontal_disabled && scroll.content.length && scroll.content[2]>scroll.rect[2]+1.1)issues.push(`horizontal scroll-content overflow: ${scroll.path}`);
 }
 async function captureToggleState(result,state,kind,width,height) {
  if(kind!=='settings')return;
  result.toggle_states??=[];
  for(const toggle of state.panel.switches||[]) {
   if(!contains(state.panel.body_scroll,toggle.rect)||result.toggle_states.some(t=>t.on===toggle.on))continue;
   if(toggle.font/state.scale<13.99)result.issues.push('switch text below 14 display pixels');
   // 한 화면에 ON/OFF 스위치가 함께 있을 수 있다. 전환 동작 증거가 아닌 상태 외형 캡처다.
   const name=`settings-${width}x${height}-switch-${toggle.on?'on':'off'}-present.png`;
   await page.screenshot({path:`${out}/${name}`,timeout:60000});
   result.toggle_states.push({...toggle,file:name,scope:'Visible state appearance; no toggle activation performed'});
  }
 }
 async function seekControl(predicate) {
  for(let attempt=0;attempt<35;attempt++) {
   const state=await read();
   const target=state.panel?.controls?.find(c=>c.kind==='button' && predicate(c));
   const body=state.panel?.body_scroll;
   if(!body)throw new Error('Detail review lost its actual panel');
   const visible=target?.visible_rect;
   const threshold=target ? (target.rect[3]<=body[3]-8*state.scale ? target.rect[3]-.5 : Math.min(target.rect[3]*.7,Math.max(12*state.scale,body[3]*.6))) : 0;
   if(target && visible[2]>=target.rect[2]*.8 && visible[3]>=threshold)return {state,target};
   const direction=target && target.rect[1]+target.rect[3]/2<body[1]+body[3]/2 ? 1 : -1;
   const start=[body[0]+body[2]*.25,body[1]+body[3]*(direction<0?.7:.2),body[2]*.5,body[3]*.1];
   const correction=target ? (target.rect[1]<body[1] ? body[1]-target.rect[1] : body[1]+body[3]-target.rect[1]-target.rect[3])/state.scale : direction*220;
   const distance=Math.min(220,body[3]/state.scale*.55,Math.max(12,Math.abs(correction)*.4));
   detailFlow.push({event:'seek',attempt,key:target?.key,text:target?.text,rect:target?.rect,visible_rect:target?.visible_rect,body,dy:direction*distance});
   await swipe(state,start,direction*distance);
  }
  throw new Error('Actual touch scrolling could not expose requested detail button');
 }
 async function tapControl(predicate, beforeTap=null) {
  let {state,target}=await seekControl(predicate);
  // A touch immediately after a swipe can stop inertia instead of activating.
  // Observe three stable probe samples, then recompute the real clipped target.
  let previous='',stable=0;
  for(let attempt=0;attempt<24;attempt++) {
   state=await fresh(state.frame);
   target=state.panel?.controls?.find(c=>c.kind==='button' && predicate(c));
   if(!target)throw new Error('Requested button vanished while waiting for touch-scroll settlement');
   const geometry=JSON.stringify([target.rect.map(v=>Math.round(v)),state.panel.scrolls.map(scroll=>Math.round(scroll.vertical))]);
   stable=geometry===previous ? stable+1 : 0;
   previous=geometry;
   if(stable>=3)break;
  }
  if(stable<3)throw new Error(`Touch scrolling never settled before ${target.text||target.key||target.path}`);
  if(target.disabled)throw new Error(`Actual detail button is disabled: ${target.text||target.path}`);
  if(!area(target.visible_rect))throw new Error(`Actual detail button is clipped: ${target.text||target.path}`);
  const trace={event:'tap',at:new Date().toISOString(),path:target.path,key:target.key,text:target.text,rect:target.rect,visible_rect:target.visible_rect,point:point(state,target.visible_rect),panel:state.panel.type,phase:await page.evaluate(()=>window.__sjrpgExpedition?.phase),scrolls:state.panel.scrolls.map(({path,vertical,maximum})=>({path,vertical,maximum}))};
  detailFlow.push(trace);
  console.log(`PANEL_DETAIL_TAP ${JSON.stringify(trace)}`);
  if(beforeTap)await beforeTap(state,target);
  await tapRect(state,target.visible_rect);
  await page.waitForTimeout(450);
  trace.after=await page.evaluate(()=>({phase:window.__sjrpgExpedition?.phase,panel:window.__sjrpgPanelLayout?.panel?.type,focus:window.__sjrpgGamepadReview?.focus}));
  return target;
 }
 function stableSettingsSnapshot(state) {
  return {
   panel:state.panel.id,viewport:state.viewport,
   buttons:state.panel.controls.filter(c=>c.kind==='button').map(({id,path,text,rect,art_source,style})=>({id,path,text,rect,art_source,style})),
   scrolls:state.panel.scrolls.map(({path,vertical,maximum})=>({path,vertical,maximum}))
  };
 }
 async function reviewSettingsChoices(result,width,height) {
  const choices=[...[.5,.75,1,1.25,1.5].map(value=>({key:'world_zoom',value})),...['auto','landscape','portrait'].map(value=>({key:'screen_orientation',value}))];
  result.settings_choices=[];
  for(const {key,value} of choices) {
   let before;
   const target=await tapControl(control=>control[key]===value,state=>{before=stableSettingsSnapshot(state);});
   await page.waitForFunction(({key,value})=>{
    const state=window.__sjrpgPanelLayout;
    return state?.[key]===value && state.panel?.controls?.some(control=>control.kind==='button'&&control[key]===value&&control.selected)
     && (key!=='screen_orientation'||state.panel.controls.filter(control=>control.screen_orientation!==null).every(control=>!control.disabled));
   },{key,value},{timeout:15000});
   const state=await fresh((await read()).frame),after=stableSettingsSnapshot(state);
   const issue=message=>result.issues.push(`settings ${key}=${value}: ${message}`);
   if(before.panel!==after.panel)issue('choice rebuilt the settings panel');
   if(JSON.stringify(before.viewport)!==JSON.stringify(after.viewport))issue('choice changed the review viewport');
   if(before.buttons.length!==after.buttons.length)issue('choice changed the control count');
   const fullscreenTitle=await page.evaluate(()=>window.SjrpgFullscreen?.state()?.title);
   for(const original of before.buttons) {
    const current=after.buttons.find(button=>button.path===original.path);
    if(!current||current.id!==original.id) {issue(`choice replaced button ${original.text||original.path}`);continue;}
    // 방향 잠금이 요구하는 전체화면 전환은 실제 브라우저 상태 문구만 갱신한다.
    const fullscreenStateLabel=key==='screen_orientation'&&original.path.endsWith('/FullscreenToggle')&&current.text===fullscreenTitle;
    if((current.text!==original.text&&!fullscreenStateLabel)||current.art_source!==original.art_source||current.style!==original.style)issue(`choice changed button text or artwork ${original.text||original.path}`);
    if(current.rect.some((number,index)=>Math.abs(number-original.rect[index])>1.1))issue(`choice moved or resized button ${original.text||original.path}`);
   }
   for(const original of before.scrolls) {
    const current=after.scrolls.find(scroll=>scroll.path===original.path);
    if(!current||Math.abs(current.vertical-original.vertical)>1.1||Math.abs(current.maximum-original.maximum)>1.1)issue(`choice changed settled scroll ${original.path}`);
   }
   const selected=state.panel.controls.filter(control=>control.kind==='button'&&control[key]!==null&&control.selected);
   if(selected.length!==1||selected[0][key]!==value)issue('choice is not represented by one current selection');
   const actual=state.panel.controls.find(control=>control.id===target.id);
   if(actual?.style!=='StyleBoxEmpty'||actual.art_source)issue('option unexpectedly acquired a frame or generated banner');
   audit(state,result.issues);
   result.settings_choices.push({key,value,target:target.id,before,after});
  }
  await page.screenshot({path:`${out}/settings-${width}x${height}-choices.png`,timeout:60000});
  // 방향 잠금이 켠 전체화면은 실제 버튼으로 해제한 뒤 다음 기기 비율을 모사한다.
  if(await page.evaluate(()=>Boolean(document.fullscreenElement))) {
   await tapControl(control=>control.path.endsWith('/FullscreenToggle'));
   await page.waitForFunction(()=>!document.fullscreenElement,null,{timeout:15000});
   await page.waitForTimeout(500);
  }
 }
 for(const [width,height] of sizes) {
  await closePanel();await page.setViewportSize({width,height});
  await page.waitForFunction(size=>{const s=window.__sjrpgPanelLayout;return s && Math.abs(s.viewport[0]/s.viewport[1]-size[0]/size[1])<.01;},[width,height]);
  await page.waitForTimeout(500);
  for(const kind of panels) {
   const result={viewport:[width,height],kind,issues:[],scrolls:[]};results.push(result);
   try {
    let state=await openPanel(kind);audit(state,result.issues);
    await captureToggleState(result,state,kind,width,height);
    result.initial=state;
    await page.screenshot({path:`${out}/${kind}-${width}x${height}-top.png`,timeout:60000});
    for(const initialScroll of state.panel.scrolls.filter(s=>s.maximum>1 && s.rect[2]>1 && s.rect[3]>1)) {
     state=await read();let scroll=state.panel.scrolls.find(s=>s.path===initialScroll.path);
     const button=state.panel.controls.find(c=>c.kind==='button' && !c.disabled && c.in_body && area(c.visible_rect)>0 && contains(scroll.rect,c.rect));
     const start=button?.rect || [scroll.rect[0]+scroll.rect[2]*.35,scroll.rect[1]+scroll.rect[3]*.55,scroll.rect[2]*.3,scroll.rect[3]*.1];
     const identity={id:state.panel.id,buttons:state.panel.controls.filter(c=>c.kind==='button').map(c=>[c.path,c.text,c.disabled]),zoom:state.world_zoom,gold:state.gold};
     const before=scroll.vertical;
     state=await swipe(state,start,-Math.min(100,point(state,scroll.rect).y*.6));
     const after=state.panel.scrolls.find(s=>s.path===initialScroll.path)?.vertical;
     if(after<=before+1)result.issues.push(`finger swipe did not advance scroll: ${initialScroll.path}`);
     const next={id:state.panel.id,buttons:state.panel.controls.filter(c=>c.kind==='button').map(c=>[c.path,c.text,c.disabled]),zoom:state.world_zoom,gold:state.gold};
     if(JSON.stringify(identity)!==JSON.stringify(next))result.issues.push(`swipe activated a button: ${initialScroll.path}`);
     // 장식 여백으로 짧아진 가로 본문도 실제 전체 길이에 맞는 수의 손가락 스와이프로 끝까지 확인한다.
     const distance=Math.min(220,scroll.rect[3]/state.scale*.55);
     const attempts=Math.min(240,Math.max(18,Math.ceil((scroll.maximum-scroll.vertical)/state.scale/Math.max(1,distance))*2+8));
     for(let attempt=0;attempt<attempts;attempt++) {
      scroll=state.panel.scrolls.find(s=>s.path===initialScroll.path);
      if(!scroll || scroll.vertical>=scroll.maximum-2)break;
      const rect=[scroll.rect[0]+scroll.rect[2]*.25,scroll.rect[1]+scroll.rect[3]*.65,scroll.rect[2]*.5,scroll.rect[3]*.1];
      state=await swipe(state,rect,-Math.min(220,scroll.rect[3]/state.scale*.55));
      await captureToggleState(result,state,kind,width,height);
     }
     scroll=state.panel.scrolls.find(s=>s.path===initialScroll.path);
     const reached=!!scroll && scroll.vertical>=scroll.maximum-2;
     if(!reached)result.issues.push(`last content not reached by touch: ${initialScroll.path}`);
     result.scrolls.push({path:initialScroll.path,started_on_button:button?.text||button?.key||null,before,after,reached,final:scroll});
    }
    result.bottom=await read();audit(result.bottom,result.issues);
    await page.screenshot({path:`${out}/${kind}-${width}x${height}-bottom.png`,timeout:60000});
    if(kind==='settings')await reviewSettingsChoices(result,width,height);
    result.issues=[...new Set(result.issues)];
   } catch(error) {result.issues.push(String(error));}
   failures.push(...result.issues.map(issue=>`${kind} ${width}x${height}: ${issue}`));
   console.log(`PANEL_REVIEW ${kind} ${width}x${height} issues=${result.issues.length}`);
   for(const issue of result.issues)console.log(`PANEL_ISSUE ${kind} ${width}x${height}: ${issue}`);
   await closePanel();
  }
 }

 if(detailReview) {
  // These cases use the same isolated save and actual touch input. Probes only observe.
  const detailSizes=[[344,883],[883,344]];
  async function resizeDetail(width,height) {
   await page.setViewportSize({width,height});
   await page.waitForFunction(size=>{const s=window.__sjrpgPanelLayout;return s && Math.abs(s.viewport[0]/s.viewport[1]-size[0]/size[1])<.01;},[width,height]);
   await page.waitForTimeout(450);
  }
  async function recordDetail(kind,width,height,work) {
   const result={viewport:[width,height],kind,issues:[],scope:'Actual touch input in the isolated review save; expedition objective, not legacy quest cards'};
   results.push(result);
   try {
    await resizeDetail(width,height);
    await work(result);
    result.final=await read();audit(result.final,result.issues);
    await page.screenshot({path:`${out}/${kind}-${width}x${height}.png`,timeout:60000});
   } catch(error) {result.issues.push(String(error));result.failure_state=await read();await page.screenshot({path:`${out}/${kind}-${width}x${height}-failure.png`,timeout:60000});}
   result.issues=[...new Set(result.issues)];
   failures.push(...result.issues.map(issue=>`${kind} ${width}x${height}: ${issue}`));
   console.log(`PANEL_REVIEW ${kind} ${width}x${height} issues=${result.issues.length}`);
   for(const issue of result.issues)console.log(`PANEL_ISSUE ${kind} ${width}x${height}: ${issue}`);
   return result;
  }
  for(const [width,height] of detailSizes) {
   await recordDetail('bag-expanded',width,height,async result=>{
    await openPanel('bag');
    await tapControl(c=>/^gear-\d+$/.test(c.key));
    await page.waitForFunction(()=>window.__sjrpgPanelLayout?.panel?.controls?.some(c=>String(c.key).startsWith('equip:')),null,{timeout:15000});
    let state=await read();audit(state,result.issues);result.expanded=state;
    const actionKeys=state.panel.controls.filter(c=>/^(equip|lock|sell):/.test(c.key)).map(c=>c.key);
    if(actionKeys.length!==3)throw new Error(`Expanded inventory has ${actionKeys.length} actual actions; expected equip, lock and sell`);
    result.actions=[];
    for(const key of actionKeys) {
     const exposed=await seekControl(c=>c.key===key);
     audit(exposed.state,result.issues);
     result.actions.push({key,control:exposed.target,state:exposed.state});
     await page.screenshot({path:`${out}/bag-expanded-${width}x${height}-${key.split(':')[0]}.png`,timeout:60000});
    }
   });
  }
  await recordDetail('expedition-contract',344,883,async result=>{
   await openPanel('journal');
   await tapControl(c=>c.text==='원정 열기');
   await page.waitForFunction(()=>window.__sjrpgPanelLayout?.panel?.type?.endsWith('/expedition_panel.gd'),null,{timeout:15000});
   const exposed=await seekControl(c=>/\/contract_hearth$/.test(c.path));
   result.contract=exposed.state;audit(exposed.state,result.issues);
  });
  // Starting a real contract reloads the actual adventure. Wait for the new probe,
  // then choose a visible starter and the roots mission through their UI buttons.
  let flowStep='tap-contract';
  const flowStage=name=>{flowStep=name;detailFlow.push({event:'step',name,at:new Date().toISOString()});console.log(`PANEL_DETAIL_STEP ${name}`);};
  try {
   flowStage('tap-contract');
   const previousLoadingSequence=await page.evaluate(()=>window.__sjrpgEntryLoading?.sequence??0);
   await tapControl(c=>/\/contract_hearth$/.test(c.path));
   flowStage('wait-contract-reload-starter');
   await page.waitForFunction(previous=>window.__sjrpgEntryLoading?.sequence>previous && window.__sjrpgEntryLoading?.visible===false && window.__sjrpgPanelLayout?.native_ready && window.__sjrpgExpedition?.phase==='starter' && window.__sjrpgPanelLayout?.panel?.controls?.some(c=>/\/draft_/.test(c.path)),previousLoadingSequence,{timeout:180000});
   flowStage('tap-starter-draft');
   await tapControl(c=>/\/draft_/.test(c.path));
   flowStage('wait-missions-after-starter');
   await page.waitForFunction(()=>window.__sjrpgExpedition?.phase==='missions',null,{timeout:15000});
   for(const [width,height] of detailSizes) {
    flowStage(`inspect-mission-options-${width}x${height}`);
    await recordDetail('expedition-mission-options',width,height,async result=>{
     const exposed=await seekControl(c=>/\/mission_roots$/.test(c.path));
     result.options=exposed.state;
    });
   }
   flowStage('tap-roots-mission');
   await tapControl(c=>/\/mission_roots$/.test(c.path));
   flowStage('wait-active-mission');
   await page.waitForFunction(()=>window.__sjrpgExpedition?.phase==='mission',null,{timeout:15000});
   for(const [width,height] of detailSizes) {
    flowStage(`inspect-active-journal-${width}x${height}`);
    await recordDetail('journal-active-mission',width,height,async result=>{
     const state=await openPanel('journal');
     result.objectives=state.panel.controls.filter(c=>c.kind==='label' && c.in_body && c.text).map(c=>c.text);
     if(result.objectives.some(text=>text.includes('계약을 선택하세요')) || result.objectives.length===0)throw new Error('Journal still shows contract lobby instead of the selected mission');
     result.journal=state;
    });
   }
  } catch(error) {
   const snapshot=await page.evaluate(()=>({layout:window.__sjrpgPanelLayout,expedition:window.__sjrpgExpedition,focus:window.__sjrpgGamepadReview?.focus,navigation:window.__sjrpgGamepadReview?.navigation,loading:window.__sjrpgEntryLoading,active_element:document.activeElement?.tagName}));
   detailFlow.push({event:'failure',step:flowStep,error:String(error),snapshot});
   await writeFile(`${out}/detail-flow-failure.json`,JSON.stringify({step:flowStep,error:String(error),detailFlow,snapshot},null,2));
   await page.screenshot({path:`${out}/detail-flow-failure-${flowStep}.png`,timeout:60000});
   failures.push(`detail expedition actual-input flow at ${flowStep}: ${error}`);
   console.log(`PANEL_ISSUE detail expedition actual-input flow at ${flowStep}: ${error}`);
   console.log(`PANEL_DETAIL_FAILURE ${JSON.stringify({step:flowStep,phase:snapshot.expedition?.phase,panel:snapshot.layout?.panel?.type,focus:snapshot.focus,last_tap:detailFlow.filter(event=>event.event==='tap').at(-1),buttons:snapshot.layout?.panel?.controls?.filter(c=>c.kind==='button').map(({text,key,path,rect,visible_rect,disabled})=>({text,key,path,rect,visible_rect,disabled}))})}`);
  }
 }
 if(errors.length || failures.length)throw new Error(`Panel review failed: ${failures.length} issues, ${errors.length} runtime errors`);
 console.log(`MOBILE_PANELS_PASS cases=${results.length}; representative aspect ratios, one actual game boot`);
} finally {
 await writeFile(`${out}/report.json`,JSON.stringify({sizes,panels,detailReview,results,failures,errors,detailFlow,scope:'Representative browser aspect ratios; no physical Fold device verification'},null,2));
 await browser.close();
}
