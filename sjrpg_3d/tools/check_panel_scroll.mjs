#!/usr/bin/env node
// 실제 터치로 버튼 위에서 시작한 스와이프와 짧은 탭을 구분한다.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=process.argv[2]||'http://127.0.0.1:8886/';
const out=process.argv[3]||'build/review/panel-scroll';
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const results=[],errors=[];
try {
 const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text());});
 const url=new URL(base);url.searchParams.set('native_style_review','1');url.searchParams.set('panel','settings');
 await page.goto(url.href);
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:120000});
 await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassSelectReady&&window.__sjrpgClassButtons);
 for(const key of ['mage','start']){const p=await page.evaluate(k=>window.__sjrpgClassButtons[k],key);await page.touchscreen.tap(p[0]*390,p[1]*844);await page.waitForTimeout(500);}
 const read=()=>page.evaluate(()=>window.__sjrpgNativeStyleReview);
 await page.waitForFunction(()=>window.__sjrpgNativeStyleReview?.panel?.scroll_max>30,null,{timeout:120000});
 const point=(s,r)=>({x:(r[0]+r[2]*.5)/s.viewport[0]*page.viewportSize().width,y:(r[1]+r[3]*.5)/s.viewport[1]*page.viewportSize().height});
 const cdp=await page.context().newCDPSession(page);
 async function swipe(p,dy){await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...p,id:0}]});await page.waitForTimeout(100);for(let n=1;n<=8;n++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:p.x,y:p.y+dy*n/8,id:0}]});await page.waitForTimeout(45);}await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.waitForTimeout(900);}
 let s=await read();let button=s.panel.buttons.find(b=>b.in_body&&!b.disabled&&b.text.includes('전체화면'));
 assert(button,'actual settings button');const initial=s.panel.scroll_vertical;
 await swipe(point(s,button.rect),-90);s=await read();
 assert(s.panel.scroll_vertical>initial+30,'settings scrolls when swipe begins on a button');
 assert.equal(await page.evaluate(()=>!!document.fullscreenElement),false,'swipe does not activate fullscreen');
 results.push({panel:'settings',before:initial,after:s.panel.scroll_vertical});
 await page.screenshot({path:out+'/settings.png'});
 let close=s.panel.buttons.find(b=>b.text==='×');await page.touchscreen.tap(...Object.values(point(s,close.rect)));
 await page.waitForFunction(()=>!window.__sjrpgNativeStyleReview?.panel?.rect);
 await page.setViewportSize({width:844,height:390});
 await page.waitForTimeout(1200);
 s=await read();await page.touchscreen.tap(...Object.values(point(s,s.buttons.bar_bag)));
 await page.waitForFunction(()=>window.__sjrpgNativeStyleReview?.panel?.type?.endsWith('/bag_panel.gd'));
 s=await read();button=s.panel.buttons.find(b=>b.in_body&&b.key.startsWith('gear-'));
 assert(button,'actual inventory row');
 if(s.panel.scroll_max<30){
  await page.touchscreen.tap(...Object.values(point(s,button.rect)));
  await page.waitForTimeout(700);s=await read();
  button=s.panel.buttons.find(b=>b.in_body&&b.key===button.key);
 }
 assert(s.panel.scroll_max>30,'inventory fixture actually overflows the landscape panel');
 const before=s.panel.scroll_vertical;const actions=s.panel.buttons.length;
 await swipe(point(s,button.rect),-90);s=await read();
 assert(s.panel.scroll_vertical>before+20,'inventory scrolls from item row');
 assert.equal(s.panel.buttons.length,actions,'swipe does not expand or collapse an item');
 results.push({panel:'bag',before,after:s.panel.scroll_vertical});
 button=s.panel.buttons.find(b=>b.in_body&&b.key.startsWith('gear-'));
 await page.touchscreen.tap(...Object.values(point(s,button.rect)));
 await page.waitForTimeout(800);s=await read();
 assert(s.panel.buttons.length>actions,'short item tap still opens item actions');
 results.push({panel:'bag',tap_opens_actions:true});
 await page.screenshot({path:out+'/bag.png'});
 assert.deepEqual(errors,[]);
 console.log('PANEL_SCROLL_PASS '+JSON.stringify(results));
} finally {await writeFile(out+'/report.json',JSON.stringify({results,errors},null,2));await browser.close();}
