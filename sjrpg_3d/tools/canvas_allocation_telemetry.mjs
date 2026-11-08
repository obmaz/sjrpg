// Worker-only attribution; retains no GL objects, engine nodes or call stacks.
export function installCanvasAllocationTelemetry() {
 const state={draws:{},buffer_creates:{},outside_buffer_creates:0,draw_paths:{},buffer_create_paths:{}};
 window.__sjrpgCanvasDrawMark=owner=>{const key=owner.script;state.draws[key]=(state.draws[key]||0)+1;const path=owner.path;state.draw_paths[path]=(state.draw_paths[path]||0)+1;};
 const seen=new Set();
 for(const name of ['WebGLRenderingContext','WebGL2RenderingContext']){
  const proto=window[name]?.prototype,original=proto?.createBuffer;
  if(!original||seen.has(proto))continue;
  seen.add(proto);
  proto.createBuffer=function(...args){
   const result=Reflect.apply(original,this,args);
   if(result){const key=window.__sjrpgCanvasDrawOwner?.script;if(key){state.buffer_creates[key]=(state.buffer_creates[key]||0)+1;const path=window.__sjrpgCanvasDrawOwner.path;state.buffer_create_paths[path]=(state.buffer_create_paths[path]||0)+1;}else state.outside_buffer_creates++;}
   return result;
  };
 }
 window.__sjrpgCanvasAllocationSnapshot=()=>JSON.parse(JSON.stringify(state));
}
