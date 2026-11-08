#!/usr/bin/env python3
"""Pair actual GPU-compression captures; never modify game/source art."""
import base64, json, os
from pathlib import Path
import sys, urllib.request
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
before = json.loads((root/"before/texture-compression.json").read_text())
after = json.loads((root/"after/texture-compression.json").read_text())
assert before["passed"] and after["passed"]
assert before["targets"] == after["targets"] and before["quality"] == after["quality"]
a = {c["name"]:c for c in before["captures"]}
b = {c["name"]:c for c in after["captures"]}
assert len(a) == 6 and set(a) <= set(b)
out = root/"previews"
out.mkdir(parents=True,exist_ok=True)
previews = []
for name in a:
    x,y = a[name]["texture"],b[name]["texture"]
    assert x["quality"] == y["quality"] and x["render_size"] == y["render_size"]
    assert abs(x["camera_elevation"]-y["camera_elevation"]) < 1e-4
    assert abs(x["camera_azimuth"]-y["camera_azimuth"]) < 1e-4
    assert abs(x["camera_size"]-y["camera_size"]) < .001
    assert all(abs(i-j)<.02 for i,j in zip(x["camera_position"],y["camera_position"])), name+": camera moved"
    panels = []
    for edition in ("before","after"):
        picture = Image.open(root/edition/(name+".png")).convert("RGB")
        picture.thumbnail((600,850),Image.Resampling.LANCZOS)
        panels.append(picture)
    sheet = Image.new("RGB",(sum(p.width for p in panels),max(p.height for p in panels)+36),"#172321")
    draw = ImageDraw.Draw(sheet)
    left = 0
    for label,picture in zip(("BEFORE","GPU COMPRESSED"),panels):
        draw.text((left+10,12),name+" | "+label,fill="#e4d8bd")
        sheet.paste(picture,(left,36))
        left += picture.width
    path = out/(name+"-comparison.jpg")
    sheet.save(path,"JPEG",quality=90,optimize=True)
    data = path.read_bytes()
    item = {"name":path.name,"bytes":len(data)}
    if os.environ.get("GH_TOKEN"):
        request = urllib.request.Request("https://api.github.com/repos/"+os.environ["GITHUB_REPOSITORY"]+"/git/blobs",
            data=json.dumps({"encoding":"base64","content":base64.b64encode(data).decode()}).encode(),
            method="POST",headers={"Authorization":"Bearer "+os.environ["GH_TOKEN"],"Accept":"application/vnd.github+json","Content-Type":"application/json"})
        with urllib.request.urlopen(request,timeout=60) as response:
            item["blob_sha"] = json.load(response)["sha"]
    previews.append(item)
    encoded = base64.b64encode(data).decode()
    print("TEXTURE_IMAGE_BEGIN "+path.name+" "+str(len(encoded)),flush=True)
    for offset in range(0,len(encoded),16384):
        print("TEXTURE_IMAGE_CHUNK "+path.name+" "+encoded[offset:offset+16384],flush=True)
    print("TEXTURE_IMAGE_END "+path.name,flush=True)
normal = [m for m in after["measurements"] if not m["name"].startswith("etc2-")]
assert len(normal) == 3 and all(m["selected_variant"] in ("s3tc","etc2") and m["gpu"]["compressed"]["bytes"] > 0 for m in normal)
for current in normal:
    original = next(m for m in before["measurements"] if m["name"] == current["name"])
    dimensions = lambda m: {t["path"]:[t["width"],t["height"]] for t in m["texture"]["probe"]["textures"]}
    assert dimensions(original) == dimensions(current), current["name"]+": logical source dimensions changed"
def budgets(report):
    return [{"name":m["name"],"normal_before_probe":m["normal_texture_memory_before_probe"],
             "controlled_all_ten":m["texture"]["probe"]["texture_memory_after_bytes"],
             "selected_variant":m["selected_variant"]} for m in report["measurements"]]
summary = {"passed":True,"baseline":before["ref"],"candidate":after["ref"],"paired_views":len(a),
           "source_dimensions_preserved":True,"before":budgets(before),"after":budgets(after),"previews":previews,
           "scope":"Actual same-camera renders and engine GPU-memory counters. Controlled all-ten measurements include explicitly loaded unused resources; upload bytes are transfers, not residency.",
           "etc2_profile":[{"name":m["name"],"selected_variant":m["selected_variant"]} for m in after["measurements"] if m["name"].startswith("etc2-")]}
(root/"comparison.json").write_text(json.dumps(summary,indent=2)+"\n")
print("TEXTURE_COMPARISON_PASS "+json.dumps(summary),flush=True)
