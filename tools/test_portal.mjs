import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile,mkdtemp,rm,mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const temp=await mkdtemp(join(tmpdir(),'sjrpg-portal-'));
const result=spawnSync('python3',['tools/prepare_portal.py',temp],{encoding:'utf8'});
assert.equal(result.status,0,result.stderr);
const server=createServer(async(req,res)=>{
 try{
  const url=new URL(req.url,'http://localhost');
  const path=url.pathname.replace(/^\/sjrpg\//,'');
  if(path==='2d/'||path==='3d/'){
   res.setHeader('Content-Type','text/html; charset=utf-8');
   res.end('<!doctype html><p>Navigation destination: '+path+'</p>');
   return;
  }
  const file=path==='portal-bg.webp'?'sjrpg_2d/web/loading-bg.webp':path==='2d.html'||path==='3d.html'?join(temp,path):path===''?'web/index.html':null;
  if(!file){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',path.endsWith('webp')?'image/webp':'text/html; charset=utf-8');
  res.end(await readFile(file));
 }catch(error){res.writeHead(500);res.end(String(error));}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base=`http://127.0.0.1:${server.address().port}/sjrpg/`;
const browser=await chromium.launch({args:['--no-sandbox']});
try{
 for(const viewport of [{width:390,height:844},{width:844,height:390},{width:1280,height:720}]){
  const page=await browser.newPage({viewport});
  const errors=[],requests=[];
  page.on('pageerror',error=>errors.push(String(error)));
  page.on('request',request=>requests.push(request.url()));
  await page.goto(base);
  await page.waitForFunction(()=>window.__sjrpgPortalReady);
  assert.equal(await page.title(),'자연의 수호자 · 모험 선택');
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  for(const edition of ['2d','3d']){
   await page.goto(base);
   const card=page.locator(`[data-edition="${edition}"]`);
   const box=await card.boundingBox();
   assert(box.width>=140&&box.height>=56);
   await card.click();
   await page.waitForURL(base+edition+'/');
  }
  assert.equal(errors.length,0,errors.join('\n'));
  assert(!requests.some(url=>/\.(wasm|pck)(\?|$)/.test(url)),'Chooser must not fetch either engine');
  if(process.argv.includes('--capture')){
   await page.goto(base);await page.waitForFunction(()=>window.__sjrpgPortalReady);
   await mkdir('build/review',{recursive:true});
   await page.screenshot({path:`build/review/edition-chooser-${viewport.width}x${viewport.height}.png`,fullPage:true});
  }
  await page.close();
 }
 const page=await browser.newPage();
 await page.goto(base+'3d.html?at=field#bookmark');
 await page.waitForURL(base+'3d/?at=field#bookmark');
 await page.goto(base+'2d.html?at=portal');
 await page.waitForURL(base+'2d/?at=portal');
 await page.goto(base+'?preview3d=1&at=chapel_reference');
 await page.waitForURL(base+'3d/?preview3d=1&at=chapel_reference');
 console.log('Portal: mobile/landscape/desktop links, touch sizes, no engine prefetch, old bookmarks passed (navigation fixtures; actual game smoke runs after export)');
}finally{
 await browser.close();await new Promise(resolve=>server.close(resolve));await rm(temp,{recursive:true,force:true});
}
