// Real two-project IndexedDB + version-navigation test against an assembled build.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=(process.argv.slice(2).find(arg=>!arg.startsWith('--'))||'http://localhost:8765/').replace(/\/?$/,'/');
const browser=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:960,height:640},deviceScaleFactor:1});
const logs=[];
function checkConsole(){
 // Pinned4.7.2 emits this engine allocator diagnostic during a successful
 // native3D shutdown, even after the entire scene has retired. Keep it visible
 // and separate from runtime/GL/script errors; URL and durable saves are strict.
 const shutdown=logs.filter(line=>/^ERROR: Pages in use exist at exit in PagedAllocator: N16WorkerThreadPool5GroupE\s*$/.test(line.trim())||/^at: ~PagedAllocator \(\.\/core\/templates\/paged_allocator\.h:170\)\s*$/.test(line.trim()));
 const unexpected=logs.filter(line=>!shutdown.includes(line));
 assert.equal(unexpected.length,0,unexpected.slice(0,8).join('\n'));
 if(shutdown.length)console.log('Observed Godot4.7.2 shutdown allocator diagnostic; successful navigation/durability verified separately:',shutdown.length,'lines');
}
async function select(page,key){
 const point=await page.evaluate(name=>window.__sjrpgClassButtons[name],key);
 const viewport=page.viewportSize();await page.mouse.click(viewport.width*point[0],viewport.height*point[1]);
}
async function enter(page,edition,hero,resume=false){
 console.log('Entering',edition,hero,resume?'continue':'new');
 await page.bringToFront();
 await page.goto(base+edition+'/?'+(edition==='3d'?'inspection=1&':'')+'quality=low');
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 console.log('Title ready',edition);
 await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassSelectReady&&window.__sjrpgClassButtons,null,{timeout:30000});
 console.log('Selection ready',edition);
 if(resume) await select(page,'continue');
 else {await select(page,hero);await page.waitForTimeout(150);await select(page,'start');}
 await page.waitForFunction(()=>window.__sjrpgAdventureReady,null,{timeout:60000});
 if(edition==='3d'){
  await page.waitForFunction(()=>window.__sjrpg3dProbe?.simulation==='3d'&&window.__sjrpg3dProbe.physics_ticks>0&&window.__sjrpg3dProbe.physics_bodies>0,null,{timeout:60000});
 }
 await page.waitForFunction(hero=>window.__sjrpgSaveProbe?.success&&window.__sjrpgSaveProbe.class===hero,hero,{timeout:20000,polling:100});
 const record=await page.evaluate(()=>({mounts:window.__sjrpgStorageMounts,save:window.__sjrpgSaveProbe}));
 console.log('Game and save ready',edition,JSON.stringify(record));
 return record;
}
async function persisted(page,record){
 console.log('Checking durable save',record.save.class,record.save.path);
 await page.waitForFunction(async({mount,path,hero})=>{
  const entry=await new Promise((resolve,reject)=>{
   const request=indexedDB.open(mount);
   request.onerror=()=>reject(request.error);
   request.onsuccess=()=>{const db=request.result;
    if(!db.objectStoreNames.contains('FILE_DATA')){db.close();resolve(null);return;}
    const read=db.transaction('FILE_DATA','readonly').objectStore('FILE_DATA').get(path);
    read.onerror=()=>{db.close();reject(read.error);};
    read.onsuccess=()=>{db.close();resolve(read.result);};
   };
  });
  if(!entry?.contents)return false;
  const data=JSON.parse(new TextDecoder().decode(entry.contents));
  return (data.hero_class||data.class)===hero;
 },{mount:record.mounts[0],path:record.save.path,hero:record.save.class},{timeout:20000,polling:100});
}
try{
 if(process.argv.includes('--navigation-only')){
  const page=await context.newPage();
  page.on('pageerror',error=>logs.push(String(error)));
  page.on('console',message=>{if(message.type()==='error'){logs.push(message.text());console.log('Browser error:',message.text());}});
  const record=await enter(page,'3d','mage');await persisted(page,record);
  await page.keyboard.press('Escape');
  await page.waitForFunction(()=>window.__sjrpgVersionButtons?.VersionSelect?.point,null,{timeout:15000});
  await page.waitForTimeout(1200);
  console.log('Version controls',await page.evaluate(()=>window.__sjrpgVersionButtons));
  await page.evaluate(()=>{const original=window.__sjrpgNavigateEdition;window.__sjrpgNavigateEdition=(...args)=>{window.__sjrpgLastVersionRequest=args;return original(...args);};});
  const p=await page.evaluate(()=>window.__sjrpgVersionButtons.VersionSelect.point),v=page.viewportSize();
  await page.mouse.click(v.width*p[0],v.height*p[1]);
  try{await page.waitForURL(url=>url.pathname===new URL(base).pathname,{timeout:30000,waitUntil:'commit'});}
  catch(error){console.log('Navigation stalled',page.url(),await page.evaluate(()=>({title:document.title,request:window.__sjrpgLastVersionRequest,result:window.__sjrpgNativeExitResult,errors:window.__sjrpgTestErrors,buttons:window.__sjrpgVersionButtons,probe:window.__sjrpg3dProbe})));throw error;}
  checkConsole();
  console.log('Real native edition shutdown, durable save and return to root chooser passed');
 }else{
 const two=await context.newPage();let three=await context.newPage();
 for(const page of [two,three]){
  page.on('pageerror',error=>logs.push(String(error)));
  page.on('console',message=>{if(message.type()==='error'){logs.push(message.text());console.log('Browser error:',message.text());}});
 }
 const first=await enter(two,'2d','warrior');await persisted(two,first);
 const second=await enter(three,'3d','mage');await persisted(three,second);
 assert.deepEqual(first.mounts,['/userfs']);
 assert.deepEqual(second.mounts,['/userfs/sjrpg_3d']);
 assert(second.save.path.startsWith('/userfs/sjrpg_3d/'));
 // Keep2D's older filesystem snapshot alive while the new3D save exists.
 // Closing the now-durable3D page avoids rendering two software GPU worlds.
 await three.close();
 await two.bringToFront();
 await two.evaluate(()=>{window.__sjrpgPreviousSave=window.__sjrpgSaveProbe;});
 for(let attempt=0;attempt<2;attempt++){
  await two.keyboard.press('Escape');
  try{await two.waitForFunction(()=>window.__sjrpgSaveProbe!==window.__sjrpgPreviousSave,null,{timeout:8000,polling:100});break;}
  catch(error){if(attempt===1)throw error;}
 }
 await persisted(two,first);
 const reloadedTwo=await enter(two,'2d','warrior',true);await persisted(two,reloadedTwo);
 await two.close();
 three=await context.newPage();
 three.on('pageerror',error=>logs.push(String(error)));
 three.on('console',message=>{if(message.type()==='error')logs.push(message.text());});
 const reloadedThree=await enter(three,'3d','mage',true);await persisted(three,reloadedThree);
 await three.keyboard.press('Escape');
 await three.waitForFunction(()=>window.__sjrpgVersionButtons?.VersionSelect?.point,null,{timeout:15000});
 await three.waitForTimeout(1200);
 const point=await three.evaluate(()=>window.__sjrpgVersionButtons.VersionSelect.point);
 const view=three.viewportSize();await three.mouse.click(view.width*point[0],view.height*point[1]);
 await three.waitForURL(url=>url.pathname===new URL(base).pathname,{timeout:30000,waitUntil:'commit'});
 checkConsole();
 console.log('Real editions passed: simultaneous isolated IndexedDB saves, both reload+continue, actual3D settings return to root chooser after graceful filesystem sync');
 console.log(JSON.stringify({two:first,three:second}));
}
}finally{await browser.close();}
