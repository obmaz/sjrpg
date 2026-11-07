export function installResourceTelemetry(){
 const state={started:performance.now(),contexts:[],context_lost:[],context_restored:[],shaders:[],links:[],frames:[],long_tasks:[],wasm:[],wasm_peak_bytes:0};
 window.__sjrpgResourceTelemetry=state;
 const memories=[];
 const Memory=WebAssembly.Memory;
 WebAssembly.Memory=new Proxy(Memory,{construct(target,args){const memory=Reflect.construct(target,args,target);memories.push(new WeakRef(memory));return memory;}});
 function remember(instance){const exports=instance?.exports; if(exports)for(const value of Object.values(exports))if(value instanceof Memory)memories.push(new WeakRef(value));}
 for(const name of ['instantiate','instantiateStreaming'])if(WebAssembly[name]){const original=WebAssembly[name];WebAssembly[name]=async function(...args){const result=await original.apply(this,args);remember(result.instance||result);return result;};}
 let previous=performance.now();
 function frame(now){state.frames.push({at:now,ms:now-previous});if(state.frames.length>3000)state.frames.shift();previous=now;requestAnimationFrame(frame);}requestAnimationFrame(frame);
 try{new PerformanceObserver(list=>{for(const e of list.getEntries()){state.long_tasks.push({at:e.startTime,ms:e.duration});if(state.long_tasks.length>300)state.long_tasks.shift();}}).observe({entryTypes:['longtask']});}catch{}
 const bytes={33321:1,33323:2,32849:3,32856:4,35905:3,35907:4,34842:8,34843:6,34836:16,33325:2,33326:4,33327:4,33328:8,33189:2,33190:3,33191:4,35056:4,36168:1,36194:2,6408:4,6407:3,6406:1,6409:1,6410:2,6402:4};
 const prototypes=[window.WebGLRenderingContext?.prototype,window.WebGL2RenderingContext?.prototype].filter(Boolean);
 const records=new WeakMap();let serial=0;
 function record(gl){let r=records.get(gl);if(!r){r={id:++serial,version:gl instanceof WebGL2RenderingContext?2:1,texture_live_bytes:0,texture_peak_bytes:0,renderbuffer_live_bytes:0,renderbuffer_peak_bytes:0,framebuffer_created:0,framebuffer_deleted:0,texture_created:0,texture_deleted:0,renderbuffer_created:0,renderbuffer_deleted:0,unknown_formats:[],draw_calls:0,draw_frames:[],_textures:new WeakMap(),_renderbuffers:new WeakMap(),_bound:new Map(),_active:33984,_rb:null};records.set(gl,r);state.contexts.push(r);gl.canvas?.addEventListener('webglcontextlost',e=>state.context_lost.push({at:performance.now(),status:e.statusMessage}));gl.canvas?.addEventListener('webglcontextrestored',()=>state.context_restored.push({at:performance.now()}));}return r;}
 function bound(r,target){return r._bound.get(r._active+':'+(target>=34069&&target<=34074?34067:target))?.deref();}
 function allocate(r,texture,level,width,height,depth,format,override){if(!texture)return;let entry=r._textures.get(texture);if(!entry){entry={levels:{},bytes:0};r._textures.set(texture,entry);}const key=String(level);let size=override; if(size===undefined){const bpp=bytes[format];if(!bpp){if(!r.unknown_formats.includes(format))r.unknown_formats.push(format);size=0;}else size=Math.max(1,width)*Math.max(1,height)*Math.max(1,depth)*bpp;}r.texture_live_bytes+=size-(entry.levels[key]||0);entry.bytes+=size-(entry.levels[key]||0);entry.levels[key]=size;if(Number(level)===0)entry.base={width,height,depth,format};r.texture_peak_bytes=Math.max(r.texture_peak_bytes,r.texture_live_bytes);}
 for(const proto of prototypes){
  const names=['activeTexture','createTexture','deleteTexture','bindTexture','texImage2D','texImage3D','texStorage2D','texStorage3D','compressedTexImage2D','compressedTexImage3D','generateMipmap','createFramebuffer','deleteFramebuffer','createRenderbuffer','deleteRenderbuffer','bindRenderbuffer','renderbufferStorage','renderbufferStorageMultisample','compileShader','linkProgram','drawArrays','drawElements','drawArraysInstanced','drawElementsInstanced'];
  for(const name of names){const original=proto[name];if(!original||original.__sjrpgWrapped)continue;const wrapped=function(...a){const r=record(this),begin=(name==='compileShader'||name==='linkProgram')?performance.now():0;const value=original.apply(this,a);
   if(name==='activeTexture')r._active=a[0];
   else if(name==='createTexture')r.texture_created++;
   else if(name==='deleteTexture'){const e=r._textures.get(a[0]);if(e){r.texture_live_bytes-=e.bytes;r._textures.delete(a[0]);}r.texture_deleted++;}
   else if(name==='bindTexture'){if(a[1])r._bound.set(r._active+':'+a[0],new WeakRef(a[1]));else r._bound.delete(r._active+':'+a[0]);}
   else if(name==='texImage2D'){const image=a.length===6?a[5]:null;allocate(r,bound(r,a[0]),a[1],image?.width||a[3],image?.height||a[4],1,a[2]);}
   else if(name==='texImage3D')allocate(r,bound(r,a[0]),a[1],a[3],a[4],a[5],a[2]);
   else if(name==='texStorage2D'||name==='texStorage3D'){for(let l=0;l<a[1];l++)allocate(r,bound(r,a[0]),l,Math.max(1,a[3]>>l),Math.max(1,a[4]>>l),name==='texStorage3D'?a[5]:1,a[2]);}
   else if(name==='compressedTexImage2D'||name==='compressedTexImage3D'){const data=a[name==='compressedTexImage2D'?6:7];allocate(r,bound(r,a[0]),a[1],a[3],a[4],name==='compressedTexImage3D'?a[5]:1,a[2],data?.byteLength||0);}
   else if(name==='generateMipmap'){const texture=bound(r,a[0]),base=r._textures.get(texture)?.base;if(base)for(let level=1;level<=Math.floor(Math.log2(Math.max(base.width,base.height)));level++)allocate(r,texture,level,Math.max(1,base.width>>level),Math.max(1,base.height>>level),base.depth,base.format);}
   else if(name==='createFramebuffer')r.framebuffer_created++;
   else if(name==='deleteFramebuffer')r.framebuffer_deleted++;
   else if(name==='createRenderbuffer')r.renderbuffer_created++;
   else if(name==='bindRenderbuffer')r._rb=a[1]?new WeakRef(a[1]):null;
   else if(name==='deleteRenderbuffer'){const e=r._renderbuffers.get(a[0]);if(e){r.renderbuffer_live_bytes-=e;r._renderbuffers.delete(a[0]);}r.renderbuffer_deleted++;}
   else if(name==='renderbufferStorage'||name==='renderbufferStorageMultisample'){const multi=name==='renderbufferStorageMultisample',offset=multi?1:0,rb=r._rb?.deref();const size=(bytes[a[1+offset]]||0)*a[2+offset]*a[3+offset]*(multi?Math.max(1,a[1]):1);if(rb){r.renderbuffer_live_bytes+=size-(r._renderbuffers.get(rb)||0);r._renderbuffers.set(rb,size);r.renderbuffer_peak_bytes=Math.max(r.renderbuffer_peak_bytes,r.renderbuffer_live_bytes);}}
   else if(name==='compileShader'||name==='linkProgram'){const list=name==='compileShader'?state.shaders:state.links;list.push({at:begin,cpu_ms:performance.now()-begin});}
   else if(name.startsWith('draw'))r.draw_calls++;
   return value;};wrapped.__sjrpgWrapped=true;proto[name]=wrapped;
  }
 }
 setInterval(()=>{let total=0;for(const ref of memories){const memory=ref.deref();if(memory)total=Math.max(total,memory.buffer.byteLength);}state.wasm.push({at:performance.now(),bytes:total});if(state.wasm.length>600)state.wasm.shift();state.wasm_peak_bytes=Math.max(state.wasm_peak_bytes,total);for(const r of state.contexts){r.draw_frames.push({at:performance.now(),draws:r.draw_calls});if(r.draw_frames.length>600)r.draw_frames.shift();}},500);
 window.__sjrpgResourceRead=()=>({at:performance.now(),wasm:state.wasm.at(-1)||null,wasm_peak_bytes:state.wasm_peak_bytes,frames:state.frames.slice(),long_tasks:state.long_tasks.slice(),context_lost:state.context_lost,context_restored:state.context_restored,shaders:state.shaders.slice(),links:state.links.slice(),contexts:state.contexts.map(({_textures,_renderbuffers,_bound,_active,_rb,...r})=>r)});
}
