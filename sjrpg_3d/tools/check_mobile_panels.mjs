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
  await tapRect(state,state.panel.close);
  await page.waitForFunction(()=>!window.__sjrpgPanelLayout?.panel?.rect,null,{timeout:15000});
 }
 // 구현의 실제 바인딩: Game._unhandled_input B/T/Escape. 일지는 HUD bar_quests 터치.
 async function openPanel(kind) {
  await closePanel();
  if(kind==='pause') {
   await page.evaluate(()=>document.querySelector('canvas').blur());
  } else if(kind==='journal') {
   const state=await read(),p=state.hud_targets.bar_quests,size=page.viewportSize();
   await page.touchscreen.tap(p[0]/state.viewport[0]*size.width,p[1]/state.viewport[1]*size.height);
  } else await page.keyboard.press({bag:'b',skills:'t',settings:'Escape'}[kind]);
  await page.waitForFunction(()=>!!window.__sjrpgPanelLayout?.panel?.rect,null,{timeout:15000});
  await page.waitForTimeout(400);
  const state=await read();
  const expected={bag:'/bag_panel.gd',skills:'/skill_tree_panel.gd',journal:'/journal_panel.gd',settings:'/settings_panel.gd',pause:'/panel_frame.gd'}[kind];
  if(!state.panel.type.endsWith(expected)) throw new Error(`${kind}: actual input opened ${state.panel.type}`);
  return state;
 }
 function audit(state, issues) {
  const p=state.panel,scale=state.scale;
  if(!contains(state.safe,p.rect))issues.push('frame exceeds safe viewport');
  for(const key of ['header','close','footer','body_holder'])if(!contains(p.rect,p[key]))issues.push(`${key} exceeds panel`);
  for(const key of ['header','close','footer','body_holder'])if(p.content_rect&&!contains(p.content_rect,p[key]))issues.push(`${key} overlaps decorative frame`);
  if(p.body_holder[3]/scale<40)issues.push('scroll body has less than 40 display pixels of height');
  for(const c of p.controls) {
   if(!area(c.visible_rect))continue;
   if(c.text && c.font/scale<13.99)issues.push(`text below 14 display pixels: ${c.text} (${c.font/scale})`);
   if(c.kind==='button' && !c.disabled && (c.rect[2]/scale<43.9 || c.rect[3]/scale<43.9))issues.push(`target below 44 display pixels: ${c.text||c.key||c.path}`);
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
    await swipe(state,start,direction*Math.min(220,body[3]/state.scale*.55));
   }
   throw new Error('Actual touch scrolling could not expose requested detail button');
  }
  async function tapControl(predicate) {
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
   await tapRect(state,target.visible_rect);
   await page.waitForTimeout(450);
   trace.after=await page.evaluate(()=>({phase:window.__sjrpgExpedition?.phase,panel:window.__sjrpgPanelLayout?.panel?.type,focus:window.__sjrpgGamepadReview?.focus}));
   return target;
  }
  async function recordDetail(kind,width,height,work) {
   const result={viewport:[width,height],kind,issues:[],scope:'Actual touch input in the isolated review save; expedition objective, not legacy quest cards'};
   results.push(result);
   try {
    await resizeDetail(width,height);
    await work(result);
    result.final=await read();audit(result.final,result.issues);
    await page.screenshot({path:`${out}/${kind}-${width}x${height}.png`,timeout:60000});
   } catch(error) {result.issues.push(String(error));}
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
   await tapControl(c=>/\/contract_hearth$/.test(c.path));
   flowStage('wait-contract-reload-starter');
   await page.waitForFunction(()=>window.__sjrpgPanelLayout?.native_ready && window.__sjrpgExpedition?.phase==='starter' && window.__sjrpgPanelLayout?.panel?.controls?.some(c=>/\/draft_/.test(c.path)),null,{timeout:120000});
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
