#!/usr/bin/env python3
"""Expose actual failed-run photographs for inspection, never release approval."""
import base64
import json
import os
from pathlib import Path
import sys
import urllib.request
from PIL import Image, ImageDraw
root = Path(sys.argv[1])
output = root / "diagnostic-previews"
output.mkdir(parents=True, exist_ok=True)
run_id = int(os.environ.get("SJRPG_DIAGNOSTIC_RUN", "42462205156"))
proofs = {edition: json.loads((root / edition / "proof.json").read_text()) for edition in ("before", "after")}
names = ["village-normal-portrait", "village-normal-landscape", "failure"]
summary = {"passed": False, "evidence_kind": "diagnostic-only", "source_run_id": run_id, "release_approval": False,
    "note": "Actual images retained even when a source physics/camera guard fails; no capture or deploy gate is altered.",
    "source_status": {edition: {"passed": proof.get("passed", False), "failure": proof.get("failure"), "captures": len(proof.get("captures", []))} for edition, proof in proofs.items()}, "previews": []}
pictures = []
def save(name, image):
    target = output / name
    image.save(target, "JPEG", quality=88, optimize=True)
    pictures.append(target)
for name in names:
    panels = []
    for edition in ("before", "after"):
        source = root / edition / (name + ".png")
        if not source.is_file():
            raise RuntimeError("Missing actual diagnostic photograph: " + str(source))
        picture = Image.open(source).convert("RGB")
        save(edition + "-" + name + ".jpg", picture)
        picture.thumbnail((600, 740), Image.Resampling.LANCZOS)
        panels.append(picture)
    canvas = Image.new("RGB", (sum(p.width for p in panels), max(p.height for p in panels) + 62), "#182321")
    pen = ImageDraw.Draw(canvas)
    pen.text((10, 9), "DIAGNOSTIC ONLY - source guard failed - not release proof", fill="#e3bb8c")
    left = 0
    for edition, picture in zip(("BEFORE", "AFTER"), panels):
        pen.text((left + 10, 33), edition + " | " + name, fill="#e2d6bd")
        canvas.paste(picture, (left, 62))
        left += picture.width
    save("diagnostic-" + name + "-comparison.jpg", canvas)
for target in pictures:
    data = target.read_bytes()
    item = {"path": str(target.relative_to(root)), "bytes": len(data), "passed": False, "evidence_kind": "diagnostic-only"}
    if os.environ.get("GH_TOKEN"):
        req = urllib.request.Request("https://api.github.com/repos/" + os.environ["GITHUB_REPOSITORY"] + "/git/blobs",
            data=json.dumps({"encoding": "base64", "content": base64.b64encode(data).decode("ascii")}).encode(),
            headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"], "Accept": "application/vnd.github+json", "Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=40) as response:
            item["blob_sha"] = json.load(response)["sha"]
    summary["previews"].append(item)
    if target.name.startswith("diagnostic-"):
        encoded = base64.b64encode(data).decode("ascii")
        print("VILLAGE_DIAGNOSTIC_IMAGE_BEGIN " + target.name + " image/jpeg " + str(len(encoded)), flush=True)
        for offset in range(0, len(encoded), 16384):
            print("VILLAGE_DIAGNOSTIC_IMAGE_CHUNK " + target.name + " " + encoded[offset:offset + 16384], flush=True)
        print("VILLAGE_DIAGNOSTIC_IMAGE_END " + target.name, flush=True)
(root / "diagnostic-summary.json").write_text(json.dumps(summary, indent=2))
print("VILLAGE_DIAGNOSTIC_EVIDENCE " + json.dumps(summary), flush=True)
