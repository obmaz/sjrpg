#!/usr/bin/env node
// CI-only real browser GPU-format measurements. It never retains upload buffers.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)('playwright');
const base=new URL(process.argv[2]||'http://127.0.0.1:8792/');
const out=path.resolve(process.argv[3]||'build/texture-compression-review');
const edition=process.env.SJRPG_TEXTURE_EDITION||'after';
assert(['before','after'].includes(edition),'explicit before/after edition');
const quality=process.env.SJRPG_TEXTURE_QUALITY||'high';
assert(['high','low'].includes(quality),'same real rendering quality for both editions');
const targets=[
 'res://assets/art/preview3d/limestone.webp','res://assets/art/preview3d/slate.webp',
 'res://assets/art/preview3d/timber.webp','res://assets/art/preview3d/bark.webp',
 'res://assets/art/forest/grass.webp','res://assets/art/forest/paving.webp',
 'res://assets/art/village/rock.webp','res://assets/art/village/water.webp',
 'res://assets/art/cave/floor.webp','res://assets/art/cave/dark.webp',
];
await mkdir(out,{recursive:true});
const errors=[],captures=[],measurements=[],checks=[];
let context,page,failure;
function timed(promise,label,ms=30000){let timer;const deadline=new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Timeout '+label)),ms);timer.unref();});return Promise.race([promise,deadline]).finally(()=>clearTimeout(timer));}
function mark(label,data={}){console.log('TEXTURE_COMPRESSION_PROGRESS '+JSON.stringify({at:new Date().toISOString(),label,...data}));}
const watchdog=setTimeout(()=>{console.error('TEXTURE_COMPRESSION_WATCHDOG_FAIL '+JSON.stringify({captures:captures.map(c=>c.name),errors}));process.exit(2);},9*60*1000);watchdog.unref();
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});

// Runs before Godot creates its own real WebGL2 context. No synthetic images,
// extra WebGL contexts, retained ArrayBuffers, camera edits or game-state edits.
function installGPUProbe({requestMask}){
 const state={requested_profile:requestMask?'etc2-if-supported':'native',contexts:[],compressed:{calls:0,bytes:0,by_format:{}},uncompressed:{calls:0,typed_buffer_calls:0},deleted_textures:0};
 Object.defineProperty(window,'__sjrpgTextureGPU',{value:state,configurable:false});
 const records=new WeakMap(),nativeMethods=new Map();
 for(const C of[window.WebGLRenderingContext,window.WebGL2RenderingContext]){
  if(!C)continue;
  const p=C.prototype;
  nativeMethods.set(p,{getSupportedExtensions:p.getSupportedExtensions,getExtension:p.getExtension,getParameter:p.getParameter,compressedTexImage2D:p.compressedTexImage2D,compressedTexSubImage2D:p.compressedTexSubImage2D,texImage2D:p.texImage2D,deleteTexture:p.deleteTexture});
 }
 const blockedName=name=>/(?:compressed_texture_(?:s3tc(?:_srgb)?|astc)|texture_compression_bptc)$/i.test(String(name));
 const blockedFormat=n=>(n>=0x83f0&&n<=0x83f3)||(n>=0x8c4c&&n<=0x8c4f)||(n>=0x8e8c&&n<=0x8e8f)||(n>=0x93b0&&n<=0x93dd);
 function raw(gl){return nativeMethods.get(window.WebGL2RenderingContext&&gl instanceof window.WebGL2RenderingContext?window.WebGL2RenderingContext.prototype:window.WebGLRenderingContext.prototype);}
 function info(gl){
  if(records.has(gl))return records.get(gl);
  const methods=raw(gl);
  const extensions=methods.getSupportedExtensions.call(gl)||[];
  const etc=extensions.includes('WEBGL_compressed_texture_etc')?methods.getExtension.call(gl,'WEBGL_compressed_texture_etc'):null;
  const formats=Array.from(methods.getParameter.call(gl,gl.COMPRESSED_TEXTURE_FORMATS)||[]);
  const realETC=!!etc&&formats.some(n=>n===0x9274||n===0x9278);
  const row={id:state.contexts.length+1,api:window.WebGL2RenderingContext&&gl instanceof window.WebGL2RenderingContext?'webgl2':'webgl',raw_extensions:extensions,effective_extensions:requestMask&&realETC?extensions.filter(n=>!blockedName(n)):extensions,real_etc2_extension:!!etc,real_etc2_formats:formats.filter(n=>n>=0x9270&&n<=0x9279),mask_active:requestMask&&realETC,mask_status:!requestMask?'native':realETC?'active_with_real_etc2':'unsupported_etc2_native_fallback',vendor:String(methods.getParameter.call(gl,gl.VENDOR)),renderer:String(methods.getParameter.call(gl,gl.RENDERER)),actual_supported_formats:formats,compressed_upload_calls:0,tex_image_calls:0};
  records.set(gl,row);if(state.contexts.length<8)state.contexts.push(row);
  return row;
 }
 function bufferBytes(args,index){
  const value=args[index];if(typeof value==='number')return Math.max(0,value);
  if(!ArrayBuffer.isView(value))return 0;
  const size=value.BYTES_PER_ELEMENT||1,offset=Number(args[index+1]||0)*size,limit=Number(args[index+2]||0)*size;
  return Math.max(0,limit||value.byteLength-offset);
 }
 for(const [p,methods]of nativeMethods){
  p.getSupportedExtensions=function(){const row=info(this);return [...row.effective_extensions];};
  p.getExtension=function(name){const row=info(this);if(row.mask_active&&blockedName(name))return null;return methods.getExtension.call(this,name);};
  p.getParameter=function(name){const row=info(this);const value=methods.getParameter.call(this,name);if(name!==this.COMPRESSED_TEXTURE_FORMATS)return value;row.actual_supported_formats=Array.from(value||[]);return row.mask_active?new Uint32Array(row.actual_supported_formats.filter(n=>!blockedFormat(n))):value;};
  p.compressedTexImage2D=function(...args){
   const row=info(this),format=Number(args[2]),bytes=bufferBytes(args,6),key=String(format);
   row.compressed_upload_calls++;state.compressed.calls++;state.compressed.bytes+=bytes;
   const stat=state.compressed.by_format[key]||(state.compressed.by_format[key]={calls:0,bytes:0,base_dimensions:[]});stat.calls++;stat.bytes+=bytes;
   if(Number(args[1])===0&&stat.base_dimensions.length<16&&!stat.base_dimensions.some(d=>d[0]===Number(args[3])&&d[1]===Number(args[4])))stat.base_dimensions.push([Number(args[3]),Number(args[4])]);
   row.actual_supported_formats=Array.from(methods.getParameter.call(this,this.COMPRESSED_TEXTURE_FORMATS)||[]);
   return methods.compressedTexImage2D.apply(this,args);
  };
  p.compressedTexSubImage2D=function(...args){
   const row=info(this),format=Number(args[6]),bytes=bufferBytes(args,7),key=String(format);
   row.compressed_upload_calls++;state.compressed.calls++;state.compressed.bytes+=bytes;
   const stat=state.compressed.by_format[key]||(state.compressed.by_format[key]={calls:0,bytes:0,base_dimensions:[]});stat.calls++;stat.bytes+=bytes;
   row.actual_supported_formats=Array.from(methods.getParameter.call(this,this.COMPRESSED_TEXTURE_FORMATS)||[]);
   return methods.compressedTexSubImage2D.apply(this,args);
  };
  p.texImage2D=function(...args){const row=info(this);row.tex_image_calls++;state.uncompressed.calls++;if(args.length>=9&&ArrayBuffer.isView(args[8]))state.uncompressed.typed_buffer_calls++;return methods.texImage2D.apply(this,args);};
  p.deleteTexture=function(...args){state.deleted_textures++;return methods.deleteTexture.apply(this,args);};
 }
}
const read=()=>timed(page.evaluate(()=>({gpu:window.__sjrpgTextureGPU,texture:window.__sjrpgTextureCompression,ui:window.__sjrpgNativeStyleReview,native:window.__sjrpg3dProbe,adventureReady:window.__sjrpgAdventureReady===true,dungeonPreviewReady:window.__sjrpgDungeonPreviewReady===true,window:[innerWidth,innerHeight]})),'read actual texture state');
async function wait(fn,label,timeout=90000){
 const end=Date.now()+timeout;
 while(Date.now()<end){assert.equal(errors.length,0,JSON.stringify(errors));const s=await read();if(fn(s))return s;await page.waitForTimeout(100);}
 throw Error('Timeout '+label+' '+JSON.stringify(await read()));
}
async function settle(frames=4){const first=(await read()).texture.frame;return wait(s=>s.texture.frame>=first+frames,'drawn native frames');}
async function boot(scene,masked){
 mark('boot begin',{scene,masked,quality});
 if(context)await timed(context.close(),'close prior context');
 context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
 await context.addInitScript(installGPUProbe,{requestMask:masked});
 page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:|INVALID_(OPERATION|VALUE|ENUM)/.test(m.text()))errors.push(m.text());});
 const url=new URL(base);url.searchParams.set('native_style_review','1');url.searchParams.set('quality',quality);
 if(scene==='town')url.searchParams.set('at','npc_courtyard');else if(scene==='river')url.searchParams.set('at','bridge');else url.searchParams.set('dungeon_preview','entry');
 await timed(page.goto(url.href,{waitUntil:'domcontentloaded'}),'game document',60000);
 await page.waitForFunction(()=>window.__sjrpgTitleReady&&window.__sjrpgEntryReady,null,{timeout:90000});
 mark('title ready',{scene,masked});await page.locator('#entry-start').click();
 await page.waitForFunction(()=>window.__sjrpgClassButtons?.stage==='class',null,{timeout:30000});
 for(const key of['mage','start']){const b=await page.evaluate(key=>({p:window.__sjrpgClassButtons[key],w:innerWidth,h:innerHeight}),key);assert(b.p,'actual class selection button '+key);await page.mouse.click(b.p[0]*b.w,b.p[1]*b.h);await page.waitForTimeout(250);}
 await wait(s=>s.adventureReady&&s.ui?.native&&s.texture?.ready&&s.native?.native_active&&s.native.physics_ticks>0&&(scene!=='cave'||s.dungeonPreviewReady),'actual adventure construction');
 await settle(6);mark('actual game ready',{scene,masked});
}
function verifyNormal(s,scene){
 const expectedPaused=scene==='cave';
 assert.equal(s.ui.paused,expectedPaused,'expected live or existing frozen-fixture state');assert.equal(s.texture.paused,expectedPaused);
 if(expectedPaused)assert(s.dungeonPreviewReady&&s.ui.dungeon_active&&!s.ui.panel.rect,'explicit existing frozen cave photograph, not live gameplay or menu');
 assert(!s.ui.panel.rect,'no overlay covers actual game');
 assert.equal(s.texture.dungeon_active,scene==='cave','actual requested world');
 assert(s.texture.hud_visible,'normal game HUD remains visible');
 assert.equal(s.texture.quality,quality,'same actual world quality');
 assert(Math.abs(s.texture.camera_elevation-35.264389682754654)<1e-4,'true isometric camera preserved');
 assert(s.gpu.contexts.some(c=>c.api==='webgl2'),'actual engine WebGL2 context');
}
async function capture(name,scene){
 const s=await read();verifyNormal(s,scene);
 assert(!s.texture.probe.ready,'normal screenshot occurs before controlled resource measurement');
 await page.screenshot({path:path.join(out,name+'.png'),timeout:60000});
 captures.push({name,...s,photograph_scope:scene==='cave'?'existing frozen cave photograph; not live gameplay':'normal live gameplay',measurement_scope:'photograph before any explicit resource probe'});
 mark('normal capture complete',{name,textureMemory:s.texture.texture_memory_bytes});
 return s;
}
async function measure(name,masked){
 const before=await read();
 await page.evaluate(()=>window.__sjrpgTextureCompressionAction('measure'));
 const s=await wait(s=>s.texture?.probe?.ready,'controlled resource measurement');
 const p=s.texture.probe;
 assert.deepEqual(p.textures.map(t=>t.path),targets,'same exact ten resources in both editions');
 assert(p.textures.every(t=>t.exists&&t.class==='CompressedTexture2D'&&t.width>0&&t.height>0&&t.load_path),'real imported texture dimensions and load paths');
 const active=s.gpu.contexts.filter(c=>c.api==='webgl2').sort((a,b)=>(b.compressed_upload_calls+b.tex_image_calls)-(a.compressed_upload_calls+a.tex_image_calls))[0];
 assert(active,'actual engine context recorded');
 if(masked&&active.mask_active){
  assert(active.real_etc2_extension&&active.real_etc2_formats.length,'mask uses real ETC2 capability');
  assert.equal(s.texture.features.s3tc,false);assert.equal(s.texture.features.bptc,false);assert.equal(s.texture.features.astc,false);
  checks.push(name+' actual ETC2-capable context with S3TC/BPTC/ASTC hidden');
 }else if(masked){checks.push(name+' explicit unsupported ETC2 native fallback; not ETC2 proof');}
 const selected=edition==='after'?(s.texture.features.s3tc?'s3tc':s.texture.features.etc2?'etc2':null):null;
 if(edition==='after'&&selected){
  assert(p.textures.every(t=>t.load_path.endsWith('.'+selected+'.ctex')),'actual chosen '+selected+' resource variants');
  const formats=Object.keys(s.gpu.compressed.by_format).map(Number);
  const expected=selected==='s3tc'?[0x83f0,0x83f2,0x83f3]:[0x9274,0x9276,0x9278];
  assert(formats.some(f=>expected.includes(f)),'actual '+selected+' compressed GPU uploads');
  assert(s.gpu.compressed.bytes>0,'actual compressed bytes uploaded');
  if(masked&&active.mask_active)assert(!formats.some(f=>(f>=0x83f0&&f<=0x83f3)||(f>=0x8e8c&&f<=0x8e8f)||(f>=0x93b0&&f<=0x93dd)),'masked profile never uploads disabled formats');
 }else if(edition==='before'){assert(p.textures.every(t=>!/\.(s3tc|etc2|bptc|astc)\.ctex$/.test(t.load_path)),'baseline target resources retain original uncompressed GPU path');}
 measurements.push({name,...s,photograph_scope:s.texture.dungeon_active?'existing frozen cave fixture; not live gameplay':'normal live gameplay',measured_upload_context:active.id,normal_texture_memory_before_probe:before.texture.texture_memory_bytes,selected_variant:selected||'raw_or_decompression_fallback',upload_counter_scope:'cumulative transfers, not GPU residency; excludes retained pixel buffers'});
 mark('controlled measurement complete',{name,selected,uncached:p.uncached_explicit_loads.length,compressedBytes:s.gpu.compressed.bytes});
}
try{
 await boot('town',false);
 await capture('native-town-portrait','town');
 await page.setViewportSize({width:844,height:390});await settle(6);
 await capture('native-town-landscape','town');
 await measure('native-town',false);
 if(process.env.SJRPG_TEXTURE_RIVER!=='false'){
  await boot('river',false);
  await capture('native-river-portrait','river');
  await page.setViewportSize({width:844,height:390});await settle(6);
  await capture('native-river-landscape','river');
  await measure('native-river',false);
 }
 if(process.env.SJRPG_TEXTURE_CAVE!=='false'){
  await boot('cave',false);
  await capture('frozen-cave-portrait','cave');
  await page.setViewportSize({width:844,height:390});await settle(6);
  await capture('frozen-cave-landscape','cave');
  await measure('frozen-cave',false);
 }
 if(edition==='after'){
  await boot('town',true);
  await capture('etc2-town-portrait','town');
  await page.setViewportSize({width:844,height:390});await settle(6);
  await capture('etc2-town-landscape','town');
  await measure('etc2-town',true);
 }
 checks.push('live town/river and explicitly frozen cave captures precede controlled measurements; no pixel reads or additional camera/gameplay mutations');
}catch(error){
 failure=error;errors.push(String(error.stack||error));
 if(page){try{await page.screenshot({path:path.join(out,'failure.png'),timeout:15000});}catch{}}
}finally{
 const summary={passed:!failure&&errors.length===0,edition,ref:process.env.SJRPG_TEXTURE_REF||'',quality,targets,captures,measurements,checks,errors};
 await writeFile(path.join(out,'texture-compression.json'),JSON.stringify(summary,null,2));
 console.log('TEXTURE_COMPRESSION_RESULT '+JSON.stringify({passed:summary.passed,edition,captures:captures.length,measurements:measurements.length,errors}));
 clearTimeout(watchdog);await timed(browser.close(),'close browser',20000);
}
if(failure)throw failure;
