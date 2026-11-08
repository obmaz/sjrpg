#!/usr/bin/env python3
"""Compare actual native captures; publish preview blobs only, never refs."""
import base64
import json
import os
from pathlib import Path
import sys
import urllib.request
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
before = json.loads((root / "before/proof.json").read_text())
after = json.loads((root / "after/proof.json").read_text())
assert before["passed"] and after["passed"], "Both actual browser runs must pass"
a = {item["name"]: item for item in before["captures"]}
b = {item["name"]: item for item in after["captures"]}
assert set(a) == set(b), "Compare the same actual viewpoints"
for name in sorted(a):
    assert a[name]["review"]["physics"] == b[name]["review"]["physics"], name + ": shared physical floor/ramp data changed"
    assert a[name]["review"]["face"] == b[name]["review"]["face"], name + ": camera corner changed"
    assert abs(a[name]["review"]["elevation"] - 35.264389682754654) < 1e-4
    assert abs(b[name]["review"]["elevation"] - 35.264389682754654) < 1e-4
out = root / "previews"
out.mkdir(parents=True, exist_ok=True)
images = []

def write_jpeg(name, picture):
    target = out / name
    picture.save(target, "JPEG", quality=86, optimize=True)
    images.append(target)
    return target

def pair(name, title):
    panels = []
    for edition in ("before", "after"):
        picture = Image.open(root / edition / (name + ".png")).convert("RGB")
        picture.thumbnail((600, 740), Image.Resampling.LANCZOS)
        panels.append(picture)
    width = sum(p.width for p in panels)
    height = max(p.height for p in panels) + 40
    sheet = Image.new("RGB", (width, height), "#182321")
    pen = ImageDraw.Draw(sheet)
    x = 0
    for edition, picture in zip(("BEFORE", "AFTER"), panels):
        pen.text((x + 12, 14), title + " | " + edition, fill="#e4d8bd")
        sheet.paste(picture, (x, 40))
        x += picture.width
    return write_jpeg(name + "-comparison.jpg", sheet)

if "terrain-0-portrait-face-0" in a:
    pair("terrain-0-portrait-face-0", "Raised meadow | azimuth 45")
    pair("terrain-3-landscape-face-2", "Raised pools | azimuth 225")
if after.get("scope") in ("architecture", "all"):
    architecture_names = [name for name in sorted(a) if a[name]["review"]["mode"] in ("house", "chapel", "gate", "corner", "wall_detail", "clear")]
    for name in architecture_names:
        if a[name]["review"]["mode"] != "clear":
            assert a[name]["review"]["hud_hidden"] and b[name]["review"]["hud_hidden"], "Inspection only: HUD deliberately hidden"
            assert abs(a[name]["review"]["camera_size"] - b[name]["review"]["camera_size"]) < 1e-4, name + ": paired camera size changed"
            assert all(abs(x-y) < 1e-4 for x,y in zip(a[name]["review"]["camera_position"], b[name]["review"]["camera_position"])), name + ": paired camera changed"
        assert a[name]["review"]["static_physics_sha256"] == b[name]["review"]["static_physics_sha256"], name + ": actual construction collider data changed"
    for name in architecture_names:
        pair(name, "Actual village materials | " + name)
if after["npcs"]:
    for face in range(4):
        picture = Image.open(root / "after" / ("residents-face-" + str(face) + ".png")).convert("RGB")
        write_jpeg("npc-designs-face-" + str(face) + ".jpg", picture)
    pair("residents-face-0", "Actual runtime NPCs + adult hero")
    pair("residents-face-2", "Actual runtime NPCs | opposite corner")
    for face in range(4):
        picture = Image.open(root / "after" / ("npc-closeup-face-" + str(face) + ".png")).convert("RGB")
        write_jpeg("npc-closeup-face-" + str(face) + ".jpg", picture)
    pair("npc-closeup-face-0", "Hero / Merchant / Mira | actual game models")
    pair("npc-closeup-face-2", "Opposite corner | actual game models")

# Four actual contact pages expose every opposite corner without printing sixteen
# full-size pictures inline. Individual full-size paired JPEGs remain available.
if after.get("scope") in ("architecture", "all"):
    groups = [
        ("architecture-houses-0-1.jpg", ["house-0-face-0", "house-0-face-2", "house-1-face-0", "house-1-face-2"]),
        ("architecture-houses-2-3.jpg", ["house-2-face-0", "house-2-face-2", "house-3-face-0", "house-3-face-2"]),
        ("architecture-chapel.jpg", ["chapel-face-0", "chapel-face-2"]),
        ("architecture-gates-corners.jpg", ["gate-0-face-0", "gate-0-face-2", "wall-corner-0-face-0", "wall-corner-0-face-2"]),
        ("architecture-context-details.jpg", ["village-normal-portrait", "village-normal-landscape", "wall-detail-face-0", "wall-detail-face-2"]),
    ]
    for filename, names in groups:
        sheet = Image.new("RGB", (1200, 395 * ((len(names)+1)//2)), "#182321")
        pen = ImageDraw.Draw(sheet)
        for index, name in enumerate(names):
            picture = Image.open(out / (name + "-comparison.jpg")).convert("RGB")
            picture.thumbnail((600, 360), Image.Resampling.LANCZOS)
            x = (index % 2) * 600
            y = (index // 2) * 395
            pen.text((x + 10, y + 10), name + " | actual BEFORE / AFTER", fill="#e4d8bd")
            sheet.paste(picture, (x + (600-picture.width)//2, y + 32))
        write_jpeg(filename, sheet)

summary = {"passed": True, "baseline": "99d0fd5e779752d5d2e4f14735fe585d8459313e", "candidate": os.environ.get("GITHUB_SHA"), "paired_captures": len(a), "physical_surfaces_unchanged": True, "camera_elevation": 35.264389682754654, "npcs": after["npcs"], "scope": after.get("scope", "terrain"), "expected_imports": after["expectedImports"], "previews": []}
for target in images:
    data = target.read_bytes()
    item = {"path": str(target.relative_to(root)), "bytes": len(data)}
    if os.environ.get("GH_TOKEN") and os.environ.get("GITHUB_REPOSITORY"):
        payload = json.dumps({"encoding": "base64", "content": base64.b64encode(data).decode("ascii")}).encode()
        req = urllib.request.Request("https://api.github.com/repos/" + os.environ["GITHUB_REPOSITORY"] + "/git/blobs", data=payload, method="POST", headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"], "Accept": "application/vnd.github+json", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=40) as response:
            item["blob_sha"] = json.load(response)["sha"]
    summary["previews"].append(item)
    # Bounded actual JPEGs let the parent inspect the result without local files.
    if target.name.startswith("architecture-") or target.name in ("terrain-0-portrait-face-0-comparison.jpg", "terrain-3-landscape-face-2-comparison.jpg", "npc-designs-face-0.jpg", "npc-closeup-face-0-comparison.jpg", "house-3-face-0-comparison.jpg", "gate-0-face-0-comparison.jpg", "wall-detail-face-0-comparison.jpg"):
        encoded = base64.b64encode(data).decode("ascii")
        print("TERRAIN_NPC_IMAGE_BEGIN " + target.name + " image/jpeg " + str(len(encoded)), flush=True)
        for offset in range(0, len(encoded), 16384):
            print("TERRAIN_NPC_IMAGE_CHUNK " + target.name + " " + encoded[offset:offset + 16384], flush=True)
        print("TERRAIN_NPC_IMAGE_END " + target.name, flush=True)
(root / "comparison.json").write_text(json.dumps(summary, indent=2))
print("TERRAIN_NPC_COMPARISON_PASS " + json.dumps(summary), flush=True)
