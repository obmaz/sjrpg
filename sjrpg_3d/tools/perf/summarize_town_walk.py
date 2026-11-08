#!/usr/bin/env python3
"""Summarize existing actual walking artifacts; never launch/export the game."""
import base64,hashlib,json,os,statistics,sys
from pathlib import Path

root=Path(sys.argv[1] if len(sys.argv)>1 else "build/walking-input")
out=Path(sys.argv[2] if len(sys.argv)>2 else "build/walking-report")
out.mkdir(parents=True,exist_ok=True)
(out/"images").mkdir(exist_ok=True)
expected={"baseline":os.environ["EXPECTED_BASELINE"],"candidate":os.environ["EXPECTED_CANDIDATE"]}
variants=["mage-high-touch","mage-high-keys","warrior-high-touch","mage-low-touch"]
proof={"kind":"existing paired real-input artifacts; no recapture","expected":expected,
       "limitations":["Chrome RSS/PSS are process observations under SwiftShader, not physical mobile memory or FPS certification.",
                     "Descriptive per-frame slopes do not establish leaks; no forced GC.",
                     "Screenshots before/after the walking interval may affect allocation peaks; compare steady phases separately."],
       "reports":{},"comparisons":[],"images":[]}

def num(x): return isinstance(x,(int,float)) and not isinstance(x,bool)
def stats(values):
    values=[x for x in values if num(x)]
    if not values:return None
    return {"first":values[0],"last":values[-1],"min":min(values),"max":max(values),"delta":values[-1]-values[0]}
def slope(points):
    # De-duplicate repeated reports from the same actual engine frame.
    points={float(x):float(y) for x,y in points if num(x) and num(y)}
    if len(points)<2:return None
    x=list(points);y=list(points.values());mx=sum(x)/len(x);my=sum(y)/len(y)
    denominator=sum((v-mx)**2 for v in x)
    return {"samples":len(points),"per_frame":sum((a-mx)*(b-my) for a,b in zip(x,y))/denominator if denominator else None,
            "first_frame":x[0],"last_frame":x[-1]}
def safeget(value,*keys):
    for key in keys:
        if not isinstance(value,dict):return None
        value=value.get(key)
    return value
def sumcontext(sample,key,value):
    contexts=safeget(sample,key) or []
    return sum(c.get(value,0) for c in contexts)
def memory_near(memory,wall):
    rows=[r for r in memory if r.get("wall",0)<=wall]
    return rows[-1] if rows else None
def read_lines(file):
    return [json.loads(line) for line in file.read_text().splitlines() if line.strip()] if file.exists() else []
def summarize(folder,edition,variant):
    file=folder/"proof.json";raw=json.loads(file.read_text())
    assert raw.get("source_sha")==expected[edition],(folder,raw.get("source_sha"),expected[edition])
    assert raw.get("variant")==variant,(folder,raw.get("variant"))
    samples=raw.get("samples",[]);moving=[s for s in samples if str(s.get("phase","")).startswith("walking-")]
    memory=read_lines(folder/"process-memory.ndjson")
    runtime=lambda s:s.get("runtime") or {}
    monitor=lambda s:runtime(s).get("monitors") or {}
    def field_series(key):return [monitor(s).get(key) for s in samples]
    first=moving[0] if moving else (samples[0] if samples else {})
    last=moving[-1] if moving else (samples[-1] if samples else {})
    heap_points=[(runtime(s).get("frame"),safeget(s,"metrics","JSHeapUsedSize")) for s in moving]
    shader_points=[(runtime(s).get("frame"),safeget(s,"telemetry","shader_compiles")) for s in moving]
    pss_points=[(runtime(s).get("frame"),(memory_near(memory,s.get("wall",0)) or {}).get("pss_sum_bytes")) for s in moving]
    last_runtime=runtime(last);first_runtime=runtime(first)
    summary={"source_sha":raw["source_sha"],"passed":raw.get("passed",False),"failure":raw.get("failure"),
             "errors":raw.get("errors",[]),"profile":raw.get("profile"),"hero":raw.get("hero"),"quality":raw.get("quality"),"input":raw.get("input"),
             "sample_count":len(samples),"moving_samples":len(moving),"start":raw.get("start"),"end":raw.get("end"),
             "walk_distance":raw.get("walk_distance",last.get("walk_distance")),"camera_distance":raw.get("camera_distance",last.get("camera_distance")),
             "resizes":raw.get("resizes",[]),"first_walking_canvases":first.get("canvases"),"last_walking_canvases":last.get("canvases"),
             "native_size":last_runtime.get("native_render_size"),"native_msaa":last_runtime.get("native_msaa_3d"),
             "iso_sprite_cache_first":first_runtime.get("iso_sprite_cache"),"iso_sprite_cache_last":last_runtime.get("iso_sprite_cache"),
             "actor_atlases_last":last_runtime.get("actor_atlases"),
             "monitors":{key:stats(field_series(key)) for key in ["texture_bytes","buffer_bytes","video_bytes","objects","resources","draw_calls","triangles"]},
             "wasm":stats([safeget(s,"telemetry","wasm","bytes") for s in samples]),
             "js_heap":stats([safeget(s,"metrics","JSHeapUsedSize") for s in samples]),
             "shader_compiles":stats([safeget(s,"telemetry","shader_compiles") for s in samples]),
             "shader_compile_cpu_ms":stats([safeget(s,"telemetry","shader_cpu_ms") for s in samples]),
             "links":stats([safeget(s,"telemetry","links") for s in samples]),
             "moving_js_heap_slope":slope(heap_points),"moving_shader_compile_slope":slope(shader_points),"moving_chrome_pss_slope":slope(pss_points),
             "chrome_pss":stats([r.get("pss_sum_bytes") for r in memory]),"chrome_rss_sum":stats([r.get("rss_sum_bytes") for r in memory]),
             "first_walking_processes":memory_near(memory,first.get("wall",0)),"last_walking_processes":memory_near(memory,last.get("wall",0)),
             "webgl_buffers":stats([sum(c.get("live_bytes",0) for c in (safeget(s,"walk","buffers") or [])) for s in samples]),
             "webgl_buffer_data_calls":stats([sum(c.get("data_calls",0) for c in (safeget(s,"walk","buffers") or [])) for s in samples]),
             "webgl_buffer_subdata_bytes":stats([sum(c.get("subdata_bytes",0) for c in (safeget(s,"walk","buffers") or [])) for s in samples]),
             "moving_frame_range":stats([runtime(s).get("frame") for s in moving]),
             "proof_sha256":hashlib.sha256(file.read_bytes()).hexdigest()}
    return summary

for edition in expected:
    proof["reports"][edition]={}
    for variant in variants:
        folder=root/("town-walk-"+edition+"-"+variant)
        if not (folder/"proof.json").exists():
            matches=list(folder.rglob("proof.json"))
            if matches:folder=matches[0].parent
        proof["reports"][edition][variant]=summarize(folder,edition,variant)
        if variant=="mage-high-touch":
            for phase in ["start","end"]:
                source=folder/(phase+".jpg")
                if not source.exists():continue
                name=edition+"-mage-fold-"+phase
                data=source.read_bytes();(out/"images"/(name+".jpg")).write_bytes(data)
                encoded=base64.b64encode(data).decode("ascii")
                metadata={"name":name,"mime":"image/jpeg","bytes":len(data),"base64_length":len(encoded),"sha256":hashlib.sha256(data).hexdigest()}
                proof["images"].append(metadata)
                print("WALK_REVIEW_IMAGE_BEGIN "+json.dumps(metadata),flush=True)
                for index in range(0,len(encoded),16384):
                    print("WALK_REVIEW_IMAGE_CHUNK "+name+" "+encoded[index:index+16384],flush=True)
                print("WALK_REVIEW_IMAGE_END "+name,flush=True)

for variant in variants:
    before=proof["reports"]["baseline"][variant];after=proof["reports"]["candidate"][variant]
    row={"variant":variant,"passed":before["passed"] and after["passed"],"same_native_size":before["native_size"]==after["native_size"],"same_msaa":before["native_msaa"]==after["native_msaa"]}
    for key in ["texture_bytes","buffer_bytes","video_bytes"]:
        a=safeget(before,"monitors",key,"first");b=safeget(after,"monitors",key,"first")
        row[key]={"baseline":a,"candidate":b,"change":b-a if num(a) and num(b) else None,"decrease_percent":(a-b)/a*100 if num(a) and num(b) and a else None}
    for key in ["chrome_pss","js_heap","shader_compiles","wasm","webgl_buffers"]:
        row[key]={"baseline":before[key],"candidate":after[key]}
    proof["comparisons"].append(row)
(out/"summary.json").write_text(json.dumps(proof,indent=2))
print("WALK_PAIRED_SUMMARY "+json.dumps(proof),flush=True)
assert all(r["passed"] and not r["errors"] for reports in proof["reports"].values() for r in reports.values()),"A source walking route failed; preserve its original errors"
print("WALK_REPORT_PASS "+json.dumps({"profiles":8,"source_shas":expected,"images":len(proof["images"])}),flush=True)
