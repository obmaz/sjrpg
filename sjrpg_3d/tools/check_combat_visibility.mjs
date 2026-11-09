#!/usr/bin/env node
// Explicit visual fixtures. These captures are NOT normal-play/performance results.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=new URL(process.argv[2]||'http://127.0.0.1:8797/');
const out=path.resolve(process.argv[3]||'build/combat-visibility');
const edition=process.env.SJRPG_VISIBILITY_EDITION||'candidate';
const all=['cave_torches','cave_torches_north','combat_health','boss_warning','meteor_warning','firewall','cave_swarm','sprite_directions','sprite_corpses'];
const requested=(process.env.SJRPG_VISIBILITY_SCENARIOS||all.join(',')).split(',').filter(Boolean);
const orientations=(process.env.SJRPG_VISIBILITY_ORIENTATIONS||'portrait,landscape').split(',');
for(const s of requested)assert(all.includes(s),'valid scenario '+s);
for(const o of orientations)assert(['portrait','landscape'].includes(o),'valid orientation '+o);
const report={edition,source_sha:process.env.SJRPG_VISIBILITY_SHA||null,fixture:true,performance_evidence:false,
 scope:'Identical explicitly configured native gameplay sources for before/after visual comparison. Normal title/slot/class entry precedes each disposable group. HP/age/camera/enemy fixture mutations are intentional; cave swarm must come from a real basic attack on the real marker.',
 cases:[],passed:false};
await mkdir(out,{recursive:true});
let browser,context,page,current,closing=false;
const deadline=90000;
async function bounded(promise,label,ms=deadline){let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label+' deadline')),ms);})]);}finally{clearTimeout(timer);}}
async function read(){return bounded(page.evaluate(()=>({
 title:window.__sjrpgTitleReady,ready:window.__sjrpgAdventureReady,entry:window.__sjrpgClassButtons,loading:window.__sjrpgEntryLoading,
 native:window.__sjrpg3dProbe,fixture:window.__sjrpgCombatVisibility,command:typeof window.__sjrpgCombatVisibilityCommand==='function',
 size:[innerWidth,innerHeight],dpr:devicePixelRatio,visibility:document.visibilityState,token:window.__sjrpgVisibilityDocument
})),'fixture read',45000);}
async function wait(predicate,label,ms=deadline){const until=Date.now()+ms;let last;while(Date.now()<until){assert.equal(current.errors.length,0,JSON.stringify(current.errors));last=await read();if(last.fixture?.proof?.error)throw Error(last.fixture.proof.error);if(predicate(last))return last;await page.waitForTimeout(100);}throw Error(label+' deadline '+JSON.stringify(last));}
async function click(key){const s=await wait(s=>s.entry?.[key],'entry '+key);await page.mouse.click(s.entry[key][0]*s.size[0],s.entry[key][1]*s.size[1]);}
async function start(hero){await wait(s=>s.title&&!s.ready&&s.command,'ordinary title and CI observer',180000);await page.locator('#entry-start').click();let s=await wait(s=>['slots','class'].includes(s.entry?.stage),'ordinary class or slot screen');if(s.entry.stage==='slots'){const slot=s.entry.slots_state?.find(x=>!x.occupied);assert(slot,'fresh disposable context must have an empty slot');await click('slot'+slot.slot);s=await wait(s=>s.entry?.selected_slot===slot.slot&&s.entry?.stage==='class','normal empty-slot class screen');}await click(hero);await click('start');s=await wait(s=>s.ready&&s.native?.ready&&!s.loading?.visible,'ordinary native adventure',180000);assert.equal(s.native.actor_mode,hero==='mage'?'skeletal_mage':'native_warrior');return s;}
function validate(scenario,s){
 assert(s.fixture.ready&&!s.fixture.busy&&s.fixture.fixture&&!s.fixture.performance_evidence);
 assert(s.fixture.paused,'explicit fixture is paused');assert.equal(s.fixture.scenario,scenario);assert.equal(s.visibility,'visible');
 assert.equal(s.fixture.scope,scenario.startsWith('cave_torches')?'cave':'forest');
 if(scenario==='cave_torches'){assert(s.fixture.proof.actual_cave_enter);assert.equal(s.fixture.cave_lights,10);}
 if(edition==='baseline')return;
 if(scenario.startsWith('cave_torches')){assert.equal(s.fixture.torches?.mounting,'wall');assert.equal(s.fixture.torches?.count,10);assert.equal(s.fixture.torches?.batches,4);assert.equal(s.fixture.torches?.scale,1.7);assert.equal(s.fixture.torches?.heights.length,10);assert(s.fixture.torches.heights.every(y=>Math.abs(y-1.55)<.001));}
 if(scenario==='combat_health'){assert.equal(s.fixture.enemy_feedback?.bars,3,'native health bars for three actual damaged enemies');assert.equal(s.fixture.enemy_feedback?.telegraphs,0);}
 if(scenario==='boss_warning'){assert.equal(s.fixture.enemy_feedback?.telegraphs,1,'native boss windup warning');assert.equal(s.fixture.proof.boss.state,'windup');}
 if(scenario==='meteor_warning'){assert.equal(s.fixture.native_zones?.count,1);assert.equal(s.fixture.native_zones?.sources?.[0]?.phase,'warning');}
 if(scenario==='firewall'){assert.equal(s.fixture.native_zones?.count,1);assert.equal(s.fixture.native_zones?.sources?.[0]?.phase,'active');assert(s.fixture.native_zones?.sources?.[0]?.wall);}
 if(scenario==='sprite_directions'){assert.equal(s.fixture.enemy_sprites?.count,4);assert.deepEqual(s.fixture.enemy_sprites.sources.map(x=>x.cell[1]).sort(),[0,1,2,3]);assert(s.fixture.enemy_sprites.sources.every(x=>x.pivot_error<.001));}
 if(scenario==='sprite_corpses'){assert.equal(s.fixture.proof.actual_source_deaths,4);assert.equal(s.fixture.enemy_sprites?.count,0);assert.equal(s.fixture.enemy_sprites?.corpses,4);assert.equal(s.fixture.visible_sprite_corpses,4,'corpses must actually be visible after fade-in');assert.equal(s.fixture.proof.corpse_age_seconds,.5);assert(s.fixture.enemy_sprites?.corpse_texture_loaded);}
 if(scenario==='cave_swarm'){assert(s.fixture.proof.actual_basic_attack);assert.equal(s.fixture.proof.living,20);assert.equal(s.fixture.enemy_sprites?.count,20);assert.equal(s.fixture.enemy_sprites?.appearance,'2d');assert.equal(s.fixture.enemy_sprites?.physics,'3d');assert(s.fixture.enemy_sprites?.sources?.every(x=>x.visible&&x.pivot_error<.001));}
}
try{
 browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
 for(const orientation of orientations){
  for(const hero of ['warrior','mage']){
   const scenarios=requested.filter(s=>(['cave_torches','cave_torches_north','cave_swarm','sprite_directions','sprite_corpses'].includes(s)?'warrior':'mage')===hero);if(!scenarios.length)continue;
   current={hero,orientation,errors:[]};closing=false;
   const viewport=orientation==='portrait'?{width:390,height:844}:{width:1280,height:720};
   context=await browser.newContext({viewport,deviceScaleFactor:1,hasTouch:true,isMobile:orientation==='portrait'});
   await context.addInitScript(()=>{window.__sjrpgVisibilityDocument=crypto.randomUUID();});
   page=await context.newPage();page.setDefaultTimeout(deadline);
   page.on('pageerror',e=>{if(!closing)current.errors.push({type:'pageerror',message:String(e)});});
   page.on('crash',()=>{if(!closing)current.errors.push({type:'crash'});});
   page.on('console',m=>{if(!closing&&(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text())))current.errors.push({type:'console',message:m.text()});});
   const url=new URL(base);url.searchParams.set('combat_visibility_review','1');url.searchParams.set('quality','high');
   await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:180000});
   const normal=await start(hero),token=normal.token;
   for(const scenario of scenarios){
    const before=await read(),serial=before.fixture.serial;
    await bounded(page.evaluate(s=>window.__sjrpgCombatVisibilityCommand(s),scenario),'fixture command');
    const s=await wait(s=>s.fixture?.ready&&s.fixture.serial>serial&&s.fixture.scenario===scenario,'actual '+scenario+' fixture ready');
    assert.equal(s.token,token,'document must not reload');
    validate(scenario,s);assert.equal(current.errors.length,0,JSON.stringify(current.errors));
    const name=scenario+'-'+orientation;
    await bounded(page.screenshot({path:path.join(out,name+'.png'),fullPage:false,timeout:85000}),'actual screenshot '+name);
    const after=await read();assert.equal(after.fixture.serial,s.fixture.serial);assert.equal(after.token,token);
    const result={name,hero,orientation,viewport,dpr:s.dpr,fixture:true,performance_evidence:false,passed:true,state:s.fixture,native:s.native,errors:[...current.errors],screenshot:name+'.png'};
    report.cases.push(result);
    await writeFile(path.join(out,name+'.json'),JSON.stringify(result,null,2));
    console.log('COMBAT_VISIBILITY_SCENE '+JSON.stringify({edition,name,hero,fixture:true,performance_evidence:false,serial:s.fixture.serial,scope:s.fixture.scope,enemy_count:s.fixture.enemy_count,health:s.fixture.enemy_feedback?.bars??null,telegraphs:s.fixture.enemy_feedback?.telegraphs??null,zones:s.fixture.native_zones?.count??null,sprite_count:s.fixture.enemy_sprites?.count??null,actual_basic_attack:s.fixture.proof.actual_basic_attack??null}));
   }
   closing=true;await context.close();context=null;page=null;
  }
 }
 assert.equal(report.cases.length,requested.length*orientations.length);
 report.passed=true;console.log('COMBAT_VISIBILITY_PASS '+JSON.stringify({edition,cases:report.cases.length,fixture:true,performance_evidence:false,errors:0}));
}catch(error){report.failure=String(error);report.errors=current?.errors||[];console.error('COMBAT_VISIBILITY_FAIL '+JSON.stringify({edition,error:String(error),errors:report.errors}));process.exitCode=1;}
finally{closing=true;await writeFile(path.join(out,'proof.json'),JSON.stringify(report,null,2));if(context)await context.close().catch(()=>{});if(browser)await browser.close().catch(()=>{});}
