// Constant-cost diagnostics only; never retains WebGL objects or intercepts drawing/upload calls.
export function installResourceTelemetry(){
 const state={started:performance.now(),buffers:[],frames:[],long_tasks:[],context_lost:[],context_restored:[],shaders:[],links:[],wasm:[],wasm_peak_bytes:0};
 window.__sjrpgStabilityState=state;
 // AudioBuffer storage lives outside the small V8 JS heap. Count successful
 // native allocations using scalar metadata; never retain buffers or source nodes.
 const audio=window.__sjrpgAudioAllocation||(window.__sjrpgAudioAllocation={create_buffer_calls:0,created_pcm_bytes:0,create_source_calls:0,last_buffer:null,last_source_at:null,buffer_hook_available:false,source_hook_available:false});
 const audioProto=window.BaseAudioContext?.prototype;
 if(audioProto){
  const createBuffer=audioProto.createBuffer,createSource=audioProto.createBufferSource;
  audio.buffer_hook_available=typeof createBuffer==='function';audio.source_hook_available=typeof createSource==='function';
  if(createBuffer&&!createBuffer.__sjrpgAudioAllocationWrapped){
   const wrapped=function(channels,length,sampleRate){const value=Reflect.apply(createBuffer,this,arguments);const bytes=value.numberOfChannels*value.length*4;audio.create_buffer_calls++;audio.created_pcm_bytes+=bytes;audio.last_buffer={channels:value.numberOfChannels,length:value.length,sample_rate:value.sampleRate,pcm_bytes:bytes,at:performance.now()};return value;};
   wrapped.__sjrpgAudioAllocationWrapped=true;audioProto.createBuffer=wrapped;
  }
  if(createSource&&!createSource.__sjrpgAudioAllocationWrapped){
   const wrapped=function(){const value=Reflect.apply(createSource,this,arguments);audio.create_source_calls++;audio.last_source_at=performance.now();return value;};
   wrapped.__sjrpgAudioAllocationWrapped=true;audioProto.createBufferSource=wrapped;
  }
 }

 const memories=[],NativeMemory=WebAssembly.Memory;
 const remember=instance=>{for(const value of Object.values(instance?.exports||{}))if(value instanceof NativeMemory)memories.push(new WeakRef(value));};
 WebAssembly.Memory=new Proxy(NativeMemory,{construct(target,args){const value=Reflect.construct(target,args,target);memories.push(new WeakRef(value));return value;}});
 for(const name of ['instantiate','instantiateStreaming'])if(WebAssembly[name]){const original=WebAssembly[name];WebAssembly[name]=async function(...args){const result=await original.apply(this,args);remember(result.instance||result);return result;};}
 const records=new WeakMap();let serial=0;
 function record(gl){let r=records.get(gl);if(!r){r={id:++serial,created:0,deleted:0,vao_created:0,vao_deleted:0};records.set(gl,r);state.buffers.push(r);}return r;}
 for(const proto of [window.WebGLRenderingContext?.prototype,window.WebGL2RenderingContext?.prototype].filter(Boolean)){
  for(const [createName,deleteName,created,deleted] of [['createBuffer','deleteBuffer','created','deleted'],['createVertexArray','deleteVertexArray','vao_created','vao_deleted']]){
   const create=proto[createName],remove=proto[deleteName];
   if(create&&!create.__sjrpgStabilityWrapped){const wrapped=function(){const value=create.call(this);if(value)record(this)[created]++;return value;};wrapped.__sjrpgStabilityWrapped=true;proto[createName]=wrapped;}
   if(remove&&!remove.__sjrpgStabilityWrapped){const wrapped=function(value){const result=remove.call(this,value);if(value)record(this)[deleted]++;return result;};wrapped.__sjrpgStabilityWrapped=true;proto[deleteName]=wrapped;}
  }
  for(const [name,key] of [['compileShader','shaders'],['linkProgram','links']]){const original=proto[name];if(!original||original.__sjrpgStabilityWrapped)continue;const wrapped=function(value){const result=original.call(this,value);state[key].push({at:performance.now(),cpu_ms:0});return result;};wrapped.__sjrpgStabilityWrapped=true;proto[name]=wrapped;}
 }
 const seen=new WeakSet();for(const name of ['webglcontextlost','webglcontextrestored'])document.addEventListener(name,event=>{if(seen.has(event))return;seen.add(event);state[name==='webglcontextlost'?'context_lost':'context_restored'].push({at:performance.now(),status:event.statusMessage});},true);
 let previous=performance.now();function frame(now){state.frames.push({at:now,ms:now-previous});if(state.frames.length>120)state.frames.shift();previous=now;requestAnimationFrame(frame);}requestAnimationFrame(frame);
 window.__sjrpgResourceRead=()=>{let total=0;for(const ref of memories){const memory=ref.deref();if(memory)total=Math.max(total,memory.buffer.byteLength);}state.wasm_peak_bytes=Math.max(state.wasm_peak_bytes,total);return{at:performance.now(),wasm:{at:performance.now(),bytes:total},wasm_peak_bytes:state.wasm_peak_bytes,contexts:[],frames:state.frames.slice(),long_tasks:[],context_lost:state.context_lost.slice(),context_restored:state.context_restored.slice(),shaders:state.shaders.slice(),links:state.links.slice()};};
}
export function installWalkingTelemetry(){
 const events=[];for(const kind of ['pagehide','pageshow','visibilitychange','blur','focus','fullscreenchange'])addEventListener(kind,event=>{events.push({at:performance.now(),kind,persisted:event.persisted||false,visibility:document.visibilityState});if(events.length>64)events.shift();},true);
 window.__sjrpgWalkingRead=()=>({events:events.slice(),buffers:(window.__sjrpgStabilityState?.buffers||[]).map(r=>({...r}))});
}
