export function installWalkingTelemetry(){
 const state={at:performance.now(),events:[],buffers:[]};
 window.__sjrpgWalkTelemetry=state;
 const note=(kind,detail)=>{const e={at:performance.now(),kind,detail};state.events.push(e);if(state.events.length>64)state.events.shift();};
 for(const kind of ['pagehide','pageshow','visibilitychange','blur','focus','fullscreenchange'])addEventListener(kind,e=>note(kind,{persisted:e.persisted||false,visibility:document.visibilityState}),true);
 const records=new WeakMap();let serial=0;
 function record(gl){let r=records.get(gl);if(!r){r={id:++serial,created:0,deleted:0,live_bytes:0,peak_bytes:0,data_calls:0,subdata_bytes:0,_allocations:new WeakMap(),_bound:new Map()};records.set(gl,r);state.buffers.push(r);}return r;}
 for(const proto of [window.WebGLRenderingContext?.prototype,window.WebGL2RenderingContext?.prototype].filter(Boolean)){
  for(const name of ['createBuffer','deleteBuffer','bindBuffer','bufferData','bufferSubData']){
   const original=proto[name];if(!original||original.__sjrpgWalkWrapped)continue;
   const wrapped=function(...a){const r=record(this),v=original.apply(this,a);
    if(name==='createBuffer')r.created++;
    else if(name==='bindBuffer'){if(a[1])r._bound.set(a[0],new WeakRef(a[1]));else r._bound.delete(a[0]);}
    else if(name==='deleteBuffer'){const n=r._allocations.get(a[0]);if(n!==undefined){r.live_bytes-=n;r._allocations.delete(a[0]);}r.deleted++;}
    else if(name==='bufferData'){
     const object=r._bound.get(a[0])?.deref(),source=a[1];
     let size=typeof source==='number'?source:(source?.byteLength||0);
     if(source&&typeof source!=='number'&&a.length>=4){const unit=source.BYTES_PER_ELEMENT||1;size=a[4]?a[4]*unit:Math.max(0,size-(a[3]||0)*unit);}
     if(object){r.live_bytes+=size-(r._allocations.get(object)||0);r._allocations.set(object,size);r.peak_bytes=Math.max(r.peak_bytes,r.live_bytes);}r.data_calls++;
    }else if(name==='bufferSubData'){const source=a[2],unit=source?.BYTES_PER_ELEMENT||1;let size=source?.byteLength||0;if(a.length>=4)size=a[4]?a[4]*unit:Math.max(0,size-(a[3]||0)*unit);r.subdata_bytes+=size;}
    return v;
   };wrapped.__sjrpgWalkWrapped=true;proto[name]=wrapped;
  }
 }
 window.__sjrpgWalkingRead=()=>({events:state.events.slice(),buffers:state.buffers.map(({_allocations,_bound,...r})=>r)});
}
