#!/usr/bin/env node
// Preserve original pixels/aspect; compare real before/after captures, never concepts.
import {readFile,readdir,mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const root=path.resolve(process.argv[2]||'build/native-style-review');
const beforeLabel=process.env.SJRPG_STYLE_BEFORE_LABEL||'3ec51c4';
if(!/^[0-9a-f]{7,40}$/.test(beforeLabel))throw Error('Expected actual baseline commit SHA label');
const before=path.join(root,'before'),after=path.join(root,'after'),out=path.join(root,'comparison');
await Promise.all([mkdir(out,{recursive:true}),mkdir(before,{recursive:true}),mkdir(after,{recursive:true})]);
const files=(await readdir(before)).filter(x=>x.endsWith('.png')&&x!=='failure.png');
const index=[];const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
try{for(const file of files){
 let a,b;try{[a,b]=await Promise.all([readFile(path.join(before,file)),readFile(path.join(after,file))]);}catch{continue;}
 const page=await browser.newPage();
 const html='<style>body{margin:0;background:#101411;color:#eee3cf;font:16px sans-serif}main{display:flex;gap:20px;padding:10px}section{display:flex;flex-direction:column;gap:10px}img{display:block;max-width:none}h2{font-size:16px;margin:0;height:24px}</style><main><section><h2>Before · '+beforeLabel+'</h2><img src="data:image/png;base64,'+a.toString('base64')+'"></section><section><h2>After · candidate</h2><img src="data:image/png;base64,'+b.toString('base64')+'"></section></main>';
 await page.setContent(html);await page.locator('img').evaluateAll(imgs=>Promise.all(imgs.map(img=>img.decode())));
 const dims=await page.locator('img').evaluateAll(imgs=>({w:imgs.reduce((n,i)=>n+i.naturalWidth,40),h:Math.max(...imgs.map(i=>i.naturalHeight))+54}));
 await page.setViewportSize({width:dims.w,height:dims.h});
 await page.screenshot({path:path.join(out,file),timeout:90000});
 if(['warrior-390x844-hud.png','mage-390x844-hud.png','mage-390x844-skills.png','bridge-native.png','cave-native.png','default-town.png','matched-actors-face-0.png','matched-chest-closed.png','matched-chest7-closed.png','merchant-portrait-town.png','merchant-landscape-town.png','merchant-portrait-shop.png','merchant-gallery-face-0.png'].includes(file)){
  const encoded=(await page.screenshot({type:'jpeg',quality:80,timeout:90000})).toString('base64');const name='comparison-'+file.slice(0,-4);
  console.log('SJ_NATIVE_STYLE_IMAGE_BEGIN '+name+' image/jpeg '+encoded.length);
  for(let i=0;i<encoded.length;i+=16384)console.log('SJ_NATIVE_STYLE_IMAGE_CHUNK '+name+' '+encoded.slice(i,i+16384));
  console.log('SJ_NATIVE_STYLE_IMAGE_END '+name);
 }
 index.push(file);await page.close();
}await writeFile(path.join(out,'index.html'),'<html><body style="background:#101411;color:#eee3cf">'+index.map(f=>'<p>'+f+'</p><img style="max-width:100%" src="'+f+'">').join('')+'</body></html>');console.log('NATIVE_STYLE_COMPARISONS '+index.length);}
finally{await browser.close();}
