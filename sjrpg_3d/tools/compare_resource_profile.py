#!/usr/bin/env python3
"""Compare identical real browser routes; no physical-device FPS claims."""
import json,sys
from pathlib import Path
root=Path(sys.argv[1] if len(sys.argv)>1 else "build/resource-review")
def percentile(values,q):
    values=sorted(values)
    return values[min(len(values)-1,int((len(values)-1)*q))] if values else None
def summarise(path):
    raw=json.loads(path.read_text())
    profiles=[]
    for profile in raw["profiles"]:
        phases=[]
        for phase in profile["phases"]:
            samples=phase["samples"]
            if not samples:
                phases.append({"label":phase["label"],"samples":0,"measurement_error":"No completed sample in original failed run"})
                continue
            frames={f["at"]:f["ms"] for sample in samples for f in sample["telemetry"]["frames"]}
            tasks={f["at"]:f["ms"] for sample in samples for f in sample["telemetry"]["long_tasks"]}
            tail=samples[-1]
            runtime=tail.get("runtime") or {}
            gl=tail["telemetry"]["contexts"]
            phases.append({"label":phase["label"],"samples":len(samples),"frames":len(frames),"frame_p50_ms":percentile(list(frames.values()),.5),"frame_p95_ms":percentile(list(frames.values()),.95),"frame_max_ms":max(frames.values(),default=None),"long_task_count":len(tasks),"long_task_ms":sum(tasks.values()),"js_heap":tail["metrics"].get("JSHeapUsedSize"),"wasm_bytes":(tail["telemetry"].get("wasm") or {}).get("bytes"),"godot":runtime.get("monitors"),"godot_peaks":runtime.get("peaks"),"actor_atlases":runtime.get("actor_atlases"),"enemy_mesh_cache":runtime.get("enemy_mesh_cache"),"render_activity":runtime.get("render_activity"),"native_render_size":runtime.get("native_render_size"),"selection_probe_activity":runtime.get("selection_probe_activity"),"node_count":runtime.get("nodes"),"gl_texture_estimate":sum(c["texture_live_bytes"] for c in gl),"gl_texture_peak_estimate":sum(c["texture_peak_bytes"] for c in gl),"gl_renderbuffer_estimate":sum(c["renderbuffer_live_bytes"] for c in gl),"framebuffer_live":sum(c["framebuffer_created"]-c["framebuffer_deleted"] for c in gl),"unknown_gl_formats":sorted(set(f for c in gl for f in c["unknown_formats"]))})
        titles=[p for p in phases if p["label"].endswith("title-after-cave")]
        growth={}
        if len(titles)>=2:
            # First cycle warms real caches; report later-cycle difference without forcing GC.
            first=titles[1] if len(titles)>2 else titles[0]
            last=titles[-1]
            for key in ["js_heap","wasm_bytes","node_count","gl_texture_estimate","gl_renderbuffer_estimate","framebuffer_live"]:
                a,b=first.get(key),last.get(key)
                growth[key]=b-a if isinstance(a,(int,float)) and isinstance(b,(int,float)) else None
        profiles.append({"name":profile["name"],"dpr":profile["dpr"],"phases":phases,"warm_title_growth":growth,"network":profile["network"],"resource_entries":profile.get("resource_entries",[])})
    return {"source_sha":raw["source_sha"],"passed":raw["passed"],"failure":raw.get("failure"),"errors":raw["errors"],"profiles":profiles}
reports={}
for edition in ["before","after"]:
    file=root/edition/"profile.json"
    if file.exists():reports[edition]=summarise(file)
comparison=[]
if len(reports)==2:
    for before,after in zip(reports["before"]["profiles"],reports["after"]["profiles"]):
        assert before["name"]==after["name"] and before["dpr"]==after["dpr"]
        for b,a in zip(before["phases"],after["phases"]):
            assert b["label"]==a["label"],"Routes differ"
            delta={}
            for key in ["frame_p95_ms","js_heap","wasm_bytes","gl_texture_estimate","gl_renderbuffer_estimate","framebuffer_live"]:
                av,bv=a.get(key),b.get(key)
                delta[key]={"before":bv,"after":av,"change":av-bv if isinstance(av,(int,float)) and isinstance(bv,(int,float)) else None}
            comparison.append({"profile":after["name"],"phase":a["label"],"delta":delta})
proof={"renderer":"Chromium ANGLE SwiftShader; relative comparison only","reports":reports,"comparison":comparison}
(root/"comparison.json").write_text(json.dumps(proof,indent=2))
print("RESOURCE_COMPARISON "+json.dumps({"editions":{k:{"sha":v["source_sha"],"passed":v["passed"],"growth":[{"name":p["name"],"growth":p["warm_title_growth"]} for p in v["profiles"]]} for k,v in reports.items()}))
assert len(reports)==2 and all(r["passed"] for r in reports.values()),"A real route failed; inspect original strict errors"
