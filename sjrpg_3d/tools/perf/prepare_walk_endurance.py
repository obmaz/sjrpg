#!/usr/bin/env python3
"""Workspace-only same-app GL-wrapper control; never edit checked-out app sources."""
import os,re
from pathlib import Path
root=Path(os.environ["RUNNER_TEMP"])/"endurance-game"
runner=root/"sjrpg_3d/tools/check_town_walking.mjs"
text=runner.read_text()
old="const duration=Math.min(300000,Math.max(30000,Number(process.env.SJRPG_WALK_DURATION_MS||90000)));"
assert old in text
text=text.replace(old,"const duration=720000;const targetFrames=400;const minWalkMilliseconds=90000;")
text=text.replace("const report={edition:","const report={diagnostic_kind:'same-app wrappers ON/OFF, trace OFF in BOTH',wrapper_mode:process.env.SJRPG_GL_WRAPPERS,target_walking_frames:targetFrames,harness_sha:process.env.SJRPG_HARNESS_SHA,edition:",1)
text=text.replace("await context.tracing.start({screenshots:false,snapshots:false,sources:false});","// Tracing is disabled in BOTH modes to avoid that allocation confound.",1)
text=text.replace("if(context)await context.tracing.stop({path:path.join(out,'trace.zip')}).catch(()=>{});","",1)
needle="const begin=Date.now();let index=0,covered=false,unfolded=false;"
assert needle in text
text=text.replace(needle,"const begin=Date.now(),walkingFrameStart=latest.runtime.frame;let index=0,covered=false,unfolded=false;",1)
needle="while(Date.now()-begin<duration){"
assert needle in text
text=text.replace(needle,"while((latest.runtime.frame-walkingFrameStart<targetFrames||Date.now()-begin<minWalkMilliseconds)&&Date.now()-begin<duration){",1)
needle="await endMove();await holdIdle('idle-after',15000);"
assert needle in text
text=text.replace(needle,"await endMove();report.actual_walking_frames=latest.runtime.frame-walkingFrameStart;assert(report.actual_walking_frames>=targetFrames,'strict 400-frame walking target before 12-minute deadline');await holdIdle('idle-after',15000);",1)
start=text.index("async function capture(name){")
end=text.index("\ntry{\n server=",start)
text=text[:start]+r"""async function capture(name){
 try{
  // Direct compositor capture avoids Playwright's fonts-ready barrier.
  const image=await timeout(cdp.send('Page.captureScreenshot',{format:'jpeg',quality:70,fromSurface:true,captureBeyondViewport:false}),90000,'compositor screenshot '+name);
  const data=Buffer.from(image.data,'base64');await writeFile(path.join(out,name+'.jpg'),data);
  (report.captures??=[]).push({name,bytes:data.length});const encoded=image.data;
  console.log('WALK_ENDURANCE_IMAGE_BEGIN '+JSON.stringify({name:variant+'-'+process.env.SJRPG_GL_WRAPPERS+'-'+name,mime:'image/jpeg',bytes:data.length,base64_length:encoded.length}));
  for(let i=0;i<encoded.length;i+=16384)console.log('WALK_ENDURANCE_IMAGE_CHUNK '+variant+'-'+process.env.SJRPG_GL_WRAPPERS+'-'+name+' '+encoded.slice(i,i+16384));
  console.log('WALK_ENDURANCE_IMAGE_END '+variant+'-'+process.env.SJRPG_GL_WRAPPERS+'-'+name);
 }catch(e){(report.capture_errors??=[]).push({name,error:String(e)});console.error('WALK_CAPTURE_FAIL '+JSON.stringify({name,error:String(e),visual_validated:false}));}
}
""" + text[end:]
text=text.replace("report.walk_distance=walkDistance;report.camera_distance=cameraDistance;report.passed=true;","report.walk_distance=walkDistance;report.camera_distance=cameraDistance;report.visual_captures_validated=(report.captures||[]).some(c=>c.name==='start')&&(report.captures||[]).some(c=>c.name==='end');report.passed=true;",1)
text=text.replace("variant,samples:report.samples.length,walk_distance:","variant,wrapper_mode:report.wrapper_mode,actual_walking_frames:report.actual_walking_frames,visual_captures_validated:report.visual_captures_validated,samples:report.samples.length,walk_distance:",1)
if os.environ["SJRPG_GL_WRAPPERS"]=="off":
    (root/"sjrpg_3d/tools/resource_telemetry.mjs").write_text(r"""export function installResourceTelemetry(){
 const state={started:performance.now(),frames:[],long_tasks:[],context_lost:[],context_restored:[]};
 let last=performance.now();function frame(now){state.frames.push({at:now,ms:now-last});if(state.frames.length>300)state.frames.shift();last=now;requestAnimationFrame(frame);}requestAnimationFrame(frame);
 const seen=new WeakSet();for(const name of ['webglcontextlost','webglcontextrestored'])document.addEventListener(name,event=>{if(seen.has(event))return;seen.add(event);state[name==='webglcontextlost'?'context_lost':'context_restored'].push({at:performance.now(),status:event.statusMessage});},true);
 window.__sjrpgResourceRead=()=>({instrumented:false,at:performance.now(),wasm:null,wasm_peak_bytes:null,contexts:[],shaders:[],links:[],frames:state.frames.slice(),long_tasks:[],context_lost:state.context_lost.slice(),context_restored:state.context_restored.slice()});
}
""")
    (root/"sjrpg_3d/tools/walking_resource_telemetry.mjs").write_text(r"""export function installWalkingTelemetry(){
 const events=[];for(const name of ['pagehide','pageshow','visibilitychange','blur','focus','fullscreenchange'])addEventListener(name,event=>{events.push({at:performance.now(),kind:name,visibility:document.visibilityState});if(events.length>64)events.shift();},true);
 window.__sjrpgWalkingRead=()=>({instrumented:false,events:events.slice(),buffers:null});
}
""")
    text=text.replace("shader_compiles:raw.shaders.length","shader_compiles:raw.instrumented===false?null:raw.shaders.length")
    text=text.replace("shader_cpu_ms:raw.shaders.reduce((n,s)=>n+s.cpu_ms,0)","shader_cpu_ms:raw.instrumented===false?null:raw.shaders.reduce((n,s)=>n+s.cpu_ms,0)")
    text=text.replace("links:raw.links.length","links:raw.instrumented===false?null:raw.links.length")
text=text.replace("Instrumentation mode is emulated","Instrumentation mode is emulated")
runner.write_text(text)
assert "const targetFrames=400" in text and "actual_walking_frames" in text
print("ENDURANCE_OVERLAY "+str({"app":os.environ["SJRPG_WALK_SHA"],"mode":os.environ["SJRPG_GL_WRAPPERS"],"trace":"off both","target_frames":400,"deadline_ms":720000}))
